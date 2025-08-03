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
import 'package:hetaumakeiba_v2/models/analytics_summary_model.dart';


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

    final Map<int, YearlySummary> yearlySummaries = {};
    final Map<String, CategorySummary> gradeSummaries = {};
    final Map<String, CategorySummary> venueSummaries = {};
    final Map<String, CategorySummary> distanceSummaries = {};
    final Map<String, CategorySummary> trackSummaries = {};
    final Map<String, CategorySummary> ticketTypeSummaries = {};
    final Map<String, CategorySummary> purchaseMethodSummaries = {};

    final now = DateTime.now();
    final currentYear = now.year;

    // --- 年次サマリーのキャッシュ処理 ---
    final availableYears = allQrData.map((qr) {
      try {
        final parsedData = json.decode(qr.parsedDataJson);
        if (parsedData == null || parsedData['年'] == null || parsedData['開催場'] == null || parsedData['回'] == null || parsedData['日'] == null || parsedData['レース'] == null) return 0;
        final raceId = ScraperService.getRaceIdFromUrl(generateNetkeibaUrl(
          year: parsedData['年'].toString(),
          racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedData['開催場']).key,
          round: parsedData['回'].toString(),
          day: parsedData['日'].toString(),
          race: parsedData['レース'].toString(),
        ));
        if (raceId == null || allRaceResults[raceId] == null) return 0;
        final dateParts = allRaceResults[raceId]!.raceDate.split(RegExp(r'[年月日]'));
        return int.parse(dateParts[0]);
      } catch (e) {
        return 0;
      }
    }).toSet().where((y) => y != 0).toList();

    for (final year in availableYears) {
      final yearlySummary = YearlySummary(year: year);
      yearlySummaries[year] = yearlySummary;

      if (year == currentYear) {
        // 現在の年は常にリアルタイム計算
      } else {
        // 過去の年はキャッシュを確認
        bool allMonthsCached = true;
        final monthlyCache = <int, AnalyticsSummary>{};
        for (int month = 1; month <= 12; month++) {
          final period = "$year-${month.toString().padLeft(2, '0')}";
          final summary = await _dbHelper.getSummary(period);
          if (summary == null) {
            allMonthsCached = false;
            break;
          }
          monthlyCache[month] = summary;
        }

        if (allMonthsCached) {
          for (int month = 1; month <= 12; month++) {
            final summary = monthlyCache[month]!;
            yearlySummary.monthlyData[month - 1].investment = summary.totalInvestment;
            yearlySummary.monthlyData[month - 1].payout = summary.totalPayout;
            yearlySummary.totalInvestment += summary.totalInvestment;
            yearlySummary.totalPayout += summary.totalPayout;
            yearlySummary.totalHitCount += summary.hitCount;
            yearlySummary.totalBetCount += summary.betCount;
          }

          // カテゴリ別集計のために、キャッシュヒットした年のデータもループ処理が必要
          final yearlyQrDataForCategory = allQrData.where((qr) {
            try {
              final raceResult = allRaceResults[ScraperService.getRaceIdFromUrl(generateNetkeibaUrl(
                year: json.decode(qr.parsedDataJson)['年'].toString(),
                racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == json.decode(qr.parsedDataJson)['開催場']).key,
                round: json.decode(qr.parsedDataJson)['回'].toString(),
                day: json.decode(qr.parsedDataJson)['日'].toString(),
                race: json.decode(qr.parsedDataJson)['レース'].toString(),
              ))];
              return raceResult != null && raceResult.raceDate.startsWith(year.toString());
            } catch (e) {
              return false;
            }
          });

          for (final qrData in yearlyQrDataForCategory) {
            final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
            final url = generateNetkeibaUrl(
              year: parsedTicket['年'].toString(),
              racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
              round: parsedTicket['回'].toString(),
              day: parsedTicket['日'].toString(),
              race: parsedTicket['レース'].toString(),
            );
            final raceId = ScraperService.getRaceIdFromUrl(url);
            final raceResult = allRaceResults[raceId];
            if (raceResult == null) continue;

            final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
            final int totalInvestment = parsedTicket['合計金額'] as int? ?? 0;
            final int totalPayout = hitResult.totalPayout;
            final bool isHit = hitResult.isHit;

            try {
              final dateParts = raceResult.raceDate.split(RegExp(r'[年月日]'));
              final month = int.parse(dateParts[1]);
              yearlySummary.monthlyPurchaseDetails.add(MonthlyPurchaseDetail(
                month: month,
                raceName: raceResult.raceTitle,
                investment: totalInvestment,
                payout: totalPayout,
              ));
            } catch (e) {
              print('Date parsing error for analytics: ${raceResult.raceDate}');
            }

            // カテゴリ別集計
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
            final purchaseDetails = parsedTicket['購入内容'] as List? ?? [];
            for (var detail in purchaseDetails) {
              if (detail is Map<String, dynamic>) {
                final ticketTypeId = detail['式別'] as String? ?? '不明';
                final investment = detail['購入金額'] as int? ?? 0;
                ticketTypeSummaries.putIfAbsent(ticketTypeId, () => CategorySummary(name: ticketTypeId));
                final summary = ticketTypeSummaries[ticketTypeId]!;
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
                  if (ticketTypeId != null && ticketTypeSummaries.containsKey(ticketTypeId)) {
                    final summary = ticketTypeSummaries[ticketTypeId]!;
                    summary.payout += payout;
                    summary.hitCount += 1;
                  }
                }
              }
            }
          }
          continue; // この年の処理は完了
        }
      }

      // リアルタイム計算 (現在の年、またはキャッシュミスした過去の年)
      final monthlyTotals = List.generate(12, (_) => {'investment': 0, 'payout': 0, 'hitCount': 0, 'betCount': 0});
      final yearlyQrData = allQrData.where((qr) {
        try {
          final raceResult = allRaceResults[ScraperService.getRaceIdFromUrl(generateNetkeibaUrl(
            year: json.decode(qr.parsedDataJson)['年'].toString(),
            racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == json.decode(qr.parsedDataJson)['開催場']).key,
            round: json.decode(qr.parsedDataJson)['回'].toString(),
            day: json.decode(qr.parsedDataJson)['日'].toString(),
            race: json.decode(qr.parsedDataJson)['レース'].toString(),
          ))];
          return raceResult != null && raceResult.raceDate.startsWith(year.toString());
        } catch (e) {
          return false;
        }
      });

      for (final qrData in yearlyQrData) {
        final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
        final url = generateNetkeibaUrl(
          year: parsedTicket['年'].toString(),
          racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
          round: parsedTicket['回'].toString(),
          day: parsedTicket['日'].toString(),
          race: parsedTicket['レース'].toString(),
        );
        final raceId = ScraperService.getRaceIdFromUrl(url);
        final raceResult = allRaceResults[raceId];
        if (raceResult == null) continue;

        final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
        final int totalInvestment = parsedTicket['合計金額'] as int? ?? 0;
        final int totalPayout = hitResult.totalPayout;
        final bool isHit = hitResult.isHit;

        try {
          final dateParts = raceResult.raceDate.split(RegExp(r'[年月日]'));
          final month = int.parse(dateParts[1]);

          monthlyTotals[month - 1]['investment'] = (monthlyTotals[month - 1]['investment'] ?? 0) + totalInvestment;
          monthlyTotals[month - 1]['payout'] = (monthlyTotals[month - 1]['payout'] ?? 0) + totalPayout;
          monthlyTotals[month - 1]['betCount'] = (monthlyTotals[month - 1]['betCount'] ?? 0) + 1;
          if (isHit) {
            monthlyTotals[month - 1]['hitCount'] = (monthlyTotals[month - 1]['hitCount'] ?? 0) + 1;
          }

          yearlySummary.monthlyPurchaseDetails.add(MonthlyPurchaseDetail(
            month: month,
            raceName: raceResult.raceTitle,
            investment: totalInvestment,
            payout: totalPayout,
          ));
        } catch (e) {
          print('Date parsing error for analytics: ${raceResult.raceDate}');
        }

        // カテゴリ別集計
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
        final purchaseDetails = parsedTicket['購入内容'] as List? ?? [];
        for (var detail in purchaseDetails) {
          if (detail is Map<String, dynamic>) {
            final ticketTypeId = detail['式別'] as String? ?? '不明';
            final investment = detail['購入金額'] as int? ?? 0;
            ticketTypeSummaries.putIfAbsent(ticketTypeId, () => CategorySummary(name: ticketTypeId));
            final summary = ticketTypeSummaries[ticketTypeId]!;
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
              if (ticketTypeId != null && ticketTypeSummaries.containsKey(ticketTypeId)) {
                final summary = ticketTypeSummaries[ticketTypeId]!;
                summary.payout += payout;
                summary.hitCount += 1;
              }
            }
          }
        }
      }

      // 計算結果をYearlySummaryに反映し、必要ならキャッシュ保存
      for (int month = 1; month <= 12; month++) {
        final totals = monthlyTotals[month - 1];
        yearlySummary.monthlyData[month - 1].investment = totals['investment']!;
        yearlySummary.monthlyData[month - 1].payout = totals['payout']!;
        yearlySummary.totalInvestment += totals['investment']!;
        yearlySummary.totalPayout += totals['payout']!;
        yearlySummary.totalHitCount += totals['hitCount']!;
        yearlySummary.totalBetCount += totals['betCount']!;

        if (year != currentYear) {
          final period = "$year-${month.toString().padLeft(2, '0')}";
          final summaryToCache = AnalyticsSummary(
            period: period,
            totalInvestment: totals['investment']!,
            totalPayout: totals['payout']!,
            hitCount: totals['hitCount']!,
            betCount: totals['betCount']!,
            lastCalculated: now.toIso8601String(),
          );
          await _dbHelper.insertOrUpdateSummary(summaryToCache);
        }
      }
    }

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