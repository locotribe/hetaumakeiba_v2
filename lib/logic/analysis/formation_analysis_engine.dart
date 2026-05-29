// lib/logic/analysis/formation_analysis_engine.dart

import 'package:hetaumakeiba_v2/models/formation_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

class FormationAnalysisEngine {

  /// 分析実行
  // [修正] 引数から totalBudget を削除 (v.2.0)
  FormationAnalysisResult analyze({
    required List<RaceResult> pastRaces,
    required List<PredictionHorseDetail> currentHorses,
  }) {
    // 1. オッズデータの収集 & マトリクス作成
    List<double> winningOdds = [];
    final List<List<int>> matrix = List.generate(18, (_) => [0, 0, 0]);

    for (final race in pastRaces) {
      for (final horse in race.horseResults) {
        int rank = int.tryParse(horse.rank ?? '') ?? 0;
        int pop = int.tryParse(horse.popularity ?? '') ?? 0;
        double odds = double.tryParse(horse.odds?.toString() ?? '') ?? 0.0;

        if (rank >= 1 && rank <= 3) {
          if (odds > 0) winningOdds.add(odds);
          if (pop >= 1 && pop <= 18) {
            matrix[pop - 1][rank - 1]++;
          }
        }
      }
    }

    // 2. オッズラインの計算
    double standardLine = 999.9;
    double maxLine = 0.0;
    if (winningOdds.isNotEmpty) {
      winningOdds.sort();
      maxLine = winningOdds.last;
      int index90 = (winningOdds.length * 0.9).floor();
      if (index90 >= winningOdds.length) index90 = winningOdds.length - 1;
      standardLine = winningOdds[index90];
    }

    // 3. 有効馬フィルタリング
    final Map<int, String> validHorseMap = {};
    // [削除] chaosHorseNames の抽出ロジックを削除 (v.2.0)

    for (final horse in currentHorses) {
      int p = int.tryParse(horse.popularity?.toString() ?? '') ?? 0;
      double o = double.tryParse(horse.odds?.toString() ?? '') ?? 0.0;

      if (p > 0 && o > 0) {
        if (o <= standardLine) {
          validHorseMap[p] = horse.horseName;
        }
      } else if (p > 0) {
        validHorseMap[p] = horse.horseName;
      }
    }

    // 4. PopScoreの構築 (ヘルパー利用)
    final popScores = _buildPopScores(matrix);

    // --- A. 基本フォーメーション (Fixed 1-2-5) ---
    final winSorted = List<_PopScore>.from(popScores)..sort((a, b) => b.winCount.compareTo(a.winCount));
    final placeSorted = List<_PopScore>.from(popScores)..sort((a, b) => b.placeCount.compareTo(a.placeCount));

    List<int> basicR1 = winSorted.take(1).map((e) => e.pop).toList();
    List<int> basicR2 = placeSorted.where((e) => !basicR1.contains(e.pop)).take(2).map((e) => e.pop).toList();
    List<int> basicR3 = placeSorted.where((e) => !basicR1.contains(e.pop)).take(5).map((e) => e.pop).toList();

    // 足切り適用
    basicR1 = basicR1.where((p) => validHorseMap.containsKey(p)).toList();
    basicR2 = basicR2.where((p) => validHorseMap.containsKey(p)).toList();
    basicR3 = basicR3.where((p) => validHorseMap.containsKey(p)).toList();

    // --- B. AI戦術フォーメーション (Dynamic) ---
    String strategyName = "";
    String strategyReason = "";
    String betType = "3連単";
    List<int> stratR1 = [];
    List<int> stratR2 = [];
    List<int> stratR3 = [];

    final top1 = winSorted.isNotEmpty ? winSorted[0] : null;
    final top2 = winSorted.length > 1 ? winSorted[1] : null;

    if (top1 != null && top1.winCount >= 5) {
      // パターン1: 不動の王様 (1頭軸流し)
      strategyName = "1頭軸流し (鉄板)";
      strategyReason = "${top1.pop}番人気の勝率が圧倒的(50%以上)です。ここを頭に固定します。";

      stratR1 = [top1.pop];
      final rivals = placeSorted.where((s) => s.pop != top1.pop && validHorseMap.containsKey(s.pop)).toList();

      stratR2 = rivals.take(4).map((e) => e.pop).toList();
      stratR3 = rivals.take(8).map((e) => e.pop).toList();

      _optimizeFormationPoints(stratR1, stratR2, stratR3, maxPoints: 40);

    } else if (top1 != null && top2 != null && (top1.winCount + top2.winCount) >= 7) {
      // パターン3: 二強対決 (2頭軸)
      strategyName = "2頭軸フォーメーション (一騎打ち)";
      strategyReason = "上位2頭で勝利の大半を占めています。この2頭を1列目に据えます。";

      stratR1 = [top1.pop, top2.pop];
      stratR2 = [top1.pop, top2.pop, ...placeSorted.where((s) => s.pop != top1.pop && s.pop != top2.pop).take(2).map((e) => e.pop)];
      stratR2 = stratR2.where((p) => validHorseMap.containsKey(p)).toSet().toList();

      final others = placeSorted.where((s) => validHorseMap.containsKey(s.pop)).map((e) => e.pop).toList();
      stratR3 = others.take(8).toList();

      _optimizeFormationPoints(stratR1, stratR2, stratR3, maxPoints: 40);

    } else if (top1 != null && top1.placeCount >= 8 && top1.winCount < 3) {
      // パターン2: 安定の軸馬 (勝ち切れないが紐には来る -> 3連複軸)
      strategyName = "3連複1頭軸流し (安定感)";
      strategyReason = "${top1.pop}番人気は勝率は低いものの、複勝率が非常に高いです。3連複の軸に最適です。";
      betType = "3連複";

      stratR1 = [top1.pop];
      final rivals = placeSorted.where((s) => s.pop != top1.pop && validHorseMap.containsKey(s.pop)).toList();

      List<int> opponents = [];
      for (var r in rivals) {
        opponents.add(r.pop);
        int pts = (opponents.length * (opponents.length - 1)) ~/ 2;
        if (pts > 30) {
          opponents.removeLast();
          break;
        }
      }
      stratR2 = opponents;
      stratR3 = opponents;

    } else {
      // パターン5: 混戦 (BOX)
      final boxCandidates = _decideBoxHeads(popScores, validHorseMap, maxPoints: 60);

      if (boxCandidates.length >= 6) {
        strategyName = "3連複BOX (大混戦)";
        strategyReason = "上位が拮抗しすぎています。3連単は点数が増えるため、3連複BOX推奨です。";
        betType = "3連複";
        final box6 = _decideBoxHeads(popScores, validHorseMap, maxPoints: 20, isTrifecta: false);
        stratR1 = box6; stratR2 = box6; stratR3 = box6;
      } else {
        strategyName = "${boxCandidates.length}頭BOX (混戦)";
        strategyReason = "混戦模様です。有力馬${boxCandidates.length}頭のBOXで網を張ります。";
        stratR1 = boxCandidates; stratR2 = boxCandidates; stratR3 = boxCandidates;
      }
    }

    // 5. 点数計算
    // [削除] 買い目の実体生成ループと資金配分ロジックを完全に削除 (v.2.0)
    // [修正] 推定点数(estimatedPoints)のみを数学的に算出するロジックに変更 (v.2.0)
    int estimatedPts = 0;

    if (betType == "3連単") {
      for (int first in stratR1) {
        for (int second in stratR2) {
          if (first == second) continue;
          for (int third in stratR3) {
            if (first == third || second == third) continue;
            estimatedPts++;
          }
        }
      }
    } else {
      if (strategyName.contains("軸")) {
        List<int> opponents = stratR2;
        int n = opponents.length;
        estimatedPts = (n * (n - 1)) ~/ 2; // nC2
      } else {
        int n = stratR1.length;
        estimatedPts = (n * (n - 1) * (n - 2)) ~/ 6; // nC3
      }
    }

    return FormationAnalysisResult(
      frequencyMatrix: matrix,
      basicRank1: basicR1,
      basicRank2: basicR2,
      basicRank3: basicR3,
      strategyRank1: stratR1,
      strategyRank2: stratR2,
      strategyRank3: stratR3,
      standardOddsLine: standardLine,
      maxOddsLine: maxLine,
      validHorseCount: validHorseMap.length,
      strategyName: strategyName,
      strategyReason: strategyReason,
      betType: betType,
      estimatedPoints: estimatedPts,
    );
  }

