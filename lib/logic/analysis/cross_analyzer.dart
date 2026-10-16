import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
// [追加] 総合シンクロ率と血統クロス Step4: 取消・除外の判定（過去分析のローテ・血統の表と同じ） (v.2026.10.16+26101617)
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';

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

// [修正] 総合シンクロ率と血統クロス Step4: 1〜3着の馬の回数ではなく、過去の全出走馬（取消・除外を除く）を父ごとに数えた着度数にする。
// 全体傾向（父・母父の一覧）は血統タブの父・母父の表と重なるので出さない。クッション値・含水率の区切りは今までどおり (v.2026.10.16+26101617)
class PedigreeCrossAnalyzer {
  CrossAnalysisResult analyze({
    required List<RaceResult> pastRaces,
    required Map<String, TrackConditionRecord> trackConditionMap,
    required Map<String, HorseProfile> horseProfileMap,
  }) {
    final Map<String, _SireCounter> highCushionMap = {};
    final Map<String, _SireCounter> standardCushionMap = {};
    final Map<String, _SireCounter> lowCushionMap = {};

    final Map<String, _SireCounter> highMoistureMap = {};
    final Map<String, _SireCounter> lowMoistureMap = {};

    int countedStarts = 0;
    int missingStarts = 0;
    int racesWithoutCushion = 0;
    int racesWithoutMoisture = 0;

    for (final r in pastRaces) {
      final tc = trackConditionMap[r.raceId];
      final cushion = tc?.cushionValue;

      double moisture = 0.0;
      if (r.raceInfo.contains('芝') && tc?.moistureTurfGoal != null) {
        moisture = tc!.moistureTurfGoal!;
      } else if (r.raceInfo.contains('ダ') && tc?.moistureDirtGoal != null) {
        moisture = tc!.moistureDirtGoal!;
      }

      if (cushion == null) racesWithoutCushion++;
      if (moisture <= 0) racesWithoutMoisture++;

      for (final h in r.horseResults) {
        if (h.horseId.isEmpty) continue;
        if (isNonStarterRank(h.rank)) continue;
        final sire = horseProfileMap[h.horseId]?.fatherName.trim() ?? '';
        if (sire.isEmpty) {
          missingStarts++;
          continue;
        }
        countedStarts++;
        final rank = int.tryParse(h.rank.trim());

        if (cushion != null) {
          if (cushion >= 9.5) {
            _add(highCushionMap, sire, rank);
          } else if (cushion < 8.5) {
            _add(lowCushionMap, sire, rank);
          } else {
            _add(standardCushionMap, sire, rank);
          }
        }

        if (moisture > 0) {
          if (moisture >= 10.0) {
            _add(highMoistureMap, sire, rank);
          } else {
            _add(lowMoistureMap, sire, rank);
          }
        }
      }
    }

    return CrossAnalysisResult(
      highCushionSires: _sorted(highCushionMap),
      standardCushionSires: _sorted(standardCushionMap),
      lowCushionSires: _sorted(lowCushionMap),
      highMoistureSires: _sorted(highMoistureMap),
      lowMoistureSires: _sorted(lowMoistureMap),
      countedStarts: countedStarts,
      missingStarts: missingStarts,
      racesWithoutCushion: racesWithoutCushion,
      racesWithoutMoisture: racesWithoutMoisture,
    );
  }

  /// 父 [sire] の出走を1つ数える。[rank] は着順の数字（中止・失格など数字でないものは null で、着外として数える）。
  void _add(Map<String, _SireCounter> map, String sire, int? rank) {
    final counter = map.putIfAbsent(sire, () => _SireCounter());
    counter.total++;
    if (rank != null && rank >= 1 && rank <= 3) {
      counter.show++;
      if (rank <= 2) counter.place++;
      if (rank == 1) counter.win++;
    }
  }

  /// 3着以内の多い順 → 出走の多い順 → 1着の多い順 → 名前の順。
  List<PedigreeRecordCount> _sorted(Map<String, _SireCounter> map) {
    final list = [
      for (final entry in map.entries)
        PedigreeRecordCount(
          name: entry.key,
          total: entry.value.total,
          win: entry.value.win,
          place: entry.value.place,
          show: entry.value.show,
        ),
    ];
    list.sort((a, b) {
      final byShow = b.show.compareTo(a.show);
      if (byShow != 0) return byShow;
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      final byWin = b.win.compareTo(a.win);
      if (byWin != 0) return byWin;
      return a.name.compareTo(b.name);
    });
    return list;
  }
}

class _SireCounter {
  int total = 0;
  int win = 0;
  int place = 0;
  int show = 0;
}
