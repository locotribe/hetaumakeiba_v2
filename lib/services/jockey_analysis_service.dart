// lib/services/jockey_analysis_service.dart

import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class JockeyAnalysisService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Map<String, JockeyStats>> analyzeAllJockeys(List<String> jockeyIdsInRace, {PredictionRaceData? raceData}) async {
    final allRaceResults = await _dbHelper.getAllRaceResults();
    final Map<String, JockeyStats> analysisResults = {};

    String? currentCourseKey;
    // ★修正: raceDataが存在する場合にコース特定を試みる
    if (raceData != null) {
      String venue = '';
      // ★修正: raceDetails1ではなく、venueプロパティから開催場名を探す
      // raceData.venue (例: "1回東京1日目") に "東京" が含まれているかチェック
      for (final entry in racecourseDict.entries) {
        if (raceData.venue.contains(entry.value)) {
          venue = entry.value;
          break;
        }
      }

      // 距離情報は引き続き raceDetails1 から取得
      final String details = raceData.raceDetails1 ?? '';
      final distance = _extractDistance(details);

      if (venue.isNotEmpty && distance.isNotEmpty) {
        currentCourseKey = '$venue $distance';
      }
    }

    for (final jockeyId in jockeyIdsInRace) {
      String jockeyName = '';
      final overallStats = FactorStats();
      final popularHorseStats = FactorStats();
      final unpopularHorseStats = FactorStats();
      final statsByCourse = <String, FactorStats>{};

      for (final raceResult in allRaceResults.values) {
        for (final horseResult in raceResult.horseResults) {
          if (horseResult.jockeyId == jockeyId) {
            jockeyName = horseResult.jockeyName;
            _updateFactorStats(overallStats, horseResult, raceResult);

            final popularity = int.tryParse(horseResult.popularity);
            if (popularity != null) {
              if (popularity >= 1 && popularity <= 3) {
                _updateFactorStats(popularHorseStats, horseResult, raceResult);
              } else if (popularity >= 6) {
                _updateFactorStats(unpopularHorseStats, horseResult, raceResult);
              }
            }

            final venue = _extractVenue(raceResult.raceId);
            final distance = _extractDistance(raceResult.raceInfo);
            if (venue.isNotEmpty && distance.isNotEmpty) {
              final courseKey = '$venue $distance';
              _updateFactorStats(statsByCourse.putIfAbsent(courseKey, () => FactorStats()), horseResult, raceResult);
            }
          }
        }
      }

      if (overallStats.raceCount > 0) {
        analysisResults[jockeyId] = JockeyStats(
          jockeyId: jockeyId,
          jockeyName: jockeyName,
          overallStats: overallStats,
          courseStats: currentCourseKey != null ? statsByCourse[currentCourseKey] : null,
          popularHorseStats: popularHorseStats,
          unpopularHorseStats: unpopularHorseStats,
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
}