// lib/logic/hit_checker.dart

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';


/// 的中判定の結果を格納するためのデータクラス
class HitResult {
  final bool isHit; // 1つでも的中したか
  final int totalPayout; // 総払戻金額
  final List<String> hitDetails; // 的中した馬券の詳細リスト
  final int totalRefund;
  final List<String> refundDetails;

  HitResult({
    this.isHit = false,
    this.totalPayout = 0,
    this.hitDetails = const [],
    this.totalRefund = 0,
    this.refundDetails = const [],
  });
}

/// 的中判定を行うサービスクラス
class HitChecker {
  /// メインの判定処理。購入内容とレース結果を元にHitResultを返す
  static HitResult check({
    required Map<String, dynamic> parsedTicket,
    required RaceResult raceResult,
  }) {
    // --- ▼▼▼ ここからが修正箇所 ▼▼▼ ---
    int totalPayout = 0;
    List<String> hitDetails = [];
    int totalRefund = 0;
    List<String> refundDetails = [];

    // 返還対象となる馬番と枠番のリストを作成
    final scratchedHorseNumbers = raceResult.horseResults
        .where((hr) => int.tryParse(hr.rank) == null && hr.rank != '中止')
        .map((hr) => int.parse(hr.horseNumber))
        .toSet();

    final scratchedFrameNumbers = raceResult.horseResults
        .where((hr) => int.tryParse(hr.rank) == null && hr.rank != '中止')
        .map((hr) => int.parse(hr.frameNumber))
        .toSet();

    for (var purchase in (parsedTicket['購入内容'] as List<dynamic>)) {
      final String ticketTypeId = purchase['式別'];
      final String ticketTypeName = bettingDict[ticketTypeId] ?? '不明';
      if (purchase['all_combinations'] == null) continue;

      final int combinationCount = (purchase['all_combinations'] as List).length;
      final int amountPerBet = (combinationCount > 0)
          ? (purchase['購入金額'] as int)
          : (purchase['購入金額'] as int);

      final List<List<int>> allUserCombinations =
      (purchase['all_combinations'] as List)
          .map((combo) => (combo as List).cast<int>())
          .toList();

      final refundInfo = raceResult.refunds.firstWhere(
            (r) => r.ticketTypeId == ticketTypeId,
        orElse: () => Refund(ticketTypeId: '', payouts: []),
      );

      final Set<String> processedHitCombinations = {};

      for (final userCombo in allUserCombinations) {
        // 的中判定
        final matchingPayout = _findPayout(userCombo, refundInfo.payouts, ticketTypeId);
        if (matchingPayout != null) {
          final comboKey = userCombo.join('-');
          if (!processedHitCombinations.contains(comboKey)) {
            final payout = int.tryParse(matchingPayout.amount.replaceAll(',', '')) ?? 0;
            if (payout > 0) {
              final payoutAmount = (payout * amountPerBet) ~/ 100;
              totalPayout += payoutAmount;
              hitDetails.add('$ticketTypeName 的中！ ${matchingPayout.combination} -> $payoutAmount円');
              processedHitCombinations.add(comboKey);
            }
          }
        } else {
          // 的中していない場合のみ、返還判定を行う
          bool isRefundable = false;
          if (ticketTypeName == '枠連') {
            if (userCombo.any((frame) => scratchedFrameNumbers.contains(frame))) {
              isRefundable = true;
            }
          } else {
            if (userCombo.any((horse) => scratchedHorseNumbers.contains(horse))) {
              isRefundable = true;
            }
          }

          if (isRefundable) {
            totalRefund += amountPerBet;
            refundDetails.add('$ticketTypeName 返還: ${userCombo.join('-')} -> $amountPerBet円');
          }
        }
      }
    }

    return HitResult(
      isHit: totalPayout > 0,
      totalPayout: totalPayout,
      hitDetails: hitDetails,
      totalRefund: totalRefund,
      refundDetails: refundDetails,
    );
    // --- ▲▲▲ ここまでが修正箇所 ▲▲▲ ---
  }

  static Payout? _findPayout(List<int> userCombo, List<Payout> payouts, String ticketTypeId) {
    final String? ticketTypeName = bettingDict[ticketTypeId];
    if (ticketTypeName == null) return null;

    for (final payout in payouts) {
      bool isMatch = false;
      switch (ticketTypeName) {
        case '馬連':
        case 'ワイド':
        case '3連複':
        case '枠連':
        // 順序不問の券種はSetで比較
          isMatch = setEquals(userCombo.toSet(), payout.combinationNumbers.toSet());
          break;
        case '単勝':
        case '複勝':
        case '馬単':
        case '3連単':
        // 順序が重要な券種はListで比較
          isMatch = listEquals(userCombo, payout.combinationNumbers);
          break;
      }
      if (isMatch) {
        return payout;
      }
    }
    return null;
  }
}