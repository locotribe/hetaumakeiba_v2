// lib/logic/hit_checker.dart
import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

// itertoolsパッケージの代替となる、組み合わせ計算の関数
Iterable<List<T>> combinations<T>(List<T> elements, int r) sync* {
  if (r < 0 || r > elements.length) return;
  if (r == 0) {
    yield <T>[];
  } else {
    for (int i = 0; i <= elements.length - r; i++) {
      var head = elements[i];
      var tail = elements.sublist(i + 1);
      for (var subcomb in combinations(tail, r - 1)) {
        yield [head, ...subcomb];
      }
    }
  }
}

Iterable<List<T>> permutations<T>(List<T> elements, int r) sync* {
  if (r < 0 || r > elements.length) return;
  if (r == 0) {
    yield <T>[];
  } else {
    for (int i = 0; i < elements.length; i++) {
      var rest = [...elements]..removeAt(i);
      for (var subperm in permutations(rest, r - 1)) {
        yield [elements[i], ...subperm];
      }
    }
  }
}


/// 的中判定の結果を格納するためのデータクラス
class HitResult {
  final bool isHit; // 1つでも的中したか
  final int totalPayout; // 総払戻金額
  final List<String> hitDetails; // 的中した馬券の詳細リスト

  HitResult({
    this.isHit = false,
    this.totalPayout = 0,
    this.hitDetails = const [],
  });
}

/// 的中判定を行うサービスクラス
class HitChecker {
  /// メインの判定処理。購入内容とレース結果を元にHitResultを返す
  static HitResult check({
    required Map<String, dynamic> parsedTicket,
    required RaceResult raceResult,
  }) {
    int totalPayout = 0;
    List<String> hitDetails = [];

    for (var purchase in (parsedTicket['購入内容'] as List<dynamic>)) {
      final String ticketTypeId = purchase['式別'];

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
      if (refundInfo.payouts.isEmpty) continue;

      final Map<String, Payout> uniqueHits = {};

      for (final userCombo in allUserCombinations) {
        final matchingPayout = _findPayout(userCombo, refundInfo.payouts, ticketTypeId);
        if (matchingPayout != null) {
          uniqueHits[matchingPayout.combination] = matchingPayout;
        }
      }

      if (uniqueHits.isNotEmpty) {
        final String ticketTypeName = bettingDict[ticketTypeId] ?? '不明';
        for (final hitPayout in uniqueHits.values) {
          final payout = int.tryParse(hitPayout.amount.replaceAll(',', '')) ?? 0;
          if (payout > 0) {
            final payoutAmount = (payout * amountPerBet) ~/ 100;
            totalPayout += payoutAmount;
            hitDetails.add('$ticketTypeName 的中！ ${hitPayout.combination} -> ${payoutAmount}円');
          }
        }
      }
    }

    return HitResult(
      isHit: totalPayout > 0,
      totalPayout: totalPayout,
      hitDetails: hitDetails,
    );
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