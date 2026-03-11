import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';

class TrackConditionFactorResult {
  final Map<String, double> scenarioScores; // 'high', 'standard', 'low'

  TrackConditionFactorResult({required this.scenarioScores});
}

class TrackConditionFactor {
  TrackConditionFactorResult analyze({
    required HorseProfile? profile,
    required CrossAnalysisResult crossResult,
  }) {
    double highScore = 40.0;
    double standardScore = 40.0;
    double lowScore = 40.0;

    if (profile != null && profile.fatherName.isNotEmpty) {
      final sire = profile.fatherName;

      // 硬い馬場 (High) での血統実績
      if (crossResult.highCushionSires.any((e) => e.name == sire && e.count > 0)) {
        highScore += 40.0;
      }

      // 標準馬場 (Standard) での血統実績
      if (crossResult.standardCushionSires.any((e) => e.name == sire && e.count > 0)) {
        standardScore += 40.0;
      }

      // 軟らかい馬場 (Low) または 水分多めの馬場での血統実績
      bool isSoft = crossResult.lowCushionSires.any((e) => e.name == sire && e.count > 0) ||
          crossResult.highMoistureSires.any((e) => e.name == sire && e.count > 0);
      if (isSoft) {
        lowScore += 40.0;
      }
    }

    return TrackConditionFactorResult(
        scenarioScores: {
          'high': highScore.clamp(0.0, 100.0),
          'standard': standardScore.clamp(0.0, 100.0),
          'low': lowScore.clamp(0.0, 100.0),
        }
    );
  }
}