// lib/logic/horse_stats_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/matchup_stats_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';

class HorseStatsAnalyzer {
  static HorseStats calculate({
    required List<HorseRaceRecord> performanceRecords,
    required Map<String, RaceResult> raceResults,
  }) {
    if (performanceRecords.isEmpty) {
      return HorseStats();
    }

    int winCount = 0;
    int placeCount = 0;
    int showCount = 0;
    double totalWinInvestment = 0;
    double totalWinPayout = 0;
    double totalShowInvestment = 0;
    double totalShowPayout = 0;

    for (final record in performanceRecords) {
      final rank = int.tryParse(record.rank);
      if (rank == null) continue; // 着順が数値でない場合はスキップ

      if (rank == 1) winCount++;
      if (rank <= 2) placeCount++;
      if (rank <= 3) showCount++;

      // 単勝回収率の計算
      final odds = double.tryParse(record.odds);
      if (odds != null) {
        totalWinInvestment += 100; // 1レース100円投資と仮定
        if (rank == 1) {
          totalWinPayout += 100 * odds;
        }
      }

      // 複勝回収率の計算
      final raceResult = raceResults[record.raceId];
      if (raceResult != null) {
        final refundInfo = raceResult.refunds.firstWhere(
              (r) => r.ticketTypeId == '2', // '2'は複勝
          orElse: () => Refund(ticketTypeId: '', payouts: []),
        );

        if (refundInfo.payouts.isNotEmpty) {
          totalShowInvestment += 100; // 1レース100円投資と仮定
          if (rank <= 3) {
            // 複勝は3着以内に入った馬が複数いる場合があるため、該当馬の払戻金を探す
            for (final payout in refundInfo.payouts) {
              final horseNumber = int.tryParse(record.horseNumber);
              if (horseNumber != null && payout.combinationNumbers.contains(horseNumber)) {
                final amount = int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
                totalShowPayout += amount;
                break; // 該当馬の払戻を見つけたらループを抜ける
              }
            }
          }
        }
      }
    }

    final raceCount = performanceRecords.length;
    return HorseStats(
      raceCount: raceCount,
      winRate: raceCount > 0 ? (winCount / raceCount) * 100 : 0,
      placeRate: raceCount > 0 ? (placeCount / raceCount) * 100 : 0,
      showRate: raceCount > 0 ? (showCount / raceCount) * 100 : 0,
      winRecoveryRate: totalWinInvestment > 0 ? (totalWinPayout / totalWinInvestment) * 100 : 0,
      showRecoveryRate: totalShowInvestment > 0 ? (totalShowPayout / totalShowInvestment) * 100 : 0,
    );
  }

  static List<MatchupStats> analyzeMatchups({
    required List<PredictionHorseDetail> horses,
    required Map<String, List<HorseRaceRecord>> allPerformanceRecords,
  }) {
    final matchups = <MatchupStats>[];

    // 全ての馬のペアを総当たりでチェック
    for (int i = 0; i < horses.length; i++) {
      for (int j = i + 1; j < horses.length; j++) {
        final horseA = horses[i];
        final horseB = horses[j];

        final recordsA = allPerformanceRecords[horseA.horseId] ?? [];
        final recordsB = allPerformanceRecords[horseB.horseId] ?? [];

        // 両馬が出走した共通のレースIDを探す
        final raceIdsA = recordsA.map((r) => r.raceId).toSet();
        final raceIdsB = recordsB.map((r) => r.raceId).toSet();
        final commonRaceIds = raceIdsA.intersection(raceIdsB).where((id) => id.isNotEmpty);

        if (commonRaceIds.isEmpty) {
          continue; // 対戦経験がなければ次のペアへ
        }

        int matchupCount = 0;
        int horseAWins = 0;

        for (final raceId in commonRaceIds) {
          final recordA = recordsA.firstWhere((r) => r.raceId == raceId);
          final recordB = recordsB.firstWhere((r) => r.raceId == raceId);

          final rankA = int.tryParse(recordA.rank);
          final rankB = int.tryParse(recordB.rank);

          // 両馬の着順が有効な数値の場合のみ集計
          if (rankA != null && rankB != null) {
            matchupCount++;
            if (rankA < rankB) {
              horseAWins++; // Aの着順がBより良ければAの勝利
            }
          }
        }

        if (matchupCount > 0) {
          matchups.add(MatchupStats(
            horseIdA: horseA.horseId,
            horseIdB: horseB.horseId,
            matchupCount: matchupCount,
            horseAWins: horseAWins,
          ));
        }
      }
    }
    return matchups;
  }

  static JockeyComboStats analyzeJockeyCombo({
    required String currentJockeyId,
    required List<HorseRaceRecord> performanceRecords,
    required Map<String, RaceResult> raceResults,
  }) {
    final comboRecords = performanceRecords
        .where((record) => record.jockeyId == currentJockeyId)
        .toList();

    if (comboRecords.isEmpty) {
      return JockeyComboStats(isFirstRide: true);
    }

    int winCount = 0;
    int placeCount = 0;
    int showCount = 0;
    double totalWinInvestment = 0;
    double totalWinPayout = 0;
    double totalShowInvestment = 0;
    double totalShowPayout = 0;

    for (final record in comboRecords) {
      final rank = int.tryParse(record.rank);
      if (rank == null) continue;

      if (rank == 1) winCount++;
      if (rank <= 2) placeCount++;
      if (rank <= 3) showCount++;

      // 単勝回収率
      final odds = double.tryParse(record.odds);
      if (odds != null) {
        totalWinInvestment += 100;
        if (rank == 1) {
          totalWinPayout += 100 * odds;
        }
      }

      // 複勝回収率
      final raceResult = raceResults[record.raceId];
      if (raceResult != null) {
        final refundInfo = raceResult.refunds.firstWhere(
              (r) => r.ticketTypeId == '2', // '2'は複勝
          orElse: () => Refund(ticketTypeId: '', payouts: []),
        );

        if (refundInfo.payouts.isNotEmpty) {
          totalShowInvestment += 100;
          if (rank <= 3) {
            for (final payout in refundInfo.payouts) {
              final horseNumber = int.tryParse(record.horseNumber);
              if (horseNumber != null && payout.combinationNumbers.contains(horseNumber)) {
                final amount = int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
                totalShowPayout += amount;
                break;
              }
            }
          }
        }
      }
    }

    final rideCount = comboRecords.length;
    final otherCount = rideCount - showCount;
    final recordString = '$winCount-${placeCount - winCount}-${showCount - placeCount}-$otherCount';

    return JockeyComboStats(
      isFirstRide: false,
      rideCount: rideCount,
      winRate: rideCount > 0 ? (winCount / rideCount) * 100 : 0,
      placeRate: rideCount > 0 ? (placeCount / rideCount) * 100 : 0,
      showRate: rideCount > 0 ? (showCount / rideCount) * 100 : 0,
      winRecoveryRate: totalWinInvestment > 0 ? (totalWinPayout / totalWinInvestment) * 100 : 0,
      showRecoveryRate: totalShowInvestment > 0 ? (totalShowPayout / totalShowInvestment) * 100 : 0,
      recordString: recordString,
    );
  }
}
