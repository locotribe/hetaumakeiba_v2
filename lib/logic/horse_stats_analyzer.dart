// lib/logic/horse_stats_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

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
}
