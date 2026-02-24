// lib/logic/ai/historical_match_engine_factors/rotation_factor.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

class RotationFactorResult {
  final double score;
  final String diag;
  final String prevRaceName;

  RotationFactorResult({
    required this.score,
    required this.diag,
    required this.prevRaceName,
  });
}

class RotationFactor {
  RotationFactorResult analyze(HorseRaceRecord? prevRecord, List<String> favorableRotations) {
    double rotScore = 40.0;
    String rotDiag = '';
    String prevRaceName = prevRecord?.raceName ?? '-';

    if (prevRaceName != '-') {
      bool isFavorable = favorableRotations.any((r) => prevRaceName.contains(r));
      bool isHighGrade = prevRaceName.contains('G1') || prevRaceName.contains('GI') ||
          prevRaceName.contains('G2') || prevRaceName.contains('GII');
      if (isFavorable) {
        rotScore = 95.0;
        rotDiag = '王道';
      } else if (isHighGrade) {
        rotScore = 80.0;
        rotDiag = '格上';
      } else {
        rotScore = 50.0;
        rotDiag = '標準';
      }
    }

    return RotationFactorResult(
      score: rotScore,
      diag: rotDiag,
      prevRaceName: prevRaceName,
    );
  }
}