// lib/services/horse_performance_scraper_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
// [追加] 成績タブ拡充: ログイン Cookie 付与とタイム指数等の保存 (v.2026.9.22+26092205)
import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_past_race_extra_repository.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';
// [追加] 過去走の取得状況ポップアップ: 取得結果（成功・初出走で戦績なし・失敗）の記録と、ログイン切れ（タイム指数の伏せ字）の判定 (v.2026.11.5+26110501)
import 'package:hetaumakeiba_v2/logic/past_record_status.dart';
import 'package:hetaumakeiba_v2/services/horse_fetch_outcome_store.dart';

// [追加] 過去走の取得状況ポップアップ: 競走馬ページの取得結果の種類。ok=戦績あり、noRecords=ページは正常だが戦績0件（初出走）、failed=取得できなかった (v.2026.11.5+26110501)
enum HorsePerformanceFetchStatus { ok, noRecords, failed }

// [追加] 過去走の取得状況ポップアップ: 競走馬ページの取得結果。maskedIndexSuspected はタイム指数が伏せ字のままだった（ログイン切れの可能性） (v.2026.11.5+26110501)
class HorsePerformanceScrapeResult {
  final HorsePerformanceFetchStatus status;
  final List<HorseRaceRecord> records;
  final bool maskedIndexSuspected;

  const HorsePerformanceScrapeResult({
    required this.status,
    required this.records,
    this.maskedIndexSuspected = false,
  });
}

