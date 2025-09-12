// lib/services/jockey_analysis_service.dart

import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart'; // ★追加

class JockeyAnalysisService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Map<String, JockeyStats>> analyzeAllJockeys(List<String> jockeyIdsInRace, {PredictionRaceData? raceData}) async { // ★引数追加
    final allRaceResults = await _dbHelper.getAllRaceResults();
    final Map<String, JockeyStats> analysisResults = {};

    // ★追加：現在のコースを特定するキーを作成
    String? currentCourseKey;
    if (raceData != null && raceData.raceDetails1 != null) {
      String venue = '';
      // raceDetails1から開催場名を抽出する
      for (final entry in racecourseDict.entries) {
        if (raceData.raceDetails1!.contains(entry.value)) {
          venue = entry.value;
          break;
        }
      }
      final distance = _extractDistance(raceData.raceDetails1!);
      // ★★★ ここからが差し替え箇所 ★★★
      print('--- Jockey Analysis Debug ---');
      print('【デバッグ】raceData.venue: "$venue"');
      print('【デバッグ】raceData.raceDetails1: "${raceData.raceDetails1}"');
      print('【デバッグ】抽出されたdistance: "$distance"');
      // ★★★ ここまでが差し替え箇所 ★★★
      if (venue.isNotEmpty && distance.isNotEmpty) {
        currentCourseKey = '$venue $distance';
      }
    }

    // ★★★ ここからが追加箇所 ★★★
    print('【デバッグ】現在のレースのコース特定キー: $currentCourseKey');
    print('--------------------------');
    // ★★★ ここまでが追加箇所 ★★★

    for (final jockeyId in jockeyIdsInRace) {
      String jockeyName = '';
      final overallStats = FactorStats();
      final Map<String, FactorStats> statsByCourse = {};
      final Map<String, FactorStats> statsByTrackCondition = {};

      for (final raceResult in allRaceResults.values) {
        for (final horseResult in raceResult.horseResults) {
          if (horseResult.jockeyId == jockeyId) {
            jockeyName = horseResult.jockeyName;
            _updateFactorStats(overallStats, horseResult, raceResult);

            final venue = _extractVenue(raceResult.raceId);
            final distance = _extractDistance(raceResult.raceInfo);

            if (venue.isNotEmpty && distance.isNotEmpty) {
              final courseKey = '$venue $distance';
              _updateFactorStats(statsByCourse.putIfAbsent(courseKey, () => FactorStats()), horseResult, raceResult);
            }

            final trackCondition = _extractTrackCondition(raceResult.raceInfo);
            if (trackCondition.isNotEmpty) {
              _updateFactorStats(statsByTrackCondition.putIfAbsent(trackCondition, () => FactorStats()), horseResult, raceResult);
            }
          }
        }
      }

      if (overallStats.raceCount > 0) {
        // ★★★ ここからが追加箇所 ★★★
        if (jockeyId == jockeyIdsInRace.first) { // 最初の騎手についてのみ、集計された全コースキーを出力
          print('【デバッグ】DBから集計されたコースキーのサンプル: ${statsByCourse.keys.take(5).join(', ')}');
        }
        // ★★★ ここまでが追加箇所 ★★★
        analysisResults[jockeyId] = JockeyStats(
          jockeyId: jockeyId,
          jockeyName: jockeyName,
          overallStats: overallStats,
          courseStats: currentCourseKey != null ? statsByCourse[currentCourseKey] : null, // ★追加：該当コースの成績をセット
          statsByCourse: statsByCourse,
          statsByTrackCondition: statsByTrackCondition,
        );
      }
    }
    return analysisResults;
  }

  void _updateFactorStats(FactorStats stats, HorseResult horseResult, RaceResult raceResult) {
    stats.raceCount++;
    final rank = int.tryParse(horseResult.rank);
    if (rank != null) {
      if (rank == 1) stats.winCount++;
      if (rank <= 2) stats.placeCount++;
      if (rank <= 3) stats.showCount++;
    }

    final odds = double.tryParse(horseResult.odds);
    if (odds != null) {
      stats.totalWinInvestment += 100;
      if (rank == 1) {
        stats.totalWinPayout += 100 * odds;
      }
    }

    final fukushoRefund = raceResult.refunds.firstWhere((r) => r.ticketTypeId == '2', orElse: () => Refund(ticketTypeId: '', payouts: []));
    if (fukushoRefund.payouts.isNotEmpty) {
      stats.totalShowInvestment += 100;
      if (rank != null && rank <= 3) {
        final horseNumber = int.tryParse(horseResult.horseNumber);
        for (final payout in fukushoRefund.payouts) {
          if (payout.combinationNumbers.contains(horseNumber)) {
            stats.totalShowPayout += double.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
            break;
          }
        }
      }
    }
  }

  String _extractVenue(String raceId) {
    if (raceId.length >= 6) {
      final code = raceId.substring(4, 6);
      return racecourseDict[code] ?? '';
    }
    return '';
  }

  String _extractDistance(String raceInfo) {
    final distanceMatch = RegExp(r'(芝|ダ|障)(?:右|左|直線)?(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      return '${distanceMatch.group(1)}${distanceMatch.group(2)}';
    }
    return '';
  }

  String _extractTrackCondition(String raceInfo) {
    if (raceInfo.contains('稍重')) return '稍重';
    if (raceInfo.contains('重')) return '重';
    if (raceInfo.contains('不良')) return '不良';
    if (raceInfo.contains('良')) return '良';
    return '';
  }
}