// lib/models/prediction_analysis_model.dart
class HorsePredictionScore {
  final double distanceScore;
  final double courseScore;
  final double jockeyCompatibilityScore;

  HorsePredictionScore({
    this.distanceScore = 0.0,
    this.courseScore = 0.0,
    this.jockeyCompatibilityScore = 0.0,
  });
}

class RacePacePrediction {
  final String predictedPace; // 例: "ハイペース", "スローペース"
  final String advantageousStyle; // 例: "差し・追込有利", "逃げ・先行有利"

  RacePacePrediction({
    this.predictedPace = "不明",
    this.advantageousStyle = "不明",
  });
}