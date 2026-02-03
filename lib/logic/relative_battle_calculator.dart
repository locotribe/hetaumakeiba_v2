// lib/logic/relative_battle_calculator.dart

import 'dart:math';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import '../models/relative_evaluation_model.dart';

/// 相対評価シミュレーションを実行する計算クラス
class RelativeBattleCalculator {
  final Random _random = Random();

  /// メインメソッド: シミュレーションを実行して結果リストを返す
  List<RelativeEvaluationResult> runSimulation(
      List<PredictionHorseDetail> horses, {
        int iterations = 100, // 試行回数
      }) {
    // 馬が1頭以下の場合はシミュレーション不可
    if (horses.length < 2) return [];

    // 1. 各馬の静的な基礎データを準備
    final List<_HorseStaticData> staticDataList = horses.map((h) => _prepareStaticData(h)).toList();

    // 2. モンテカルロ・シミュレーション
    final winCounts = {for (var h in horses) h.horseId: 0};
    // 要因分析用のスコア累積
    final scoreAccumulator = {
      for (var h in horses)
        h.horseId: {'base': 0.0, 'style': 0.0, 'pace': 0.0, 'aptitude': 0.0}
    };

    for (int i = 0; i < iterations; i++) {
      _runSingleIteration(staticDataList, winCounts, scoreAccumulator);
    }

    // 3. 結果の集計
    List<RelativeEvaluationResult> results = [];

    // 勝利数順にソート
    var sortedEntries = winCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ★修正: 1回のシミュレーションでの最大勝利数（自分以外の全馬と対戦するため）
    final int maxWinsPerIteration = horses.length - 1;
    // ★修正: 分母は「試行回数 × 1回あたりの最大勝利数」
    final int totalMatchups = iterations * maxWinsPerIteration;

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final horseId = entry.key;
      final winCount = entry.value;
      final staticData = staticDataList.firstWhere((d) => d.horseId == horseId);

      // ★修正: 勝率計算の正規化 (0除算防止)
      final winRate = totalMatchups > 0 ? winCount / totalMatchups : 0.0;

      // 平均スコアの算出（表示用）
      final acc = scoreAccumulator[horseId]!;
      final factorScores = {
        'base': acc['base']! / iterations,
        'style': acc['style']! / iterations, // 脚質適性・質
        'pace': acc['pace']! / iterations,   // 展開利
        'aptitude': acc['aptitude']! / iterations, // コース・距離適性
        'value': staticData.expectedValue, // ★修正: 正しい期待値をセット
      };

      // 短評と逆転スコアの生成
      final analysis = _analyzeFactors(factorScores, winRate, i + 1);

      results.add(RelativeEvaluationResult(
        horseId: horseId,
        horseName: staticData.horseName,
        popularity: staticData.popularity, // ★追加: 人気情報をセット
        winRate: winRate,
        rank: i + 1,
        reversalScore: analysis.reversalScore,
        confidence: _calculateConfidence(winRate, iterations),
        evaluationComment: analysis.comment,
        factorScores: factorScores,
      ));
    }
    return results;
  }

  /// 静的データの準備（ループ外で計算できるもの）
  _HorseStaticData _prepareStaticData(PredictionHorseDetail horse) {
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

    // ★修正: 期待値（妙味）の動的計算
    double expectedValue = 0.0;

    // 最新のオッズを取得 (effectiveOdds優先、なければodds)
    double? currentOdds;
    if (horse.effectiveOdds != null) {
      currentOdds = double.tryParse(horse.effectiveOdds!);
    } else {
      currentOdds = horse.odds;
    }

    // オッズがあり、かつ基礎能力がある場合、その場で簡易的に期待値を再計算
    if (currentOdds != null && currentOdds > 0) {
      // 簡易期待値 = 推定勝率係数 * オッズ
      // baseAbilityが50の場合、係数0.5。オッズが2.0倍なら 0.5 * 2.0 = 1.0 (標準)
      double estimatedWinRate = (baseAbility / 100.0);
      expectedValue = estimatedWinRate * currentOdds;
    }
    // 上記で計算できず、DBに保存された値があればそれを使う
    else if (horse.expectedValue != null) {
      expectedValue = horse.expectedValue!;
    }

    return _HorseStaticData(
      horseId: horse.horseId,
      horseName: horse.horseName,
      popularity: horse.popularity, // ★追加
      baseAbility: baseAbility,
      aptitudeScore: aptitudeScore,
      expectedValue: expectedValue, // ★追加
      legStyleProfile: horse.legStyleProfile,
    );
  }

  /// 1回分のシミュレーション（動的展開生成）
  void _runSingleIteration(
      List<_HorseStaticData> staticDataList,
      Map<String, int> winCounts,
      Map<String, Map<String, double>> scoreAccumulator,
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

    // B. ペース判定
    _PaceType pace = _PaceType.middle;
    if (nigeCount <= 1) pace = _PaceType.slow;
    else if (nigeCount >= 3) pace = _PaceType.high;

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

      // C-2. 展開補正
      double paceBonus = 0.0;
      if (pace == _PaceType.slow) {
        if (style == '逃げ') paceBonus += 15.0;
        else if (style == '先行') paceBonus += 5.0;
        else if (style == '追い込み') paceBonus -= 5.0;
      } else if (pace == _PaceType.high) {
        if (style == '逃げ') paceBonus -= 10.0;
        else if (style == '差し') paceBonus += 5.0;
        else if (style == '追い込み') paceBonus += 10.0;
      }
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

  /// 結果分析
  _AnalysisResult _analyzeFactors(Map<String, double> scores, double winRate, int rank) {
    String comment = "";
    // ★修正: 逆転スコアに「妙味」も含める
    double reversal = scores['pace']! + scores['style']! + (scores['value'] ?? 0.0);

    // ★修正: 勝率の基準を正規化後の値に合わせて調整
    if (winRate > 0.8) {
      comment = "盤石";
    } else if ((scores['value'] ?? 0.0) > 1.2) { // 期待値が1.2(120%)を超えたら
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
  final int? popularity; // ★追加
  final double baseAbility;
  final double aptitudeScore;
  final double expectedValue; // ★追加: 期待値
  final LegStyleProfile? legStyleProfile;

  _HorseStaticData({
    required this.horseId,
    required this.horseName,
    this.popularity, // ★追加
    required this.baseAbility,
    required this.aptitudeScore,
    required this.expectedValue, // ★追加
    this.legStyleProfile,
  });
}

class _AnalysisResult {
  final String comment;
  final double reversalScore;
  _AnalysisResult(this.comment, this.reversalScore);
}

enum _PaceType { slow, middle, high }