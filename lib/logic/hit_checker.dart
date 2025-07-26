// lib/logic/hit_checker.dart
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

Iterable<List<T>> combinations<T>(List<T> elements, int r) sync* {
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

    final winners = _getWinningHorses(raceResult);
    if (winners.isEmpty) return HitResult();

    for (var purchase in (parsedTicket['購入内容'] as List<dynamic>)) {
      final String purchaseMethod = parsedTicket['方式'] ?? '通常';
      final String ticketType = purchase['式別'];

      final int combinationCount = purchase['組合せ数'] ?? 1;
      final int amountPerBet = (combinationCount > 0)
          ? (purchase['購入金額'] as int) ~/ combinationCount
          : (purchase['購入金額'] as int);

      final List<List<int>> allUserCombinations = _generateUserCombinations(
        purchaseMethod: purchaseMethod,
        ticketType: ticketType,
        purchaseData: purchase,
      );

      final Set<String> hitCombinationStrings = {};

      for (final userCombo in allUserCombinations) {
        if (_isCombinationHit(ticketType, userCombo, winners)) {
          final combinationKey = _formatCombinationToString(ticketType, userCombo, winners);
          hitCombinationStrings.add(combinationKey);
        }
      }

      if (hitCombinationStrings.isNotEmpty) {
        for (final hitComboStr in hitCombinationStrings) {
          final payout = _findPayout(raceResult.refunds, ticketType, hitComboStr);
          if (payout > 0) {
            final payoutAmount = (payout * amountPerBet) ~/ 100;
            totalPayout += payoutAmount;
            hitDetails.add('$ticketType 的中！ $hitComboStr -> ${payoutAmount}円');
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

  static List<String> _getWinningHorses(RaceResult raceResult) {
    final top3 = raceResult.horseResults
        .where((h) {
      final rank = int.tryParse(h.rank);
      return rank != null && rank >= 1 && rank <= 3;
    })
        .toList()
      ..sort((a, b) => int.parse(a.rank).compareTo(int.parse(b.rank)));

    return top3.map((h) => h.horseNumber).toList();
  }

  static List<List<int>> _generateUserCombinations({
    required String purchaseMethod,
    required String ticketType,
    required Map<String, dynamic> purchaseData,
  }) {
    try {
      switch (purchaseMethod) {
        case '通常':
        case '応援馬券':
          if (purchaseData['馬番'] is List) {
            return [(purchaseData['馬番'] as List).cast<int>()];
          }
          return [];
        case 'ボックス':
          if (purchaseData['馬番'] is List) {
            final horses = (purchaseData['馬番'] as List).cast<int>();
            if (ticketType == '馬単' || ticketType == '3連単') {
              int r = (ticketType == '馬単') ? 2 : 3;
              if (horses.length < r) return [];
              return permutations(horses, r).toList();
            } else {
              int r = (ticketType == '馬連' || ticketType == 'ワイド' || ticketType == '枠連') ? 2 : 3;
              if (horses.length < r) return [];
              return combinations(horses, r).toList();
            }
          }
          return [];
        case 'ながし':
          List<int> axis;
          if (purchaseData['軸'] is List) {
            axis = (purchaseData['軸'] as List).cast<int>();
          } else if (purchaseData['軸'] is int) {
            axis = [purchaseData['軸'] as int];
          } else {
            return [];
          }

          if (purchaseData['相手'] is List) {
            final opponents = (purchaseData['相手'] as List).cast<int>();
            if (axis.isEmpty || opponents.isEmpty) return [];


            if (ticketType == '馬連' || ticketType == 'ワイド' || ticketType == '枠連') {
              return opponents.map((o) => [axis.first, o]).toList();
            } else if (ticketType == '馬単') {
              return opponents.map((o) => [axis.first, o]).toList();
            } else if (ticketType == '3連複') {
              if(axis.length == 1) { // 軸1頭
                if (opponents.length < 2) return [];
                return combinations(opponents, 2).map((pair) => [axis.first, ...pair]).toList();
              } else if (axis.length == 2) { // 軸2頭
                return opponents.map((o) => [...axis, o]).toList();
              }
            }
          }
          return [];
        case 'フォーメーション':
          if (purchaseData['馬番'] is List) {
            final groups = (purchaseData['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            if (ticketType == '3連複' && groups.length == 3) {
              List<List<int>> result = [];
              for (var i in groups[0]) {
                for (var j in groups[1]) {
                  for (var k in groups[2]) {
                    final combo = {i, j, k};
                    if (combo.length == 3) {
                      result.add(combo.toList());
                    }
                  }
                }
              }
              return result;
            }
          }
          return [];
        default:
          return [];
      }
    } catch (e) {
      print('組み合わせ生成中にエラー: $e / data: $purchaseData');
      return [];
    }
  }

  static bool _isCombinationHit(String ticketType, List<int> userCombo, List<String> winners) {
    if (winners.isEmpty) return false;
    final winningInts = winners.map((e) => int.parse(e)).toList();
    final userSet = userCombo.toSet();

    switch (ticketType) {
      case '単勝':
        if (winningInts.isEmpty) return false;
        return userCombo.first == winningInts[0];
      case '複勝':
        if (winningInts.length < 3) return false;
        return winningInts.sublist(0,3).contains(userCombo.first);
      case '馬連':
      case '枠連':
        if (winners.length < 2) return false;
        final winningPair = {winningInts[0], winningInts[1]};
        return winningPair.difference(userSet).isEmpty;
      case 'ワイド':
        if (winners.length < 3) return false;
        final winningPairs = [
          {winningInts[0], winningInts[1]},
          {winningInts[0], winningInts[2]},
          {winningInts[1], winningInts[2]},
        ];
        return winningPairs.any((pair) => pair.difference(userSet).isEmpty);
      case '馬単':
        if (winners.length < 2) return false;
        return userCombo[0] == winningInts[0] && userCombo[1] == winningInts[1];
      case '3連複':
        if (winners.length < 3) return false;
        final winningTrio = {winningInts[0], winningInts[1], winningInts[2]};
        return winningTrio.difference(userSet).isEmpty;
      case '3連単':
        if (winners.length < 3) return false;
        return userCombo[0] == winningInts[0] &&
            userCombo[1] == winningInts[1] &&
            userCombo[2] == winningInts[2];
      default:
        return false;
    }
  }

  static int _findPayout(List<Refund> refunds, String ticketType, String combinationKey) {
    try {
      final refundInfo = refunds.firstWhere((r) => r.ticketType == ticketType);

      if (ticketType == '馬単' || ticketType == '3連単') {
        final payout = refundInfo.payouts.firstWhere((p) => p.combination == combinationKey, orElse: () => Payout(combination: '', amount: '0', popularity: ''));
        return int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
      } else {
        final combinationSet = combinationKey.split(RegExp(r'\s*-\s*')).toSet();
        for (var payout in refundInfo.payouts) {
          final payoutSet = payout.combination.split(RegExp(r'\s*-\s*')).toSet();
          if (payoutSet.length == combinationSet.length && payoutSet.difference(combinationSet).isEmpty) {
            return int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
          }
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static String _formatCombinationToString(String ticketType, List<int> combination, List<String> winners) {
    switch (ticketType) {
      case '単勝':
      case '複勝':
        return combination.first.toString();
      case '馬単':
      case '3連単':
        return combination.join(' → ');
      case 'ワイド':
        final winningInts = winners.map((e) => int.parse(e)).toSet();
        final hitCombo = combination.where((h) => winningInts.contains(h)).toList()..sort();
        return hitCombo.join(' - ');
      default: // 馬連, 3連複, 枠連
        return (combination..sort()).join(' - ');
    }
  }
}
