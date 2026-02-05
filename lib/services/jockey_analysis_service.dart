// lib/services/jockey_analysis_service.dart

import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class JockeyAnalysisService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Map<String, JockeyStats>> analyzeAllJockeys(List<String> jockeyIdsInRace, {PredictionRaceData? raceData}) async {
    print('DEBUG: ========== ジョッキー分析開始(修正版) ==========');

    final allRaceResults = await _dbHelper.getAllRaceResults();
    print('DEBUG: データベースから取得した過去レース総数: ${allRaceResults.length}件');

    final Map<String, JockeyStats> analysisResults = {};

    String? currentCourseKey;
    String targetVenue = '';

    // 1. 今回のレース（ターゲット）の情報解析
    if (raceData != null) {
      // 【強化ポイント】会場(Venue)の特定ロジックを3段構えにする

      // 手段A: レースIDから直接抽出 (DB検索と完全に一致させるため最優先)
      targetVenue = _extractVenue(raceData.raceId);
      print('DEBUG: 手段A(ID抽出)の結果 -> "$targetVenue" (ID: ${raceData.raceId})');

      // 手段B: 詳細テキストから辞書マッチング (ID抽出失敗時の保険)
      if (targetVenue.isEmpty) {
        final String details = raceData.raceDetails1 ?? '';
        for (final val in racecourseDict.values) {
          if (details.contains(val)) {
            targetVenue = val;
            print('DEBUG: 手段B(詳細テキスト検索)で発見 -> "$targetVenue"');
            break;
          }
        }
      }

      // 手段C: raceData.venue から辞書マッチング (最終手段)
      if (targetVenue.isEmpty) {
        for (final entry in racecourseDict.entries) {
          if (raceData.venue.contains(entry.value)) {
            targetVenue = entry.value;
            break;
          }
        }
      }

      // 距離の抽出
      final String details = raceData.raceDetails1 ?? '';
      final distance = _extractDistance(details);

      print('DEBUG: [ターゲットレース最終判定]');
      print('DEBUG:   レース名: ${raceData.raceName}');
      print('DEBUG:   判定結果 -> 会場: "$targetVenue", 距離: "$distance"');

      if (targetVenue.isNotEmpty && distance.isNotEmpty) {
        currentCourseKey = '$targetVenue $distance';
        print('DEBUG:   ★生成された検索キー: "$currentCourseKey"');
      } else {
        print('DEBUG:   ★検索キー生成失敗 (会場か距離が取得できませんでした)');
        // 辞書の中身が空でないか念のため確認ログ
        // print('DEBUG:   (参考) 辞書サンプル: ${racecourseDict.entries.take(3).map((e) => '${e.key}:${e.value}').join(', ')}');
      }
    }

    bool isFirstJockey = true;
    int debugMatchCount = 0;

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

            // 過去データの抽出
            final venue = _extractVenue(raceResult.raceId);
            final distance = _extractDistance(raceResult.raceInfo);

            // デバッグログ (最初のジョッキーのみ)
            if (isFirstJockey) {
              if (targetVenue.isNotEmpty && venue == targetVenue) {
                final dbKey = '$venue $distance';
                final isMatch = (currentCourseKey != null && dbKey == currentCourseKey);

                if (isMatch) {
                  debugMatchCount++;
                }

                // マッチしたデータのサンプルを表示
                if (isMatch && debugMatchCount <= 3) {
                  print('DEBUG: [マッチ成功] Key="$dbKey" (DB RaceID: ${raceResult.raceId})');
                }
              }
            }

            if (venue.isNotEmpty && distance.isNotEmpty) {
              final courseKey = '$venue $distance';
              _updateFactorStats(statsByCourse.putIfAbsent(courseKey, () => FactorStats()), horseResult, raceResult);
            }
          }
        }
      }

      if (isFirstJockey) {
        print('DEBUG: 最初のジョッキー($jockeyName)の処理完了。マッチ件数: $debugMatchCount');
        isFirstJockey = false;
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
    print('DEBUG: ========== ジョッキー分析終了 ==========');
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
    // レースIDの5,6桁目が場所コード (例: 202505... -> 05 -> 東京)
    if (raceId.length >= 6) {
      final code = raceId.substring(4, 6);
      return racecourseDict[code] ?? '';
    }
    return '';
  }

  String _extractDistance(String raceInfo) {
    // (芝|ダ|障) の後に、数字以外の文字([^0-9]*?)が来て、最後に数字(\d+)mが来るパターン
    final distanceMatch = RegExp(r'(芝|ダ|障)[^0-9]*?(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      return '${distanceMatch.group(1)}${distanceMatch.group(2)}';
    }
    return '';
  }
}