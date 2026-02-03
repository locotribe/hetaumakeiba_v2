// lib/models/relative_evaluation_model.dart

/// レースのペース定義
enum RacePace {
  slow,
  middle,
  high
}

/// 相対評価シミュレーションの結果を保持するモデル
class RelativeEvaluationResult {
  /// 評価対象の馬ID
  final String horseId;

  /// 馬名
  final String horseName;

  /// 現在の人気
  final int? popularity;

  /// シミュレーション勝率 (0.0 - 1.0)
  final double winRate;

  /// 相対順位 (1位〜)
  final int rank;

  /// 逆転期待度スコア (正の値ほど格上を倒す可能性が高い)
  final double reversalScore;

  /// 信頼度/安定度 (0.0 - 1.0, 分散の逆数などで算出)
  final double confidence;

  /// 自動生成された評価短評 (例: "距離短縮で有利")
  final String evaluationComment;

  /// 各評価要因の寄与度 (SHAP値に近いもの)
  /// Key: 'base', 'distance', 'course', 'gate', 'pace', 'value'
  final Map<String, double> factorScores;

  /// ★追加: ペース別シミュレーション勝率
  final Map<RacePace, double> scenarioWinRates;

  /// ★追加: ペース別シミュレーション順位
  final Map<RacePace, int> scenarioRanks;

  RelativeEvaluationResult({
    required this.horseId,
    required this.horseName,
    this.popularity,
    required this.winRate,
    required this.rank,
    required this.reversalScore,
    required this.confidence,
    required this.evaluationComment,
    required this.factorScores,
    this.scenarioWinRates = const {}, // ★追加 (デフォルト値あり)
    this.scenarioRanks = const {},    // ★追加 (デフォルト値あり)
  });

  /// デバッグ用文字列
  @override
  String toString() {
    return '$rank位 $horseName (勝率: ${(winRate * 100).toStringAsFixed(1)}%) - $evaluationComment';
  }
}