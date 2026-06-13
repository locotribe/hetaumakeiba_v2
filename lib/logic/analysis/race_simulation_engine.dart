// lib/logic/analysis/race_simulation_engine.dart
// [追加] 展開予想アニメーション機能(MVP)のシミュレーションエンジン (v.1.0)

import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';

class RaceSimulationEngine {
  /// アニメーション全体の長さ(秒)
  static const double totalAnimationSeconds = 12.0;

  /// レーン1つあたりの横方向オフセット(px)。coords.pixelsPerMeter≈0.5
  /// (1px≈2m)であるため、0.5px≈1m間隔とする(18頭が重なりながら密集する想定)。
  static const double laneSpacingPx = 0.5;

  /// 隊列の「-」区切りグループ1つあたりの縦方向(ゴールからの絶対残距離)
  /// オフセット(m)。グループ番号が大きい(後方)ほどdistanceFromGoalが増える。
  static const double groupSpacingMeters = 4.0;

  /// 内ラチへのめり込み防止のため、全馬の横方向オフセットに加算する
  /// 固定マージン(px)。coords.pixelsPerMeter≈0.5(1px≈2m)であるため、
  /// 4.75px≈9.5m相当。最内枠(laneRank=-8.5)が内ラチ境界(lateralOffset=0)より
  /// 約+1m走路側に来るよう設定。
  static const double innerMarginPx = 4.75;

  /// 出走取消済み除外後の各馬について、発走(d0)〜ゴール(d4)の5キーフレーム分の
  /// Snapshot配列(time, distanceFromGoal, laneRank)を構築する。
  static Future<RaceSimulationData?> build({
    required PredictionRaceData raceData,
    required List<PredictionHorseDetail> horses,
    required Map<String, List<HorseRaceRecord>> allPastRecords,
    required RaceCourseData? raceCourse,
    required double raceDistance,
  }) async {
    if (horses.isEmpty || raceDistance <= 0) return null;

    final development = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      const ['1-2コーナー', '3コーナー', '4コーナー'],
      const {},
    );

    // 「ゴールからの絶対残距離」(d0=raceDistance, d4=0, 単調減少)
    final d0 = raceDistance;
    final d1 = _clampD(
      _cornerMid(raceCourse, const ['corner_1', 'corner_2'],
          fallback: raceDistance * 0.75),
      0.0,
      d0,
    );
    final d2 = _clampD(
      _cornerMid(raceCourse, const ['corner_3'], fallback: raceDistance * 0.5),
      0.0,
      d1,
    );
    final d3 = _clampD(
      _cornerMid(raceCourse, const ['corner_4'], fallback: raceDistance * 0.25),
      0.0,
      d2,
    );
    const d4 = 0.0;

    final distances = <double>[d0, d1, d2, d3, d4];
    final times = distances
        .map((d) => ((raceDistance - d) / raceDistance) * totalAnimationSeconds)
        .toList();

    // 各キーフレームでの隊列グループ（「-」区切りの前後グループ × 内側からの並び順）
    final orderedByGate = List<PredictionHorseDetail>.from(horses)
      ..sort((a, b) => a.gateNumber.compareTo(b.gateNumber));
    // 発走時は枠順一列を1グループとして扱う（横一列のスタートゲート表現）
    final order0Groups = [
      orderedByGate.map((h) => h.horseNumber.toString()).toList()
    ];
    final order1Groups = _parseTairetsuGroups(development['1-2コーナー']);
    final order2Groups = _parseTairetsuGroups(development['3コーナー']);
    final order3Groups = _parseTairetsuGroups(development['4コーナー']);
    final order4Groups = order3Groups;

    final orderGroups = <List<List<String>>>[
      order0Groups,
      order1Groups,
      order2Groups,
      order3Groups,
      order4Groups,
    ];

    final horseTracks = <RaceSimHorseTrack>[];
    for (final horse in horses) {
      final horseNumber = horse.horseNumber.toString();
      final snapshots = <RaceSimSnapshot>[];
      for (int i = 0; i < 5; i++) {
        final groups = orderGroups[i];

        int groupIndex = -1;
        int idxInGroup = -1;
        int groupSize = 1;
        for (int g = 0; g < groups.length; g++) {
          final idx = groups[g].indexOf(horseNumber);
          if (idx >= 0) {
            groupIndex = g;
            idxInGroup = idx;
            groupSize = groups[g].length;
            break;
          }
        }

        final laneRank = groupIndex >= 0
            ? idxInGroup - (groupSize - 1) / 2.0
            : 0.0;
        final distanceFromGoal = groupIndex >= 0
            ? distances[i] + groupIndex * groupSpacingMeters
            : distances[i];

        snapshots.add(RaceSimSnapshot(
          time: times[i],
          distanceFromGoal: distanceFromGoal,
          laneRank: laneRank,
        ));
      }
      horseTracks.add(RaceSimHorseTrack(
        horseNumber: horseNumber,
        gateNumber: horse.gateNumber,
        snapshots: snapshots,
      ));
    }

    return RaceSimulationData(
      horseTracks: horseTracks,
      developmentTexts: development,
      totalTime: totalAnimationSeconds,
    );
  }

  static double _clampD(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  /// raceCourse.sections（distanceFromStart基準）からsectionNamesに該当する
  /// 最後（=ゴールに最も近い）の連続グループを探し、その中間値を
  /// 「ゴールからの絶対残距離」に変換して返す。該当が無い場合はfallbackを返す。
  static double _cornerMid(
    RaceCourseData? raceCourse,
    List<String> sectionNames, {
    required double fallback,
  }) {
    if (raceCourse == null) return fallback;
    final sections = raceCourse.sections;

    final matches = <int>[];
    for (int i = 0; i < sections.length; i++) {
      if (sectionNames.contains(sections[i].name)) matches.add(i);
    }
    if (matches.isEmpty) return fallback;

    // 複数周回コースで同名セクションが複数存在する場合は、
    // ゴールに最も近い（最後の）連続グループのみを採用する
    final lastGroup = <int>[matches.last];
    for (int i = matches.length - 2; i >= 0; i--) {
      if (matches[i] == lastGroup.first - 1) {
        lastGroup.insert(0, matches[i]);
      } else {
        break;
      }
    }

    double minStart = sections[lastGroup.first].startDistance;
    double maxEnd = sections[lastGroup.first].endDistance;
    for (final idx in lastGroup) {
      if (sections[idx].startDistance < minStart) {
        minStart = sections[idx].startDistance;
      }
      if (sections[idx].endDistance > maxEnd) {
        maxEnd = sections[idx].endDistance;
      }
    }
    final midFromStart = (minStart + maxEnd) / 2.0;
    return raceCourse.raceDistance - midFromStart;
  }

  /// "(3,5)-7-12" 形式の隊列文字列を [['3','5'], ['7'], ['12']] に変換する。
  /// 「-」区切りの各トークンが1グループ（前後関係）、トークン内の「()」が
  /// 並走する馬（横方向のみの関係）を表す。
  static List<List<String>> _parseTairetsuGroups(String? tairetsu) {
    if (tairetsu == null || tairetsu.isEmpty) return [];
    return tairetsu
        .split('-')
        .map((token) => token
            .replaceAll(RegExp(r'[()]'), '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList())
        .where((group) => group.isNotEmpty)
        .toList();
  }
}
