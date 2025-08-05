// lib/logic/analytics_logic.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/analytics_summary_model.dart';

// バックグラウンド処理に渡すためのパラメータを格納するクラス
class _AnalyticsIsolateParams {
  final List<QrData> allQrData;
  final Map<String, RaceResult> allRaceResults;
  final int? filterYear;

  _AnalyticsIsolateParams({
    required this.allQrData,
    required this.allRaceResults,
    required this.filterYear,
  });
}

@pragma('vm:entry-point')
Future<String> _calculateAnalyticsDataIsolate(_AnalyticsIsolateParams params) async {
  // この関数はバックグラウンドで実行される
  // データベースアクセスは行わず、受け取ったデータで計算のみ行う
  final allQrData = params.allQrData;
  final allRaceResults = params.allRaceResults;
  final filterYear = params.filterYear;

  // 元のcalculateAnalyticsDataから計算ロジックのみを移植
  TopPayoutInfo? topPayoutInfo;
  final Map<int, YearlySummary> yearlySummaries = {};

  final allQrDataWithResults = allQrData.map((qr) {
    final parsedTicket = json.decode(qr.parsedDataJson) as Map<String, dynamic>;
    final url = generateNetkeibaUrl(
      year: parsedTicket['年'].toString(),
      racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
      round: parsedTicket['回'].toString(),
      day: parsedTicket['日'].toString(),
      race: parsedTicket['レース'].toString(),
    );
    final raceId = ScraperService.getRaceIdFromUrl(url);
    final raceResult = allRaceResults[raceId];
    return {'qrData': qr, 'raceResult': raceResult, 'parsedTicket': parsedTicket};
  }).where((e) => e['raceResult'] != null).toList();

  List<dynamic> filteredData = allQrDataWithResults;
  if (filterYear != null) {
    filteredData = allQrDataWithResults.where((d) {
      final raceResult = d['raceResult'] as RaceResult;
      final year = int.tryParse(raceResult.raceDate.split(RegExp(r'[年月日]')).first) ?? 0;
      return year == filterYear;
    }).toList();
  }

  final availableYears = allQrDataWithResults.map((d) {
    try {
      final dateParts = (d['raceResult'] as RaceResult).raceDate.split(RegExp(r'[年月日]'));
      return int.parse(dateParts[0]);
    } catch (e) {
      return 0;
    }
  }).toSet().where((y) => y != 0).toList();

  final yearsToProcess = filterYear != null ? [filterYear] : availableYears;
  for (final year in yearsToProcess) {
    yearlySummaries[year] = YearlySummary(year: year);
  }

  final tempTicketTypeSummaries = <String, CategorySummary>{};
  final tempGradeSummaries = <String, CategorySummary>{};
  final tempVenueSummaries = <String, CategorySummary>{};
  final tempDistanceSummaries = <String, CategorySummary>{};
  final tempTrackSummaries = <String, CategorySummary>{};
  final tempPurchaseMethodSummaries = <String, CategorySummary>{};

  final logic = AnalyticsLogic(); // ヘルパーメソッドを使うためだけにインスタンス化

  for (final d in filteredData) {
    final raceResult = d['raceResult'] as RaceResult;
    final parsedTicket = d['parsedTicket'] as Map<String, dynamic>;
    final year = int.tryParse(raceResult.raceDate.split(RegExp(r'[年月日]')).first) ?? 0;

    final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
    final totalInvestment = parsedTicket['合計金額'] as int? ?? 0;
    final totalPayout = hitResult.totalPayout;
    final isHit = hitResult.isHit;

    if (isHit && (topPayoutInfo == null || totalPayout > topPayoutInfo.payout)) {
      topPayoutInfo = TopPayoutInfo(payout: totalPayout, raceName: raceResult.raceTitle, raceDate: raceResult.raceDate);
    }

    if (yearlySummaries.containsKey(year)) {
      final yearlySummary = yearlySummaries[year]!;
      yearlySummary.totalInvestment += totalInvestment;
      yearlySummary.totalPayout += totalPayout;
      yearlySummary.totalBetCount += 1;
      if (isHit) yearlySummary.totalHitCount += 1;
    }

    final venue = parsedTicket['開催場'] as String? ?? '不明';
    final purchaseMethod = parsedTicket['方式'] as String? ?? '不明';
    final gradePattern = RegExp(r'\((G(?:I{1,3}|[1-3])|Jpn[1-3])\)', caseSensitive: false);
    final gradeMatch = gradePattern.firstMatch(raceResult.raceTitle);
    String grade = 'その他';
    if (gradeMatch != null) grade = logic._normalizeGrade(gradeMatch.group(1)!);
    final raceInfoParts = raceResult.raceInfo.split('/');
    final trackAndDistance = raceInfoParts.isNotEmpty ? raceInfoParts[0].trim() : '不明';
    final track = trackAndDistance.startsWith('ダ') ? 'ダート' : (trackAndDistance.startsWith('障') ? '障害' : '芝');
    final distance = trackAndDistance.replaceAll(RegExp(r'[^0-9]'), '');

    logic._updateCategorySummary(summaryMap: tempVenueSummaries, key: venue, investment: totalInvestment, payout: totalPayout, isHit: isHit);
    logic._updateCategorySummary(summaryMap: tempGradeSummaries, key: grade, investment: totalInvestment, payout: totalPayout, isHit: isHit);
    logic._updateCategorySummary(summaryMap: tempTrackSummaries, key: track, investment: totalInvestment, payout: totalPayout, isHit: isHit);
    if (distance.isNotEmpty) {
      logic._updateCategorySummary(summaryMap: tempDistanceSummaries, key: '${distance}m', investment: totalInvestment, payout: totalPayout, isHit: isHit);
    }
    logic._updateCategorySummary(summaryMap: tempPurchaseMethodSummaries, key: purchaseMethod, investment: totalInvestment, payout: totalPayout, isHit: isHit);

    final purchaseDetails = parsedTicket['購入内容'] as List? ?? [];
    for (var detail in purchaseDetails) {
      if (detail is Map<String, dynamic>) {
        final ticketTypeId = detail['式別'] as String? ?? '不明';
        final investment = detail['購入金額'] as int? ?? 0;
        tempTicketTypeSummaries.putIfAbsent(ticketTypeId, () => CategorySummary(name: ticketTypeId));
        final summary = tempTicketTypeSummaries[ticketTypeId]!;
        summary.investment += investment;
        summary.betCount += 1;
      }
    }
    if (isHit) {
      final reversedBettingDict = {for (var e in bettingDict.entries) e.value: e.key};
      for (final hitDetailString in hitResult.hitDetails) {
        final match = RegExp(r'(.+?)\s*的中！.* -> (\d+)円').firstMatch(hitDetailString);
        if (match != null && match.groupCount >= 2) {
          final ticketTypeName = match.group(1)!.trim();
          final ticketTypeId = reversedBettingDict[ticketTypeName];
          final payout = int.tryParse(match.group(2)!) ?? 0;
          if (ticketTypeId != null && tempTicketTypeSummaries.containsKey(ticketTypeId)) {
            final summary = tempTicketTypeSummaries[ticketTypeId]!;
            summary.payout += payout;
            summary.hitCount += 1;
          }
        }
      }
    }
  }

  final analyticsData = AnalyticsData(
    yearlySummaries: yearlySummaries,
    gradeSummaries: tempGradeSummaries.values.toList(),
    venueSummaries: tempVenueSummaries.values.toList(),
    distanceSummaries: tempDistanceSummaries.values.toList(),
    trackSummaries: tempTrackSummaries.values.toList(),
    ticketTypeSummaries: tempTicketTypeSummaries.values.toList(),
    purchaseMethodSummaries: tempPurchaseMethodSummaries.values.toList(),
    topPayout: topPayoutInfo,
  );

  return analyticsData.toJson();
}


