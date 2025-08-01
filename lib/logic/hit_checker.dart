// lib/logic/hit_checker.dart
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

    final winners = _getWinningHorses(raceResult);
    if (winners.isEmpty) return HitResult();

    for (var purchase in (parsedTicket['購入内容'] as List<dynamic>)) {
      final String ticketType = purchase['式別'];

      // all_combinationsが存在しない場合はスキップ
      if (purchase['all_combinations'] == null) continue;

      final int combinationCount = (purchase['all_combinations'] as List).length;
      final int amountPerBet = (combinationCount > 0)
          ? (purchase['購入金額'] as int)
          : (purchase['購入金額'] as int);

      // 保存済みの組み合わせリストを直接利用
      final List<List<int>> allUserCombinations =
      (purchase['all_combinations'] as List)
          .map((combo) => (combo as List).cast<int>())
          .toList();

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

  // ▼▼▼ 払戻金を探すロジックを全面的に修正 ▼▼▼
  static int _findPayout(List<Refund> refunds, String ticketType, String combinationKey) {
    try {
      final refundInfo = refunds.firstWhere((r) => r.ticketType == ticketType);

      // 文字列を正規化し、順序不問の券種はソートして「正準（canonical）」な比較用文字列を生成する
      String createCanonicalString(String combo, String type) {
        // スペースを削除し、矢印をハイフンに統一
        String normalized = combo.replaceAll(' ', '').replaceAll('→', '-');

        // 馬連、ワイド、3連複、枠連は数字をソートして順序を不問にする
        if (type == '馬連' || type == 'ワイド' || type == '3連複' || type == '枠連') {
          var parts = normalized.split('-');
          // 数字として正しくソートするためにintに変換
          parts.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
          return parts.join('-');
        }
        return normalized;
      }

      // ユーザーの組み合わせを正準形式に変換
      final canonicalUserCombo = createCanonicalString(combinationKey, ticketType);

      // 払戻情報の中に一致するものがあるか探す
      final payout = refundInfo.payouts.firstWhere(
            (p) => createCanonicalString(p.combination, ticketType) == canonicalUserCombo,
        orElse: () => Payout(combination: '', amount: '0', popularity: ''),
      );

      return int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ▼▼▼ 組み合わせキーの生成ロジックをシンプルに修正 ▼▼▼
  static String _formatCombinationToString(String ticketType, List<int> combination, List<String> winners) {
    // 常に数字の小さい順でソートして返すことで比較の一貫性を保つ
    final sortedCombination = List<int>.from(combination)..sort((a, b) => a.compareTo(b));

    switch (ticketType) {
      case '単勝':
      case '複勝':
        return combination.first.toString();
      case '馬単':
      case '3連単':
      // 着順が重要な券種は、元の順序のまま返す
        return combination.join('→');
      default: // 馬連, 3連複, 枠連, ワイド
      // 着順が関係ない券種は、ソートしたものを返す
        return sortedCombination.join('-');
    }
  }
}