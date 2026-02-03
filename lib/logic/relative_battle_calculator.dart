// lib/logic/relative_battle_calculator.dart

import 'dart:math';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import '../models/relative_evaluation_model.dart';

/// 相対評価シミュレーションを実行する計算クラス
class RelativeBattleCalculator {
  final Random _random = Random();

  /// メインメソッド: 総合・各ペースのシミュレーションを一括実行して結果リストを返す
  List<RelativeEvaluationResult> runSimulation(
      List<PredictionHorseDetail> horses, {
        int iterations = 100, // 各シナリオの試行回数
      }) {
    // 馬が1頭以下の場合はシミュレーション不可
    if (horses.length < 2) return [];

    // 1. 各馬の静的な基礎データを準備
    final List<_HorseStaticData> staticDataList = horses.map((h) => _prepareStaticData(h)).toList();

    // 2. 各シナリオを実行
    // A. 総合（ペース動的判定）
    final overallResult = _runScenario(staticDataList, iterations, null);
    // B. スロー固定
    final slowResult = _runScenario(staticDataList, iterations, RacePace.slow);
    // C. ミドル固定
    final middleResult = _runScenario(staticDataList, iterations, RacePace.middle);
    // D. ハイ固定
    final highResult = _runScenario(staticDataList, iterations, RacePace.high);

    // 3. 結果のマージ
    // 総合順位のリストをベースに、各シナリオの結果を詰め込む
    List<RelativeEvaluationResult> results = [];

    for (var baseRes in overallResult) {
      // 各シナリオでの該当馬のデータを探す
      final slowRes = slowResult.firstWhere((r) => r.horseId == baseRes.horseId);
      final middleRes = middleResult.firstWhere((r) => r.horseId == baseRes.horseId);
      final highRes = highResult.firstWhere((r) => r.horseId == baseRes.horseId);

      // ペース別結果マップを作成
      final Map<RacePace, double> scenarioWinRates = {
        RacePace.slow: slowRes.winRate,
        RacePace.middle: middleRes.winRate,
        RacePace.high: highRes.winRate,
      };

      final Map<RacePace, int> scenarioRanks = {
        RacePace.slow: slowRes.rank,
        RacePace.middle: middleRes.rank,
        RacePace.high: highRes.rank,
      };

      // 最終結果オブジェクトを生成（マージ）
      results.add(RelativeEvaluationResult(
        horseId: baseRes.horseId,
        horseName: baseRes.horseName,
        popularity: baseRes.popularity,
        winRate: baseRes.winRate,
        rank: baseRes.rank,
        reversalScore: baseRes.reversalScore,
        confidence: baseRes.confidence,
        evaluationComment: baseRes.evaluationComment,
        factorScores: baseRes.factorScores,
        scenarioWinRates: scenarioWinRates, // ★追加
        scenarioRanks: scenarioRanks,       // ★追加
      ));
    }

    // 念のため総合順位で再ソート
    results.sort((a, b) => a.rank.compareTo(b.rank));

    return results;
  }

