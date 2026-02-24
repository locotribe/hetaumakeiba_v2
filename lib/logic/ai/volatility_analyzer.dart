// lib/logic/ai/volatility_analyzer.dart

import 'package:hetaumakeiba_v2/models/race_result_model.dart';

class VolatilityResult {
  final double averagePopularity;
  final String diagnosis;
  final String description;

  VolatilityResult({
    required this.averagePopularity,
    required this.diagnosis,
    required this.description,
  });
}

class VolatilityAnalyzer {
  VolatilityResult analyze(List<RaceResult> pastRaces) {
    if (pastRaces.isEmpty) {
      return VolatilityResult(averagePopularity: 3.5, diagnosis: 'データ不足', description: '過去のレースデータがありません。');
    }

    double totalTopPop = 0.0;
    int topPopCount = 0;

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        int pop = int.tryParse(h.popularity ?? '') ?? 0;
        if (rank >= 1 && rank <= 3 && pop > 0) {
          totalTopPop += pop;
          topPopCount++;
        }
      }
    }

    double avgPop = topPopCount > 0 ? totalTopPop / topPopCount : 3.5;

    String diag = '標準';
    String desc = '人気馬と穴馬がバランスよく好走しています。';
    if (avgPop >= 4.5) {
      diag = '大波乱';
      desc = '過去の上位馬の平均人気が${avgPop.toStringAsFixed(1)}と高く、下位人気の激走が頻発する荒れやすいレースです。';
    } else if (avgPop <= 3.0) {
      diag = '堅実';
      desc = '過去の上位馬の平均人気が${avgPop.toStringAsFixed(1)}と低く、上位人気馬が順当に力を発揮しやすいレースです。';
    } else {
      desc = '過去の上位馬の平均人気は${avgPop.toStringAsFixed(1)}です。極端な波乱は少なく、中穴までの好走が目立ちます。';
    }

    return VolatilityResult(
      averagePopularity: avgPop,
      diagnosis: diag,
      description: desc,
    );
  }
}