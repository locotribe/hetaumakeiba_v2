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
  final Map<String, double> paceProbabilities;

  RacePacePrediction({
    this.paceProbabilities = const {},
  });

  String get predictedPace {
    if (paceProbabilities.isEmpty) {
      return "ミドルペース";
    }
    final topEntry = paceProbabilities.entries.reduce((a, b) => a.value > b.value ? a : b);
    return topEntry.key;
  }
}

enum FitnessRating { excellent, good, average, poor, unknown }

class ConditionFitResult {
  final FitnessRating trackFit;
  final FitnessRating paceFit;
  final FitnessRating weightFit;
  final FitnessRating gateFit;

  ConditionFitResult({
    this.trackFit = FitnessRating.unknown,
    this.paceFit = FitnessRating.unknown,
    this.weightFit = FitnessRating.unknown,
    this.gateFit = FitnessRating.unknown,
  });
}