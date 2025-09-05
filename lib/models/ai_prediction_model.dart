// lib/models/ai_prediction_model.dart

class AiPrediction {
  final int? id;
  final String raceId;
  final String horseId;
  final double overallScore;
  final double expectedValue;
  final DateTime predictionTimestamp;

  AiPrediction({
    this.id,
    required this.raceId,
    required this.horseId,
    required this.overallScore,
    required this.expectedValue,
    required this.predictionTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'race_id': raceId,
      'horse_id': horseId,
      'overall_score': overallScore,
      'expected_value': expectedValue,
      'prediction_timestamp': predictionTimestamp.toIso8601String(),
    };
  }

  factory AiPrediction.fromMap(Map<String, dynamic> map) {
    return AiPrediction(
      id: map['id'] as int?,
      raceId: map['race_id'] as String,
      horseId: map['horse_id'] as String,
      overallScore: map['overall_score'] as double,
      expectedValue: map['expected_value'] as double,
      predictionTimestamp: DateTime.parse(map['prediction_timestamp'] as String),
    );
  }
}