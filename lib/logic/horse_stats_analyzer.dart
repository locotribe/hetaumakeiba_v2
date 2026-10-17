// lib/logic/horse_stats_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';
// [削除] 好走条件・個別成績・相対評価の移動 Step5: 個別成績（calculate）と対戦成績（analyzeMatchups）を削除したので、horse_stats_model・race_data・matchup_stats_model の import を外した。
// 個別成績は logic/analysis/horse_record_stats.dart（日付で絞り、取消・除外を数えない）に作り直した (v.2026.10.17+26101710)

class HorseStatsAnalyzer {
  // [削除] 好走条件・個別成績・相対評価の移動 Step5: calculate（出走馬分析の個別成績）と analyzeMatchups（対戦成績）を削除した。
  // analyzeJockeyCombo は出馬表・展開シミュの騎手要素・相対評価が使うので残す (v.2026.10.17+26101710)

  static JockeyComboStats analyzeJockeyCombo({
    required String currentJockeyId,
    required List<HorseRaceRecord> performanceRecords,
    required Map<String, RaceResult> raceResults,
  }) {
    final comboRecords = performanceRecords
        .where((record) => record.jockeyId == currentJockeyId) // jockey -> jockeyId に変更
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