  /// 1つのシナリオ（指定ペースまたは動的）を実行する
  List<RelativeEvaluationResult> _runScenario(
      List<_HorseStaticData> staticDataList,
      int iterations,
      RacePace? forcedPace, // nullなら動的判定
      ) {
    final winCounts = {for (var h in staticDataList) h.horseId: 0};
    final scoreAccumulator = {
      for (var h in staticDataList)
        h.horseId: {'base': 0.0, 'style': 0.0, 'pace': 0.0, 'aptitude': 0.0}
    };

    for (int i = 0; i < iterations; i++) {
      _runSingleIteration(staticDataList, winCounts, scoreAccumulator, forcedPace);
    }

    // 結果の集計（既存ロジックと同じ）
    List<RelativeEvaluationResult> results = [];
    var sortedEntries = winCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int maxWinsPerIteration = staticDataList.length - 1;
    final int totalMatchups = iterations * maxWinsPerIteration;

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final horseId = entry.key;
      final winCount = entry.value;
      final staticData = staticDataList.firstWhere((d) => d.horseId == horseId);

      final winRate = totalMatchups > 0 ? winCount / totalMatchups : 0.0;
      final acc = scoreAccumulator[horseId]!;
      final factorScores = {
        'base': acc['base']! / iterations,
        'style': acc['style']! / iterations,
        'pace': acc['pace']! / iterations,
        'aptitude': acc['aptitude']! / iterations,
        'value': staticData.expectedValue,
      };

      final analysis = _analyzeFactors(factorScores, winRate, i + 1);

      results.add(RelativeEvaluationResult(
        horseId: horseId,
        horseName: staticData.horseName,
        popularity: staticData.popularity,
        winRate: winRate,
        rank: i + 1,
        reversalScore: analysis.reversalScore,
        confidence: _calculateConfidence(winRate, iterations),
        evaluationComment: analysis.comment,
        factorScores: factorScores,
        // ここでは空のマップを渡す（マージ元になるため）
        scenarioWinRates: {},
        scenarioRanks: {},
      ));
    }
    return results;
  }

  /// 静的データの準備（変更なし）
  _HorseStaticData _prepareStaticData(PredictionHorseDetail horse) {
    // 既存の実装をそのまま利用
    // 1. 基礎能力 (Base Ability)
    double baseAbility = 50.0;
    if (horse.overallScore != null) {
      baseAbility = horse.overallScore!;
    } else if (horse.effectiveOdds != null) {
      double? odds = double.tryParse(horse.effectiveOdds!);
      if (odds != null) {
        baseAbility = 100.0 - (odds * 2.0).clamp(0, 80);
      }
    } else if (horse.odds != null) {
      baseAbility = 100.0 - (horse.odds! * 2.0).clamp(0, 80);
    }

    // 2. 適性データ (Aptitude)
    double aptitudeScore = 0.0;
    if (horse.distanceCourseAptitudeStats != null) {
      final stats = horse.distanceCourseAptitudeStats!;
      double winRate = 0.0;
      if (stats.raceCount > 0) {
        winRate = stats.winCount / stats.raceCount;
      }
      aptitudeScore += (winRate * 30.0);
    }

    // 期待値（妙味）の動的計算
    double expectedValue = 0.0;
    double? currentOdds;
    if (horse.effectiveOdds != null) {
      currentOdds = double.tryParse(horse.effectiveOdds!);
    } else {
      currentOdds = horse.odds;
    }

    if (currentOdds != null && currentOdds > 0) {
      double estimatedWinRate = (baseAbility / 100.0);
      expectedValue = estimatedWinRate * currentOdds;
    }
    else if (horse.expectedValue != null) {
      expectedValue = horse.expectedValue!;
    }

    return _HorseStaticData(
      horseId: horse.horseId,
      horseName: horse.horseName,
      popularity: horse.popularity,
      baseAbility: baseAbility,
      aptitudeScore: aptitudeScore,
      expectedValue: expectedValue,
      legStyleProfile: horse.legStyleProfile,
    );
  }

  /// 1回分のシミュレーション（動的展開生成 or 強制指定）
  void _runSingleIteration(
      List<_HorseStaticData> staticDataList,
      Map<String, int> winCounts,
      Map<String, Map<String, double>> scoreAccumulator,
      RacePace? forcedPace, // ★追加: 強制ペース
      ) {
    // A. 各馬の「今回の脚質」を決定
    final Map<String, String> currentStyles = {};
    int nigeCount = 0;

    for (var horse in staticDataList) {
      String selectedStyle = '自在';
      if (horse.legStyleProfile != null) {
        double rand = _random.nextDouble();
        double cumulative = 0.0;
        bool determined = false;

        final dist = horse.legStyleProfile!.styleDistribution;
        for (var style in ['逃げ', '先行', '差し', '追い込み']) {
          cumulative += (dist[style] ?? 0.0);
          if (rand <= cumulative) {
            selectedStyle = style;
            determined = true;
            break;
          }
        }
        if (!determined) selectedStyle = horse.legStyleProfile!.primaryStyle;
      }

      currentStyles[horse.horseId] = selectedStyle;
      if (selectedStyle == '逃げ') {
        nigeCount++;
      }
    }

    // B. ペース判定 (強制指定があればそれを使う)
    RacePace pace; // ★修正: _PaceType -> RacePace
    if (forcedPace != null) {
      pace = forcedPace;
    } else {
      // 動的判定
      pace = RacePace.middle;
      if (nigeCount <= 1) pace = RacePace.slow;
      else if (nigeCount >= 3) pace = RacePace.high;
    }

    // C. 各馬の戦闘力算出
    final Map<String, double> currentStrengths = {};

    for (var horse in staticDataList) {
      double score = horse.baseAbility + horse.aptitudeScore;

      // C-1. 脚質「質」補正
      double styleQualityBonus = 0.0;
      final style = currentStyles[horse.horseId]!;
      if (horse.legStyleProfile != null) {
        double winRate = horse.legStyleProfile!.styleWinRates[style] ?? 0.0;
        styleQualityBonus = winRate * 50.0;
      }
      score += styleQualityBonus;

      // C-2. 展開補正 (RacePace enumを使用)
      double paceBonus = 0.0;
      if (pace == RacePace.slow) {
        if (style == '逃げ') paceBonus += 15.0;
        else if (style == '先行') paceBonus += 5.0;
        else if (style == '追い込み') paceBonus -= 5.0;
      } else if (pace == RacePace.high) {
        if (style == '逃げ') paceBonus -= 10.0;
        else if (style == '差し') paceBonus += 5.0;
        else if (style == '追い込み') paceBonus += 10.0;
      }
      // Middleの場合は補正なし（または微調整）

      score += paceBonus;

      // ランダムなゆらぎ
      double noise = (_random.nextDouble() - 0.5) * 10.0;
      score += noise;

      currentStrengths[horse.horseId] = score;

      scoreAccumulator[horse.horseId]!['base'] =
          scoreAccumulator[horse.horseId]!['base']! + horse.baseAbility;
      scoreAccumulator[horse.horseId]!['style'] =
          scoreAccumulator[horse.horseId]!['style']! + styleQualityBonus;
      scoreAccumulator[horse.horseId]!['pace'] =
          scoreAccumulator[horse.horseId]!['pace']! + paceBonus;
      scoreAccumulator[horse.horseId]!['aptitude'] =
          scoreAccumulator[horse.horseId]!['aptitude']! + horse.aptitudeScore;
    }

    // D. 総当たり戦 (Bradley-Terry)
    for (int i = 0; i < staticDataList.length; i++) {
      for (int j = i + 1; j < staticDataList.length; j++) {
        String idA = staticDataList[i].horseId;
        String idB = staticDataList[j].horseId;

        double strA = currentStrengths[idA]!;
        double strB = currentStrengths[idB]!;

        double probA = 1 / (1 + exp(-(strA - strB) / 15.0));

        if (_random.nextDouble() < probA) {
          winCounts[idA] = (winCounts[idA] ?? 0) + 1;
        } else {
          winCounts[idB] = (winCounts[idB] ?? 0) + 1;
        }
      }
    }
  }

  /// 結果分析（変更なし）
  _AnalysisResult _analyzeFactors(Map<String, double> scores, double winRate, int rank) {
    String comment = "";
    double reversal = scores['pace']! + scores['style']! + (scores['value'] ?? 0.0);

    if (winRate > 0.8) {
      comment = "盤石";
    } else if ((scores['value'] ?? 0.0) > 1.2) {
      comment = "妙味十分";
    } else if (scores['pace']! > 5.0) {
      comment = "展開利あり";
    } else if (scores['style']! > 10.0) {
      comment = "適性条件揃う";
    } else if (scores['aptitude']! > 10.0) {
      comment = "コース巧者";
    } else if (scores['pace']! < -5.0) {
      comment = "展開不向き";
    } else {
      comment = "相手なり";
    }

    return _AnalysisResult(comment, reversal);
  }

  double _calculateConfidence(double winRate, int iterations) {
    if (winRate == 0 || winRate == 1) return 1.0;
    return 1.0 - (sqrt(winRate * (1 - winRate) / iterations));
  }
}

/// 静的データ保持用
class _HorseStaticData {
  final String horseId;
  final String horseName;
  final int? popularity;
  final double baseAbility;
  final double aptitudeScore;
  final double expectedValue;
  final LegStyleProfile? legStyleProfile;

  _HorseStaticData({
    required this.horseId,
    required this.horseName,
    this.popularity,
    required this.baseAbility,
    required this.aptitudeScore,
    required this.expectedValue,
    this.legStyleProfile,
  });
}

class _AnalysisResult {
  final String comment;
  final double reversalScore;
  _AnalysisResult(this.comment, this.reversalScore);
}

// _PaceType enumは削除し、lib/models/relative_evaluation_model.dart の RacePace を使用する