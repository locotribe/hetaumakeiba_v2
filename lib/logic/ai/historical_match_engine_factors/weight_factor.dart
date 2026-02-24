// lib/logic/ai/historical_match_engine_factors/weight_factor.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class WeightFactorResult {
  final double score;
  final double? usedWeight;
  final double diff;
  final bool isCurrent;
  final String displayStr;

  WeightFactorResult({
    required this.score,
    this.usedWeight,
    required this.diff,
    required this.isCurrent,
    required this.displayStr,
  });
}

class WeightFactor {
  WeightFactorResult analyze(PredictionHorseDetail horse, HorseRaceRecord? prevRecord, double medianWeight) {
    double? weight;
    bool isCurrent = false;
    String displayStr = '--';

    final currentWeightVal = parseWeight(horse.horseWeight);
    if (currentWeightVal != null) {
      weight = currentWeightVal;
      isCurrent = true;
      displayStr = horse.horseWeight ?? '--';
    } else if (prevRecord != null) {
      final prevWeightVal = parseWeight(prevRecord.horseWeight);
      if (prevWeightVal != null) {
        weight = prevWeightVal;
        isCurrent = false;
        displayStr = "${prevRecord.horseWeight} (前走)";
      }
    }

    double weightScore = 0.0;
    double diff = 0.0;
    if (weight != null && medianWeight > 0) {
      diff = (weight - medianWeight).abs();
      weightScore = 100.0 - (diff * 2.0);
      if (weightScore < 0) weightScore = 0;
    }

    return WeightFactorResult(
      score: weightScore,
      usedWeight: weight,
      diff: diff,
      isCurrent: isCurrent,
      displayStr: displayStr,
    );
  }

  static double? parseWeight(String? s) {
    if (s == null || s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
    try {
      return double.tryParse(s.split('(')[0].replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return null;
    }
  }
}