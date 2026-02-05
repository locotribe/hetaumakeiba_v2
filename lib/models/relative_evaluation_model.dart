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

  /// 単勝オッズ
  final double odds;

  /// シミュレーション勝率 (0.0 - 1.0)
  final double winRate;

  /// 相対順位 (1位〜)
  final int rank;

  /// 逆転期待度スコア
  final double reversalScore;

  /// 信頼度/安定度
  final double confidence;

  /// 自動生成された評価短評
  final String evaluationComment;

  /// 各評価要因の寄与度 (base, style, pace, aptitude, jockey, compatibility, gate, value)
  final Map<String, double> factorScores;

  /// 騎手評価の詳細データ
  final Map<String, dynamic>? jockeyDetails;

  /// 相性（コンビ）評価の詳細データ
  final Map<String, dynamic>? compatibilityDetails;

  /// ★追加: 枠順評価の詳細データ（ダイアログ表示用）
  final Map<String, dynamic>? gateDetails;

  /// ペース別シミュレーション勝率
  final Map<RacePace, double> scenarioWinRates;

  /// ペース別シミュレーション順位
  final Map<RacePace, int> scenarioRanks;

  RelativeEvaluationResult({
    required this.horseId,
    required this.horseName,
    this.popularity,
    required this.odds,
    required this.winRate,
    required this.rank,
    required this.reversalScore,
    required this.confidence,
    required this.evaluationComment,
    required this.factorScores,
    this.jockeyDetails,
    this.compatibilityDetails,
    this.gateDetails, // ★追加
    this.scenarioWinRates = const {},
    this.scenarioRanks = const {},
  });

  @override
  String toString() {
    return '$rank位 $horseName (勝率: ${(winRate * 100).toStringAsFixed(1)}%)';
  }
}