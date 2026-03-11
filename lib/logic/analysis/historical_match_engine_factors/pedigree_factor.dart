import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';

class PedigreeFactorResult {
  final double score;
  final String diag;

  PedigreeFactorResult({required this.score, required this.diag});
}

class PedigreeFactor {
  PedigreeFactorResult analyze({
    required HorseProfile? profile,
    required CrossAnalysisResult crossResult,
  }) {
    if (profile == null || profile.fatherName.isEmpty) {
      return PedigreeFactorResult(score: 50.0, diag: 'データなし');
    }

    double score = 40.0; // 基本点
    String diag = '標準';

    final sire = profile.fatherName;
    final bm = profile.mfName;

    // 父の好走実績を確認
    int sireCount = crossResult.overallSires
        .firstWhere((e) => e.name == sire, orElse: () => PedigreeCount('', 0))
        .count;

    // 母父の好走実績を確認
    int bmCount = crossResult.overallBms
        .firstWhere((e) => e.name == bm, orElse: () => PedigreeCount('', 0))
        .count;

    if (sireCount >= 2) {
      score += 40.0;
      diag = '父特注';
    } else if (sireCount == 1) {
      score += 20.0;
      diag = '父好走あり';
    }

    if (bmCount >= 1) {
      score += 20.0;
      if (diag == '標準') diag = '母父実績あり';
      else diag += '・母父も';
    }

    return PedigreeFactorResult(score: score.clamp(0.0, 100.0), diag: diag);
  }
}