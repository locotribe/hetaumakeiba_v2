// lib/services/race_result_scraper_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'dart:convert';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/services/race_result_first_scraper_service.dart';

/// netkeiba.comからレース結果の詳細をスクレイピングすることに特化したサービスクラスです。
class RaceResultScraperService {
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// URLからレースIDを抽出するヘルパー関数
  static String? getRaceIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (uri.path.contains('/race/')) {
      final raceId = uri.queryParameters['race_id'];
      if (raceId != null) return raceId;
      if (pathSegments.length > 1 && pathSegments[0] == 'race') {
        return pathSegments[1];
      }
    }
    if (uri.host == 'db.netkeiba.com' && pathSegments.contains('race') && pathSegments.last.isNotEmpty) {
      return pathSegments.last;
    }
    return uri.queryParameters['race_id'];
  }

  static Future<bool> isRaceResultConfirmed(String raceId) async {
    try {
      final url = 'https://race.netkeiba.com/race/result.html?race_id=$raceId';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        return false;
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final resultTable = document.querySelector('#All_Result_Table');
      return resultTable != null;
    } catch (e) {
      print('[ERROR] レース結果確定チェック中にエラー: $e');
      return false;
    }
  }

  /// netkeiba.comのレース結果ページをスクレイピングし、RaceResultオブジェクトを返す
  static Future<RaceResult> scrapeRaceDetails(String url) async {
    try {
      // まずはデータベースページ（db.netkeiba.com）から試行
      final dbUrl = url.replaceFirst('race.netkeiba.com/race/result.html?race_id=', 'db.netkeiba.com/race/');
      final raceId = getRaceIdFromUrl(dbUrl);
      if (raceId == null) {
        throw Exception('無効なURLです: レースIDが取得できませんでした。');
      }

      final response = await http.get(Uri.parse(dbUrl), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode}');
      }

      final decodedBody =
      await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      // データベースページに結果テーブルがあるかチェック
      final resultTable = document.querySelector('table.race_table_01');
      if (resultTable != null && resultTable.querySelectorAll('tr').length > 1) {
        // データがあれば、従来通りのパース処理を実行
        print('INFO: レース結果をデータベースページから取得しました: $raceId');
        final raceTitle = _safeGetText(document.querySelector('div.race_head h1'));
        final raceInfoSpan =
        document.querySelector('div.data_intro p diary_snap_cut span');
        final raceInfo = _safeGetText(raceInfoSpan).replaceAll(RegExp(r'\s+'), ' ');
        final smallTxt = _safeGetText(document.querySelector('p.smalltxt'));
        final raceDate = smallTxt.split(' ').first;
        final raceGrade = raceTitle;
        final horseResults = _parseHorseResults(document);
        final refunds = _parseRefunds(document);
        final cornerPassages = _parseCornerPassages(document);
        final lapTimes = _parseLapTimes(document);

        return RaceResult(
          raceId: raceId,
          raceTitle: raceTitle,
          raceInfo: raceInfo,
          raceDate: raceDate,
          raceGrade: raceGrade,
          horseResults: horseResults,
          refunds: refunds,
          cornerPassages: cornerPassages,
          lapTimes: lapTimes,
        );
      } else {
        // データがなければ、当日の結果ページにフォールバック
        print('INFO: データベースページに結果がありません。当日の結果ページから取得を試みます: $raceId');
        final firstUrl = 'https://race.netkeiba.com/race/result.html?race_id=$raceId';
        return await RaceResultFirstScraperService.scrapeRaceDetails(firstUrl);
      }
    } catch (e) {
      print('[ERROR]スクレイピングエラー: $e');
      // DBページでエラーが発生した場合も、当日の結果ページにフォールバックを試みる
      try {
        final raceId = getRaceIdFromUrl(url);
        print('INFO: エラー発生のため、当日の結果ページから取得を試みます: $raceId');
        final firstUrl = 'https://race.netkeiba.com/race/result.html?race_id=$raceId';
        return await RaceResultFirstScraperService.scrapeRaceDetails(firstUrl);
      } catch (fallbackError) {
        print('[ERROR]フォールバック処理も失敗しました: $fallbackError');
        rethrow; // 両方失敗した場合はエラーを投げる
      }
    }
  }

  /// dom.Elementから安全にテキストを取得するヘルパー関数
  static String _safeGetText(dom.Element? element) {
    return element?.text.trim() ?? '';
  }

  /// HTMLドキュメントから全出走馬のレース結果を解析する
  static List<HorseResult> _parseHorseResults(dom.Document document) {
    final List<HorseResult> results = [];
    final rows = document.querySelectorAll('table.race_table_01 tr');

    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 21) continue;

      final horseLink = cells[3].querySelector('a');
      final horseId = horseLink?.attributes['href']
          ?.split('/')
          .lastWhere((part) => part.isNotEmpty, orElse: () => '') ??
          '';

      results.add(HorseResult(
        rank: _safeGetText(cells[0]),
        frameNumber: _safeGetText(cells[1]),
        horseNumber: _safeGetText(cells[2]),
        horseName: _safeGetText(horseLink),
        horseId: horseId,
        sexAndAge: _safeGetText(cells[4]),
        weightCarried: _safeGetText(cells[5]),
        jockeyName: _safeGetText(cells[6].querySelector('a')),
        time: _safeGetText(cells[7]),
        margin: _safeGetText(cells[8]),
        cornerRanking: _safeGetText(cells[10]),
        agari: _safeGetText(cells[11].querySelector('span')),
        odds: _safeGetText(cells[12]),
        popularity: _safeGetText(cells[13]),
        horseWeight: _safeGetText(cells[14]),
        trainerName: _safeGetText(cells[18].querySelector('a')),
        ownerName: _safeGetText(cells[19].querySelector('a')),
        prizeMoney: _safeGetText(cells[20]),
      ));
    }
    return results;
  }

  /// HTMLドキュメントから払戻情報を解析する
  static List<Refund> _parseRefunds(dom.Document document) {
    final List<Refund> refundList = [];
    final payTables = document.querySelectorAll('dl.pay_block table.pay_table_01');

    for (final table in payTables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final th = row.querySelector('th');
        final tds = row.querySelectorAll('td');
        if (th == null || tds.isEmpty) continue;

        String ticketTypeName = _safeGetText(th);
        if (ticketTypeName == '三連複') {
          ticketTypeName = '3連複';
        }
        if (ticketTypeName == '三連単') {
          ticketTypeName = '3連単';
        }

        String ticketTypeId = bettingDict.entries
            .firstWhere((entry) => entry.value == ticketTypeName,
            orElse: () => const MapEntry('', ''))
            .key;

        final payouts = <Payout>[];

        final combinations =
        tds[0].innerHtml.split('<br>').map((e) => e.trim()).toList();
        final amounts = tds.length > 1
            ? tds[1].innerHtml.split('<br>').map((e) => e.trim()).toList()
            : [];
        final popularities = tds.length > 2
            ? tds[2].innerHtml.split('<br>').map((e) => e.trim()).toList()
            : [];

        for (int i = 0; i < combinations.length; i++) {
          final combinationStr = combinations[i].replaceAll(RegExp(r'\s*→\s*'), '→');
          final combinationNumbers = RegExp(r'\d+')
              .allMatches(combinationStr)
              .map((m) => int.parse(m.group(0)!))
              .toList();

          if (['馬連', 'ワイド', '3連複', '枠連'].contains(ticketTypeName)) {
            combinationNumbers.sort();
          }

          payouts.add(Payout(
            combination: combinationStr,
            amount: i < amounts.length ? amounts[i] : '',
            popularity: i < popularities.length ? popularities[i] : '',
            combinationNumbers: combinationNumbers,
          ));
        }
        refundList.add(Refund(ticketTypeId: ticketTypeId, payouts: payouts));
      }
    }
    // ▼▼▼【ここから追加】▼▼▼
    print('--- START: race_result_scraper_service REFUND DATA ---');
    print(json.encode(refundList.map((r) => r.toJson()).toList()));
    print('--- END: race_result_scraper_service REFUND DATA ---');
    // ▲▲▲【ここまで追加】▲▲▲
    return refundList;
  }

  /// HTMLドキュメントからコーナー通過順位を解析する
  static List<String> _parseCornerPassages(dom.Document document) {
    final List<String> passages = [];
    final table = document.querySelector('table[summary="コーナー通過順位"]');
    if (table == null) return passages;

    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final th = _safeGetText(row.querySelector('th'));
      final td = _safeGetText(row.querySelector('td'));
      if (th.isNotEmpty && td.isNotEmpty) {
        passages.add('$th: $td');
      }
    }
    return passages;
  }

  /// HTMLドキュメントからラップタイムを解析する
  static List<String> _parseLapTimes(dom.Document document) {
    final List<String> laps = [];
    final table = document.querySelector('table[summary="ラップタイム"]');
    if (table == null) return laps;

    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final th = _safeGetText(row.querySelector('th'));
      final td = _safeGetText(row.querySelector('td'));
      if (th.isNotEmpty && td.isNotEmpty) {
        laps.add('$th: $td');
      }
    }
    return laps;
  }
}