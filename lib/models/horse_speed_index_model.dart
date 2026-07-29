// lib/models/horse_speed_index_model.dart

/// スピード指数を保持するモデル。
/// 過去成績から算出され、horse_speed_index テーブルに永続化される。
class HorseSpeedIndex {
  final String horseId;
  final double bestIndex;       // 自己ベストのスピード指数
  final double recentAvgIndex;  // 直近レースの平均スピード指数
  final double trend;           // 指数の推移傾向 (正=上昇, 負=下降)
  final double confidence;      // 指数の信頼度 (0.0〜1.0)
  final int sampleCount;        // 算出に使用したレース数
  final String calculatedAt;    // 計算日時 (ISO8601)

  HorseSpeedIndex({
    required this.horseId,
    required this.bestIndex,
    required this.recentAvgIndex,
    required this.trend,
    required this.confidence,
    required this.sampleCount,
    required this.calculatedAt,
  });

  factory HorseSpeedIndex.fromMap(Map<String, dynamic> map) {
    return HorseSpeedIndex(
      horseId: map['horse_id'] as String,
      bestIndex: (map['best_index'] as num).toDouble(),
      recentAvgIndex: (map['recent_avg_index'] as num).toDouble(),
      trend: (map['trend'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      sampleCount: map['sample_count'] as int,
      calculatedAt: map['calculated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horse_id': horseId,
      'best_index': bestIndex,
      'recent_avg_index': recentAvgIndex,
      'trend': trend,
      'confidence': confidence,
      'sample_count': sampleCount,
      'calculated_at': calculatedAt,
    };
  }
}
