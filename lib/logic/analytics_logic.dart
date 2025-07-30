// lib/logic/analytics_logic.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';


class AnalyticsLogic {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // カテゴリ別の集計マップを更新または新規追加するヘルパー関数
  void _updateCategorySummary({
    required Map<String, CategorySummary> summaryMap,
    required String key,
    required int investment,
    required int payout,
    required bool isHit,
  }) {
    if (key.isEmpty) return;
    summaryMap.putIfAbsent(key, () => CategorySummary(name: key));
    final summary = summaryMap[key]!;
    summary.investment += investment;
    summary.payout += payout;
    summary.betCount += 1;
    if (isHit) {
      summary.hitCount += 1;
    }
  }

  Future<AnalyticsData> calculateAnalyticsData() async {
    final allQrData = await _dbHelper.getAllQrData();

    final Map<int, YearlySummary> yearlySummaries = {};
    final Map<String, CategorySummary> gradeSummaries = {};
    final Map<String, CategorySummary> venueSummaries = {};
    final Map<String, CategorySummary> distanceSummaries = {};
    final Map<String, CategorySummary> trackSummaries = {};
    final Map<String, CategorySummary> ticketTypeSummaries = {};
    final Map<String, CategorySummary> purchaseMethodSummaries = {};

    for (final QrData qrData in allQrData) {
      final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;

      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = ScraperService.getRaceIdFromUrl(url);
      if (raceId == null) continue;

      final raceResult = await _dbHelper.getRaceResult(raceId);
      if (raceResult == null) continue;

      final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
      final int totalInvestment = parsedTicket['合計金額'] as int? ?? 0;
      final int totalPayout = hitResult.totalPayout;
      final bool isHit = hitResult.isHit;

      try {
        final dateParts = raceResult.raceDate.split(RegExp(r'[年月日]'));
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);

        yearlySummaries.putIfAbsent(year, () => YearlySummary(year: year));
        final yearlySummary = yearlySummaries[year]!;

        yearlySummary.totalInvestment += totalInvestment;
        yearlySummary.totalPayout += totalPayout;
        yearlySummary.totalBetCount += 1;
        if (isHit) {
          yearlySummary.totalHitCount += 1;
        }

        yearlySummary.monthlyData[month - 1].investment += totalInvestment;
        yearlySummary.monthlyData[month - 1].payout += totalPayout;

        yearlySummary.monthlyPurchaseDetails.add(MonthlyPurchaseDetail(
          month: month,
          raceName: raceResult.raceTitle,
          investment: totalInvestment,
          payout: totalPayout,
        ));

      } catch (e) {
        print('Date parsing error for analytics: ${raceResult.raceDate}');
      }

      final venue = parsedTicket['開催場'] as String? ?? '不明';
      final purchaseMethod = parsedTicket['方式'] as String? ?? '不明';

      final gradeMatch = RegExp(r'\((G[1-3])\)').firstMatch(raceResult.raceTitle);
      final grade = gradeMatch?.group(1) ?? 'その他';

      final raceInfoParts = raceResult.raceInfo.split('/');
      final trackAndDistance = raceInfoParts.isNotEmpty ? raceInfoParts[0].trim() : '不明';
      final track = trackAndDistance.startsWith('ダ') ? 'ダート' : (trackAndDistance.startsWith('障') ? '障害' : '芝');
      final distance = trackAndDistance.replaceAll(RegExp(r'[^0-9]'), '');

      _updateCategorySummary(summaryMap: venueSummaries, key: venue, investment: totalInvestment, payout: totalPayout, isHit: isHit);
      _updateCategorySummary(summaryMap: gradeSummaries, key: grade, investment: totalInvestment, payout: totalPayout, isHit: isHit);
      _updateCategorySummary(summaryMap: trackSummaries, key: track, investment: totalInvestment, payout: totalPayout, isHit: isHit);
      if (distance.isNotEmpty) {
        _updateCategorySummary(summaryMap: distanceSummaries, key: '${distance}m', investment: totalInvestment, payout: totalPayout, isHit: isHit);
      }
      _updateCategorySummary(summaryMap: purchaseMethodSummaries, key: purchaseMethod, investment: totalInvestment, payout: totalPayout, isHit: isHit);

      // --- ▼▼▼ Step 5 で修正 ▼▼▼ ---
      // 式別の投資額と払戻額を正確に集計するロジック
      final purchaseDetails = parsedTicket['購入内容'] as List? ?? [];

      // まず、各券種の投資額を集計
      for (var detail in purchaseDetails) {
        if (detail is Map<String, dynamic>) {
          final ticketType = detail['式別'] as String? ?? '不明';
          final investment = detail['購入金額'] as int? ?? 0;

          ticketTypeSummaries.putIfAbsent(ticketType, () => CategorySummary(name: ticketType));
          final summary = ticketTypeSummaries[ticketType]!;
          summary.investment += investment;
          summary.betCount += 1; // ここでは馬券の枚数ではなく、券種ごとの購入回数をカウント
        }
      }

      // 次に、的中詳細から払戻額を各券種に加算
      if (isHit) {
        for (final hitDetailString in hitResult.hitDetails) {
          // '馬連 的中！ ... -> 500円' のような文字列を解析
          final match = RegExp(r'(.+?)\s*的中！.* -> (\d+)円').firstMatch(hitDetailString);
          if (match != null && match.groupCount >= 2) {
            final ticketType = match.group(1)!.trim();
            final payout = int.tryParse(match.group(2)!) ?? 0;

            if (ticketTypeSummaries.containsKey(ticketType)) {
              final summary = ticketTypeSummaries[ticketType]!;
              summary.payout += payout;
              summary.hitCount += 1; // 的中した券種のみカウント
            }
          }
        }
      }
      // --- ▲▲▲ Step 5 で修正 ▲▲▲ ---
    }

    // 不要になった按分ロジックは削除

    return AnalyticsData(
      yearlySummaries: yearlySummaries,
      gradeSummaries: gradeSummaries.values.toList(),
      venueSummaries: venueSummaries.values.toList(),
      distanceSummaries: distanceSummaries.values.toList(),
      trackSummaries: trackSummaries.values.toList(),
      ticketTypeSummaries: ticketTypeSummaries.values.toList(),
      purchaseMethodSummaries: purchaseMethodSummaries.values.toList(),
    );
  }
}