  // --- Helpers ---

  List<_PopScore> _buildPopScores(List<List<int>> matrix) {
    final List<_PopScore> list = [];
    for (int i = 0; i < 18; i++) {
      int w = matrix[i][0];
      int p = matrix[i][0] + matrix[i][1] + matrix[i][2];
      if (p > 0) {
        list.add(_PopScore(pop: i + 1, winCount: w, placeCount: p));
      }
    }
    return list;
  }

  List<int> _decideBoxHeads(List<_PopScore> scores, Map<int, String> validMap, {required int maxPoints, bool isTrifecta = true}) {
    final sorted = List<_PopScore>.from(scores)..sort((a, b) => b.placeCount.compareTo(a.placeCount));
    final List<int> selected = [];

    for (var s in sorted) {
      if (!validMap.containsKey(s.pop)) continue;

      selected.add(s.pop);
      int n = selected.length;
      int pts = isTrifecta ? (n * (n - 1) * (n - 2)) : (n * (n - 1) * (n - 2)) ~/ 6;

      if (pts > maxPoints) {
        selected.removeLast();
        break;
      }
    }
    if (selected.length < 3) return [];
    return selected;
  }

  void _optimizeFormationPoints(List<int> r1, List<int> r2, List<int> r3, {required int maxPoints}) {
    int calc() {
      int pts = 0;
      for (var x in r1) {
        for (var y in r2) {
          if (x == y) continue;
          for (var z in r3) {
            if (x == z || y == z) continue;
            pts++;
          }
        }
      }
      return pts;
    }

    while (calc() > maxPoints) {
      if (r3.length > r2.length && r3.length > 3) {
        r3.removeLast();
      } else if (r2.length > r1.length && r2.length > 2) {
        r2.removeLast();
      } else {
        if (r3.length > 1) r3.removeLast();
        else break;
      }
    }
  }

// [削除] _calcPlaceWeight, _allocateBudget ヘルパーメソッドを削除 (v.2.0)
}