class HorsePerformanceScraperService {
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  /// ※プロフィールの取得は HorseProfileScraperService に分離されました。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    // [修正] 過去走の取得状況ポップアップ: 取得の本体は scrapeHorsePerformanceDetailed へ移した。戻り値は今までどおり戦績のリスト（失敗時は空） (v.2026.11.5+26110501)
    final result = await scrapeHorsePerformanceDetailed(horseId);
    return result.records;
  }

  // [追加] 過去走の取得状況ポップアップ: scrapeHorsePerformance と同じ取得で、結果の種類（成功・初出走・失敗）とログイン切れの疑いも返す。
  // 取得のたびに、馬ごとの結果を HorseFetchOutcomeStore に記録する (v.2026.11.5+26110501)
  static Future<HorsePerformanceScrapeResult> scrapeHorsePerformanceDetailed(
      String horseId) async {
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      // [修正] 成績タブ拡充: netkeiba ログイン中はアプリ内 WebView の Cookie を付与する (v.2026.9.22+26092205)
      final requestHeaders = Map<String, String>.from(_headers);
      final cookieHeader = await NetkeibaSessionService.getCookieHeader(url);
      final bool isLoggedIn = cookieHeader != null;
      if (cookieHeader != null) {
        requestHeaders['Cookie'] = cookieHeader;
      }
      final response = await http.get(Uri.parse(url), headers: requestHeaders);

      if (response.statusCode == 200) {
        final document = html.parse(await CharsetConverter.decode('euc-jp', response.bodyBytes));
        final rows = document.querySelectorAll('.db_h_race_results tbody tr');
        final List<HorseRaceRecord> records = [];
        // [追加] 成績タブ拡充: 馬場指数・タイム指数・備考の保存用 (v.2026.9.22+26092205)
        final List<HorsePastRaceExtra> extras = [];
        final fetchedAt = DateTime.now().toIso8601String();
        // [追加] 過去走の取得状況ポップアップ: 新しい走から順のタイム指数の列の文字列（伏せ字の判定用） (v.2026.11.5+26110501)
        final List<String> timeIndexTexts = [];

        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length < 28) continue; // 行のデータが足りない場合はスキップ

          final raceNameLink = cells[4].querySelector('a');
          final String? raceHref = raceNameLink?.attributes['href'];
          // ドメインの強制連結を解除し、そのまま関数へ渡す
          final raceId = raceHref != null ? RaceResultScraperService.getRaceIdFromUrl(raceHref) ?? '' : '';

          final jockeyLink = cells[12].querySelector('a');
          final String? jockeyHref = jockeyLink?.attributes['href'];
          final jockeyId = jockeyHref != null
              ? jockeyHref.split('/').firstWhere(
                  (s) => RegExp(r'^\d{5}$').hasMatch(s), orElse: () => '')
              : '';

          // [修正] netkeibaのテーブル列数（標準28列 / プレミアム仕様33列以上）に応じて取得インデックスを動的に切り替える (v.1.0)
          final bool isPremiumLayout = cells.length >= 33;

          final String cornerPassage = cells[isPremiumLayout ? 25 : 21].text.trim();
          final String pace = cells[isPremiumLayout ? 26 : 22].text.trim();
          final String agari = cells[isPremiumLayout ? 27 : 23].text.trim();
          final String horseWeight = cells[isPremiumLayout ? 28 : 24].text.trim();
          final String winnerOrSecondHorse = cells[isPremiumLayout ? 31 : 26].text.trim();
          final String prizeMoney = cells[isPremiumLayout ? 32 : 27].text.trim();

          records.add(HorseRaceRecord(
            horseId: horseId,
            raceId: raceId,
            date: cells[0].text.trim(),
            venue: cells[1].text.trim(),
            weather: cells[2].text.trim(),
            raceNumber: cells[3].text.trim(),
            raceName: raceNameLink?.text.trim() ?? '',
            numberOfHorses: cells[6].text.trim(),
            frameNumber: cells[7].text.trim(),
            horseNumber: cells[8].text.trim(),
            odds: cells[9].text.trim(),
            popularity: cells[10].text.trim(),
            rank: cells[11].text.trim(),
            jockey: jockeyLink?.text.trim() ?? '',
            jockeyId: jockeyId,
            carriedWeight: cells[13].text.trim(),
            distance: cells[14].text.trim(),
            trackCondition: cells[16].text.trim(),
            time: cells[18].text.trim(),
            margin: cells[19].text.trim(),
            cornerPassage: cornerPassage,
            pace: pace,
            agari: agari,
            horseWeight: horseWeight,
            winnerOrSecondHorse: winnerOrSecondHorse,
            prizeMoney: prizeMoney,
          ));
          // [追加] 成績タブ拡充: 33列レイアウト時のみ、列17=馬場指数・列20=タイム指数・列30=備考を保持する。
          // 未ログイン時は最新走以外が '**' となり null として扱う (v.2026.9.22+26092205)
          if (isPremiumLayout && raceId.isNotEmpty) {
            timeIndexTexts.add(cells[20].text.trim());
            extras.add(HorsePastRaceExtra(
              horseId: horseId,
              raceId: raceId,
              trackIndex: int.tryParse(cells[17].text.trim()),
              timeIndex: int.tryParse(cells[20].text.trim()),
              remark: HorsePastRaceExtra.normalizeScrapedText(cells[30].text),
              horsePageFetchedAt: fetchedAt,
              horsePagePremium: isLoggedIn,
            ));
          }
        }
        // [追加] 成績タブ拡充: 追加情報をマージ保存（失敗しても戦績の戻り値には影響させない） (v.2026.9.22+26092205)
        if (extras.isNotEmpty) {
          try {
            await HorsePastRaceExtraRepository().upsertMerge(extras);
          } catch (e) {
            debugPrint('HorsePerformanceScraperService: extras save failed for $horseId: $e');
          }
        }
        // [追加] 過去走の取得状況ポップアップ: 結果の種類を決めて馬ごとに記録する。ページが正常で戦績が0件なら初出走（失敗ではない） (v.2026.11.5+26110501)
        final status = records.isNotEmpty
            ? HorsePerformanceFetchStatus.ok
            : HorsePerformanceFetchStatus.noRecords;
        final masked = isTimeIndexMasked(timeIndexTexts);
        await _recordOutcome(horseId, status, masked);
        return HorsePerformanceScrapeResult(
          status: status,
          records: records,
          maskedIndexSuspected: masked,
        );
      } else {
        await _recordOutcome(horseId, HorsePerformanceFetchStatus.failed, false);
        return const HorsePerformanceScrapeResult(
          status: HorsePerformanceFetchStatus.failed,
          records: [],
        );
      }
    } catch (e) {
      await _recordOutcome(horseId, HorsePerformanceFetchStatus.failed, false);
      return const HorsePerformanceScrapeResult(
        status: HorsePerformanceFetchStatus.failed,
        records: [],
      );
    }
  }

  // [追加] 過去走の取得状況ポップアップ: 取得結果の記録。記録に失敗しても取得の結果には影響させない（例外を投げない） (v.2026.11.5+26110501)
  static Future<void> _recordOutcome(String horseId,
      HorsePerformanceFetchStatus status, bool maskedIndexSuspected) async {
    final kind = switch (status) {
      HorsePerformanceFetchStatus.ok => HorseFetchOutcomeKind.ok,
      HorsePerformanceFetchStatus.noRecords => HorseFetchOutcomeKind.noRecords,
      HorsePerformanceFetchStatus.failed => HorseFetchOutcomeKind.failed,
    };
    try {
      await HorseFetchOutcomeStore.saveOutcome(
        horseId,
        HorseFetchOutcome(
          kind: kind,
          at: DateTime.now(),
          maskedIndexSuspected: maskedIndexSuspected,
        ),
      );
    } catch (e) {
      debugPrint('HorsePerformanceScraperService: 取得結果の記録に失敗 ($horseId): $e');
    }
  }
}