class AnalyticsLogic {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<AnalyticsData> calculateAnalyticsDataInBackground({int? filterYear}) async {
    // 1. UIスレッドで、計算に必要なデータをすべてDBから取得する
    final allQrData = await _dbHelper.getAllQrData();
    final allRaceResults = <String, RaceResult>{};
    for (final qrData in allQrData) {
      final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = ScraperService.getRaceIdFromUrl(url);
      if (raceId != null && allRaceResults[raceId] == null) {
        final raceResult = await _dbHelper.getRaceResult(raceId);
        if (raceResult != null) {
          allRaceResults[raceId] = raceResult;
        }
      }
    }

    // 2. 取得した元データをバックグラウンド処理に渡して、重い計算を実行させる
    final params = _AnalyticsIsolateParams(
      allQrData: allQrData,
      allRaceResults: allRaceResults,
      filterYear: filterYear,
    );
    final jsonResult = await compute(_calculateAnalyticsDataIsolate, params);

    // 3. 計算結果のJSONをデコードして返す
    return AnalyticsData.fromJson(jsonResult);
  }

  /// 検出したグレード表記を正規化する
  String _normalizeGrade(String rawGrade) {
    // 大文字に変換し、ローマ数字の全角文字を半角に統一
    final upperGrade = rawGrade.toUpperCase().replaceAll('Ⅰ', 'I').replaceAll('Ⅱ', 'II').replaceAll('Ⅲ', 'III');

    const gradeMap = {
      'G1': 'G1', 'GI': 'G1',
      'G2': 'G2', 'GII': 'G2',
      'G3': 'G3', 'GIII': 'G3',
      'JPN1': 'Jpn1',
      'JPN2': 'Jpn2',
      'JPN3': 'Jpn3',
    };

    return gradeMap[upperGrade] ?? 'その他';
  }

  // カテゴリ別の集計マップを更新または新規追加するヘルパー関数
  void _updateCategorySummary({
    required Map<String, CategorySummary> summaryMap,
    required String key,
    required int investment,
    required int payout,
    required bool isHit,
  }) {
    if (key.isEmpty || key == 'その他') return; // 「その他」は集計から除外する場合
    summaryMap.putIfAbsent(key, () => CategorySummary(name: key));
    final summary = summaryMap[key]!;
    summary.investment += investment;
    summary.payout += payout;
    summary.betCount += 1;
    if (isHit) {
      summary.hitCount += 1;
    }
  }

// 元の calculateAnalyticsData メソッドはバックグラウンド処理に移行したため、ここでは不要
}