// lib/logic/ai/formation_analysis_engine.dart

import 'package:hetaumakeiba_v2/models/formation_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class FormationAnalysisEngine {

  /// 分析実行
  FormationAnalysisResult analyze({
    required List<RaceResult> pastRaces,
    required List<PredictionHorseDetail> currentHorses,
    int totalBudget = 10000, // デフォルト予算
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
    final List<String> chaosHorseNames = [];

    for (final horse in currentHorses) {
      int p = int.tryParse(horse.popularity?.toString() ?? '') ?? 0;
      double o = double.tryParse(horse.odds?.toString() ?? '') ?? 0.0;

      if (p > 0 && o > 0) {
        if (o <= standardLine) {
          validHorseMap[p] = horse.horseName;
        } else if (o <= maxLine) {
          chaosHorseNames.add('${horse.horseName}($p人/${o}倍)');
        }
      } else if (p > 0) {
        validHorseMap[p] = horse.horseName;
      }
    }

    // 4. PopScoreの構築 (ヘルパー利用)
    final popScores = _buildPopScores(matrix);

    // --- A. 基本フォーメーション (Fixed 1-2-5) ---
    // 単純にWinPts順、PlacePts順で選ぶ
    final winSorted = List<_PopScore>.from(popScores)..sort((a, b) => b.winCount.compareTo(a.winCount));
    final placeSorted = List<_PopScore>.from(popScores)..sort((a, b) => b.placeCount.compareTo(a.placeCount));

    List<int> basicR1 = winSorted.take(1).map((e) => e.pop).toList();
    List<int> basicR2 = placeSorted.take(2).map((e) => e.pop).toList();
    List<int> basicR3 = placeSorted.take(5).map((e) => e.pop).toList();

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

    // 戦術判定ロジック
    // 1位と2位のスコアを取得
    final top1 = winSorted.isNotEmpty ? winSorted[0] : null;
    final top2 = winSorted.length > 1 ? winSorted[1] : null;

    if (top1 != null && top1.winCount >= 5) {
      // パターン1: 不動の王様 (1頭軸流し)
      // 相手は予算(例:30点)に収まるようにPlace順で選抜
      strategyName = "1頭軸流し (鉄板)";
      strategyReason = "${top1.pop}番人気の勝率が圧倒的(50%以上)です。ここを頭に固定します。";

      stratR1 = [top1.pop];
      // 相手候補を抽出
      final rivals = placeSorted.where((s) => s.pop != top1.pop && validHorseMap.containsKey(s.pop)).toList();

      // 2列目: 3~4頭, 3列目: 点数が許す限り
      stratR2 = rivals.take(4).map((e) => e.pop).toList();
      stratR3 = rivals.take(8).map((e) => e.pop).toList(); // 仮置き

      // 点数調整 (3列目を削る)
      _optimizeFormationPoints(stratR1, stratR2, stratR3, maxPoints: 40);

    } else if (top1 != null && top2 != null && (top1.winCount + top2.winCount) >= 7) {
      // パターン3: 二強対決 (2頭軸)
      strategyName = "2頭軸フォーメーション (一騎打ち)";
      strategyReason = "上位2頭で勝利の大半を占めています。この2頭を1列目に据えます。";

      stratR1 = [top1.pop, top2.pop];
      stratR2 = [top1.pop, top2.pop, ...placeSorted.where((s) => s.pop != top1.pop && s.pop != top2.pop).take(2).map((e) => e.pop)];
      stratR2 = stratR2.where((p) => validHorseMap.containsKey(p)).toSet().toList(); // 重複排除 & 足切り

      final others = placeSorted.where((s) => validHorseMap.containsKey(s.pop)).map((e) => e.pop).toList();
      stratR3 = others.take(8).toList(); // 仮置き

      _optimizeFormationPoints(stratR1, stratR2, stratR3, maxPoints: 40);

    } else if (top1 != null && top1.placeCount >= 8 && top1.winCount < 3) {
      // パターン2: 安定の軸馬 (勝ち切れないが紐には来る -> 3連複軸)
      strategyName = "3連複1頭軸流し (安定感)";
      strategyReason = "${top1.pop}番人気は勝率は低いものの、複勝率が非常に高いです。3連複の軸に最適です。";
      betType = "3連複";

      stratR1 = [top1.pop];
      // 相手はPlace順に選ぶ
      final rivals = placeSorted.where((s) => s.pop != top1.pop && validHorseMap.containsKey(s.pop)).toList();

      // nC2 で点数を計算しながら相手を増やす
      List<int> opponents = [];
      for (var r in rivals) {
        opponents.add(r.pop);
        int pts = (opponents.length * (opponents.length - 1)) ~/ 2; // nC2
        if (pts > 30) {
          opponents.removeLast();
          break;
        }
      }
      stratR2 = opponents;
      stratR3 = opponents; // 3連複軸流しの場合、R2,R3は相手リストとして扱う

    } else {
      // パターン5: 混戦 (BOX)
      // BOX頭数を自動決定
      final boxCandidates = _decideBoxHeads(popScores, validHorseMap, maxPoints: 60); // 3連単60点=5頭BOXまで

      if (boxCandidates.length >= 6) {
        strategyName = "3連複BOX (大混戦)";
        strategyReason = "上位が拮抗しすぎています。3連単は点数が増えるため、3連複BOX推奨です。";
        betType = "3連複";
        // 3連複なら6頭でも20点
        final box6 = _decideBoxHeads(popScores, validHorseMap, maxPoints: 20, isTrifecta: false);
        stratR1 = box6; stratR2 = box6; stratR3 = box6;
      } else {
        strategyName = "${boxCandidates.length}頭BOX (混戦)";
        strategyReason = "混戦模様です。有力馬${boxCandidates.length}頭のBOXで網を張ります。";
        stratR1 = boxCandidates; stratR2 = boxCandidates; stratR3 = boxCandidates;
      }
    }

    // 5. 買い目の生成
    final List<FormationTicket> tickets = [];
    int estimatedPts = 0;

    if (betType == "3連単") {
      // BOX戦略の場合、stratR1~R3は同じリストなので全通り生成される
      // フォーメーションの場合、指定通り生成される
      for (int first in stratR1) {
        for (int second in stratR2) {
          if (first == second) continue;
          for (int third in stratR3) {
            if (first == third || second == third) continue;

            int w1 = matrix[first - 1][0] == 0 ? 1 : matrix[first - 1][0] * 5;
            int w2 = matrix[second - 1][1] == 0 ? 1 : matrix[second - 1][1] * 2;
            int w3 = matrix[third - 1][2] == 0 ? 1 : matrix[third - 1][2];
            double weight = (w1 + w2 + w3).toDouble();

            tickets.add(FormationTicket(
              popularities: [first, second, third],
              horseNames: [validHorseMap[first]!, validHorseMap[second]!, validHorseMap[third]!],
              weight: weight,
              type: '3連単',
            ));
            estimatedPts++;
          }
        }
      }
    } else {
      // 3連複
      if (strategyName.contains("軸")) {
        // 軸流し (R1が軸, R2が相手)
        int axis = stratR1[0];
        List<int> opponents = stratR2;
        int n = opponents.length;
        for (int i = 0; i < n; i++) {
          for (int j = i + 1; j < n; j++) {
            int p2 = opponents[i];
            int p3 = opponents[j];
            int w = _calcPlaceWeight(matrix, axis) + _calcPlaceWeight(matrix, p2) + _calcPlaceWeight(matrix, p3);

            tickets.add(FormationTicket(
              popularities: [axis, p2, p3],
              horseNames: [validHorseMap[axis]!, validHorseMap[p2]!, validHorseMap[p3]!],
              weight: w.toDouble(),
              type: '3連複',
            ));
            estimatedPts++;
          }
        }
      } else {
        // BOX
        List<int> boxList = stratR1;
        int n = boxList.length;
        for (int i = 0; i < n; i++) {
          for (int j = i + 1; j < n; j++) {
            for (int k = j + 1; k < n; k++) {
              int p1 = boxList[i]; int p2 = boxList[j]; int p3 = boxList[k];
              int w = _calcPlaceWeight(matrix, p1) + _calcPlaceWeight(matrix, p2) + _calcPlaceWeight(matrix, p3);
              tickets.add(FormationTicket(
                popularities: [p1, p2, p3],
                horseNames: [validHorseMap[p1]!, validHorseMap[p2]!, validHorseMap[p3]!],
                weight: w.toDouble(),
                type: '3連複',
              ));
              estimatedPts++;
            }
          }
        }
      }
    }

    tickets.sort((a, b) => b.weight.compareTo(a.weight));

    // 6. 資金配分の計算
    final budgetAllocation = _allocateBudget(tickets, totalBudget);

    return FormationAnalysisResult(
      frequencyMatrix: matrix,
      basicRank1: basicR1,
      basicRank2: basicR2,
      basicRank3: basicR3,
      strategyRank1: stratR1,
      strategyRank2: stratR2,
      strategyRank3: stratR3,
      tickets: tickets,
      standardOddsLine: standardLine,
      maxOddsLine: maxLine,
      chaosHorses: chaosHorseNames,
      validHorseCount: validHorseMap.length,
      strategyName: strategyName,
      strategyReason: strategyReason,
      betType: betType,
      estimatedPoints: estimatedPts,
      budgetAllocation: budgetAllocation, // 追加
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
    // Place順にソート
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
    // BOXは最低3頭いないと成立しない
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
      // 3列目 -> 2列目 の順で削る
      if (r3.length > r2.length && r3.length > 3) {
        r3.removeLast();
      } else if (r2.length > r1.length && r2.length > 2) {
        r2.removeLast();
      } else {
        // これ以上削れないか、1列目を削るしかない場合
        if (r3.length > 1) r3.removeLast();
        else break;
      }
    }
  }

  int _calcPlaceWeight(List<List<int>> matrix, int pop) {
    return matrix[pop-1][0] + matrix[pop-1][1] + matrix[pop-1][2];
  }

  Map<FormationTicket, int> _allocateBudget(List<FormationTicket> tickets, int totalBudget) {
    if (tickets.isEmpty) return {};

    double totalWeight = tickets.fold(0.0, (p, t) => p + t.weight);
    if (totalWeight == 0) return {};

    final Map<FormationTicket, int> result = {};
    int allocated = 0;

    for (var t in tickets) {
      int bet = (totalBudget * (t.weight / totalWeight)).floor();
      // 100円単位にするなら
      bet = (bet ~/ 100) * 100;
      if (bet < 100) bet = 100; // 最低100円

      result[t] = bet;
      allocated += bet;
    }

    // 予算オーバーしないように調整(今回は単純に返す)
    return result;
  }
}

class _PopScore {
  final int pop;
  final int winCount;
  final int placeCount;
  _PopScore({required this.pop, required this.winCount, required this.placeCount});
}