class _PopScore {
  final int pop;
  final int winCount;
  final int placeCount;
  _PopScore({required this.pop, required this.winCount, required this.placeCount});
}

class MatrixTrapResult {
  final List<int> rank1;
  final List<int> rank2;
  final List<int> rank3;
  final List<FormationTicket> tickets;
  final int estimatedPoints;

  MatrixTrapResult({
    required this.rank1,
    required this.rank2,
    required this.rank3,
    required this.tickets,
    required this.estimatedPoints,
  });
}

class MatrixTrapFormationEngine {
  /// マトリクスデータから排他的なトラップフォーメーションを生成する
  MatrixTrapResult analyze({
    required List<List<int>> frequencyMatrix,
    required Map<int, String> validHorseMap,
  }) {
    // 1. 各着順の最大出現回数を取得し、列ごとの閾値を決定する
    int max1 = 0, max2 = 0, max3 = 0;
    for (int i = 0; i < 18; i++) {
      if (frequencyMatrix[i][0] > max1) max1 = frequencyMatrix[i][0];
      if (frequencyMatrix[i][1] > max2) max2 = frequencyMatrix[i][1];
      if (frequencyMatrix[i][2] > max3) max3 = frequencyMatrix[i][2];
    }

    int threshold1 = max1 >= 2 ? 2 : 1;
    int threshold2 = max2 >= 2 ? 2 : 1;
    int threshold3 = max3 >= 2 ? 2 : 1;

    List<int> r1 = [];
    List<int> r2 = [];
    List<int> r3 = [];

    // 2. 独立判定で各列に候補を追加していく（重複を許容する）
    for (int pop = 1; pop <= 18; pop++) {
      if (!validHorseMap.containsKey(pop)) continue;

      if (frequencyMatrix[pop - 1][0] >= threshold1) r1.add(pop);
      if (frequencyMatrix[pop - 1][1] >= threshold2) r2.add(pop);
      if (frequencyMatrix[pop - 1][2] >= threshold3) r3.add(pop);
    }

    // 3. 買い目生成と矛盾（同一人気の重複）の排除
    List<FormationTicket> tickets = [];
    for (int first in r1) {
      for (int second in r2) {
        if (first == second) continue; // 1着と2着が同じならスキップ

        for (int third in r3) {
          if (first == third || second == third) continue; // 3着が1着・2着と同じならスキップ

          int w1 = frequencyMatrix[first - 1][0];
          int w2 = frequencyMatrix[second - 1][1];
          int w3 = frequencyMatrix[third - 1][2];
          double weight = (w1 + w2 + w3).toDouble();

          tickets.add(FormationTicket(
            popularities: [first, second, third],
            horseNames: [validHorseMap[first]!, validHorseMap[second]!, validHorseMap[third]!],
            weight: weight,
            type: '3連単',
          ));
        }
      }
    }

    tickets.sort((a, b) => b.weight.compareTo(a.weight));

    return MatrixTrapResult(
      rank1: r1,
      rank2: r2,
      rank3: r3,
      tickets: tickets,
      estimatedPoints: tickets.length,
    );
  }
}