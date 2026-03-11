import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';

class TrackConditionTrendAnalyzer {
  TrackConditionTrendResult analyze(Map<String, TrackConditionRecord> trackConditionMap) {
    List<double> cushions = [];
    List<double> turfMoistures = [];
    List<double> dirtMoistures = [];

    for (final tc in trackConditionMap.values) {
      if (tc.cushionValue != null) cushions.add(tc.cushionValue!);
      if (tc.moistureTurfGoal != null) turfMoistures.add(tc.moistureTurfGoal!);
      if (tc.moistureDirtGoal != null) dirtMoistures.add(tc.moistureDirtGoal!);
    }

    double avgC = cushions.isNotEmpty ? cushions.reduce((a, b) => a + b) / cushions.length : 0.0;
    double maxC = cushions.isNotEmpty ? cushions.reduce((a, b) => a > b ? a : b) : 0.0;
    double minC = cushions.isNotEmpty ? cushions.reduce((a, b) => a < b ? a : b) : 0.0;

    double avgT = turfMoistures.isNotEmpty ? turfMoistures.reduce((a, b) => a + b) / turfMoistures.length : 0.0;
    double avgD = dirtMoistures.isNotEmpty ? dirtMoistures.reduce((a, b) => a + b) / dirtMoistures.length : 0.0;

    return TrackConditionTrendResult(
      avgCushion: avgC,
      maxCushion: maxC,
      minCushion: minC,
      avgTurfMoisture: avgT,
      avgDirtMoisture: avgD,
    );
  }
}

class PedigreeCrossAnalyzer {
  CrossAnalysisResult analyze({
    required List<RaceResult> pastRaces,
    required Map<String, TrackConditionRecord> trackConditionMap,
    required Map<String, HorseProfile> horseProfileMap,
  }) {
    Map<String, int> overallSireMap = {};
    Map<String, int> overallBmMap = {};

    Map<String, int> highCushionMap = {};
    Map<String, int> standardCushionMap = {};
    Map<String, int> lowCushionMap = {};

    Map<String, int> highMoistureMap = {};
    Map<String, int> lowMoistureMap = {};

    for (final r in pastRaces) {
      final tc = trackConditionMap[r.raceId];
      final cushion = tc?.cushionValue;

      double moisture = 0.0;
      if (r.raceInfo.contains('芝') && tc?.moistureTurfGoal != null) {
        moisture = tc!.moistureTurfGoal!;
      } else if (r.raceInfo.contains('ダ') && tc?.moistureDirtGoal != null) {
        moisture = tc!.moistureDirtGoal!;
      }

      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        if (rank >= 1 && rank <= 3) {
          final profile = horseProfileMap[h.horseId];
          if (profile != null) {
            final sire = profile.fatherName;
            final bm = profile.mfName;

            if (sire.isNotEmpty) {
              overallSireMap[sire] = (overallSireMap[sire] ?? 0) + 1;

              if (cushion != null) {
                if (cushion >= 9.5) {
                  highCushionMap[sire] = (highCushionMap[sire] ?? 0) + 1;
                } else if (cushion < 8.5) {
                  lowCushionMap[sire] = (lowCushionMap[sire] ?? 0) + 1;
                } else {
                  standardCushionMap[sire] = (standardCushionMap[sire] ?? 0) + 1;
                }
              }

              if (moisture > 0) {
                if (moisture >= 10.0) {
                  highMoistureMap[sire] = (highMoistureMap[sire] ?? 0) + 1;
                } else {
                  lowMoistureMap[sire] = (lowMoistureMap[sire] ?? 0) + 1;
                }
              }
            }
            if (bm.isNotEmpty) {
              overallBmMap[bm] = (overallBmMap[bm] ?? 0) + 1;
            }
          }
        }
      }
    }

    List<PedigreeCount> sortMap(Map<String, int> map) {
      final list = map.entries.map((e) => PedigreeCount(e.key, e.value)).toList();
      list.sort((a, b) => b.count.compareTo(a.count));
      return list;
    }

    return CrossAnalysisResult(
      overallSires: sortMap(overallSireMap),
      overallBms: sortMap(overallBmMap),
      highCushionSires: sortMap(highCushionMap),
      standardCushionSires: sortMap(standardCushionMap),
      lowCushionSires: sortMap(lowCushionMap),
      highMoistureSires: sortMap(highMoistureMap),
      lowMoistureSires: sortMap(lowMoistureMap),
    );
  }
}