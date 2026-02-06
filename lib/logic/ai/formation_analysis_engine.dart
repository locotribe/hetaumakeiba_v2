// lib/logic/ai/formation_analysis_engine.dart

import 'package:hetaumakeiba_v2/models/formation_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class FormationAnalysisEngine {

  /// 分析実行
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
        // オッズ不明時は一旦有効とする
        validHorseMap[p] = horse.horseName;
      }
    }

    // 4. ポイント計算とランキング作成
    List<_PopStats> statsList = [];
    for (int i = 0; i < 18; i++) {
      int winCount = matrix[i][0];
      int totalCount = matrix[i][0] + matrix[i][1] + matrix[i][2];
      if (totalCount == 0) continue;

      statsList.add(_PopStats(
        pop: i + 1,
        winCount: winCount,
        totalCount: totalCount,
        winPts: winCount * 10,
        totalPts: totalCount,
      ));
    }

    // WinPts順 (1着性能)
    List<_PopStats> winRanking = List.from(statsList);
    winRanking.sort((a, b) {
      int cmp = b.winPts.compareTo(a.winPts);
      if (cmp != 0) return cmp;
      return b.totalPts.compareTo(a.totalPts);
    });

    // TotalPts順 (複勝性能)
    List<_PopStats> totalRanking = List.from(statsList);
    totalRanking.sort((a, b) => b.totalPts.compareTo(a.totalPts));

    // --- A. 基本フォーメーション (Fixed 1-2-5) ---
    // どんなレースでも固定で計算
    List<int> basicR1 = winRanking.take(1).map((e) => e.pop).toList(); // 1頭
    List<int> basicR2 = totalRanking.take(2).map((e) => e.pop).toList(); // 2頭
    List<int> basicR3 = totalRanking.take(5).map((e) => e.pop).toList(); // 5頭

    // 足切り適用 (基本形でもオッズ足切りは適用する)
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

    int topWinPts = winRanking.isNotEmpty ? winRanking[0].winPts : 0;
    int secondWinPts = winRanking.length > 1 ? winRanking[1].winPts : 0;

    // 戦略判定
    if (topWinPts >= 50) {
      // 1頭軸流し
      strategyName = "1頭軸流し (鉄板)";
      strategyReason = "${winRanking[0].pop}番人気が圧倒的(勝率50%以上)です。ここを頭に固定し、相手を絞ります。";
      stratR1 = [winRanking[0].pop];
      stratR2 = totalRanking.take(4).map((e) => e.pop).toList(); // 相手4頭
      stratR3 = totalRanking.take(7).map((e) => e.pop).toList(); // 紐7頭

    } else if ((topWinPts + secondWinPts) >= 70) {
      // 2頭軸/フォーメーション
      strategyName = "2頭軸フォーメーション (一騎打ち)";
      strategyReason = "上位2頭で勝利の大半を占めています。この2頭を1列目に据えます。";
      stratR1 = [winRanking[0].pop, winRanking[1].pop];
      stratR2 = [winRanking[0].pop, winRanking[1].pop, ...totalRanking.take(2).map((e) => e.pop)];
      stratR2 = stratR2.toSet().toList();
      stratR3 = totalRanking.take(6).map((e) => e.pop).toList();

    } else {
      // 混戦 -> BOX推奨だが、点数制御を行う
      // 有力馬(TotalPts上位)を抽出
      List<int> boxCandidates = totalRanking.take(6).map((e) => e.pop).toList();

      // 足切り適用後の頭数で判定
      boxCandidates = boxCandidates.where((p) => validHorseMap.containsKey(p)).toList();

      if (boxCandidates.length >= 6) {
        // 6頭以上なら3連複BOX (20点) に切り替え
        strategyName = "3連複BOX (大混戦)";
        strategyReason = "上位が拮抗しすぎています。3連単は点数が増えるため、3連複BOX(20点)を推奨します。";
        betType = "3連複";
        stratR1 = boxCandidates; // BOXの場合は全て同じリストを入れる
        stratR2 = boxCandidates;
        stratR3 = boxCandidates;
      } else if (boxCandidates.length == 5) {
        // 5頭なら3連単BOX (60点) 許容範囲
        strategyName = "5頭BOX (混戦)";
        strategyReason = "有力5頭のBOX(60点)で網を張ります。";
        stratR1 = boxCandidates;
        stratR2 = boxCandidates;
        stratR3 = boxCandidates;
      } else {
        // 4頭以下なら3連単BOX (24点以下)
        strategyName = "${boxCandidates.length}頭BOX (少数精鋭)";
        strategyReason = "混戦ですが、有効オッズ馬は${boxCandidates.length}頭に絞られます。";
        stratR1 = boxCandidates;
        stratR2 = boxCandidates;
        stratR3 = boxCandidates;
      }
    }

    // AI戦略の足切り適用 (念のため再確認)
    stratR1 = stratR1.where((p) => validHorseMap.containsKey(p)).toList();
    stratR2 = stratR2.where((p) => validHorseMap.containsKey(p)).toList();
    stratR3 = stratR3.where((p) => validHorseMap.containsKey(p)).toList();

    // 5. 買い目の生成 (AI戦略に基づくチケットのみ生成)
    final List<FormationTicket> tickets = [];
    int estimatedPts = 0;

    if (betType == "3連単") {
      for (int first in stratR1) {
        for (int second in stratR2) {
          if (first == second) continue;
          for (int third in stratR3) {
            if (first == third || second == third) continue;

            // BOX戦略の場合、stratR1~R3は同じリストなので全通り生成される
            // フォーメーションの場合、指定通り生成される

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
      // 3連複の生成 (重複なし組み合わせ)
      // stratR1がBOX対象リストになっている
      List<int> boxList = stratR1;
      int n = boxList.length;
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          for (int k = j + 1; k < n; k++) {
            int p1 = boxList[i];
            int p2 = boxList[j];
            int p3 = boxList[k];

            int w = (matrix[p1-1][0] + matrix[p1-1][1] + matrix[p1-1][2]) +
                (matrix[p2-1][0] + matrix[p2-1][1] + matrix[p2-1][2]) +
                (matrix[p3-1][0] + matrix[p3-1][1] + matrix[p3-1][2]);

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

    tickets.sort((a, b) => b.weight.compareTo(a.weight));

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
    );
  }
}

class _PopStats {
  final int pop;
  final int winCount;
  final int totalCount;
  final int winPts;
  final int totalPts;
  _PopStats({required this.pop, required this.winCount, required this.totalCount, required this.winPts, required this.totalPts});
}