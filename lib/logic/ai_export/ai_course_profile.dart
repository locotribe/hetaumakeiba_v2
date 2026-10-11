// lib/logic/ai_export/ai_course_profile.dart

// [追加] AI分析データ 天気・コース追加 Step1: レースのコース（周長・区間・高低差）を、AI分析用データに書ける数値の要約にする純粋ロジック。標高はレース情報タブのグラフと同じ ElevationLogic.generateRaceChartData の値を使い、右回りでグラフ用に左右反転された分はスタート→ゴールの向きに戻す。DB・画面・通信には触れない (v.2026.10.11+26101101)

import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/logic/elevation_logic.dart';

/// コースの区間1つぶんの要約。距離はスタートからのメートル、標高はコースデータ上の相対値（m）。
class AiCourseSectionProfile {
  /// コースデータ上の区間名（'corner_3' など）
  final String rawName;

  /// 出力用の日本語名
  final String label;

  /// 路面（'芝' / 'ダート'）。区間名から分からないときは null
  final String? surface;

  /// 区間の始まり（スタートからのm）
  final double startMeters;

  /// 区間の終わり（スタートからのm）
  final double endMeters;

  /// 区間の始まりの標高（m）
  final double startElevation;

  /// 区間の終わりの標高（m）
  final double endElevation;

  const AiCourseSectionProfile({
    required this.rawName,
    required this.label,
    required this.surface,
    required this.startMeters,
    required this.endMeters,
    required this.startElevation,
    required this.endElevation,
  });

  /// 区間の長さ（m）
  double get lengthMeters => endMeters - startMeters;

  /// 区間内の標高の変化（m）。正は上り、負は下り
  double get elevationChange => endElevation - startElevation;

  /// 平均勾配（%）。長さが0以下なら null
  double? get averageGradePercent =>
      lengthMeters > 0 ? elevationChange / lengthMeters * 100 : null;
}

/// 一定間隔で取った標高の1点。
class AiElevationSample {
  /// スタートからの距離（m）
  final int fromStartMeters;

  /// ゴールまでの残り距離（m）
  final int remainingMeters;

  /// 標高（m）
  final double elevation;

  const AiElevationSample({
    required this.fromStartMeters,
    required this.remainingMeters,
    required this.elevation,
  });
}

/// レース1つぶんのコースの要約。
class AiCourseProfile {
  /// 競馬場コード（'05' など）
  final String venueCode;

  /// コースデータの種別（'shiba' / 'shiba_inner' / 'shiba_outer' / 'shiba_straight' / 'dirt'）
  final String trackType;

  /// レースの距離（m）
  final int raceDistance;

  /// 1周の長さ（m）
  final double lapDistance;

  /// 左回りか（コースデータの判定。新潟の直線も true）
  final bool isLeftHanded;

  /// 直線コースか
  final bool isStraightCourse;

  /// 区間（スタートから順）
  final List<AiCourseSectionProfile> sections;

  /// 一定間隔の標高（スタートから順。最後はゴール地点）
  final List<AiElevationSample> samples;

  /// スタート地点の標高（m）
  final double startElevation;

  /// ゴール地点の標高（m）
  final double goalElevation;

  /// 最高点の標高（m）
  final double maxElevation;

  /// 最高点の位置（スタートからのm。同じ高さが続くときは最初の位置）
  final int maxElevationFromStart;

  /// 最低点の標高（m）
  final double minElevation;

  /// 最低点の位置（スタートからのm。同じ高さが続くときは最初の位置）
  final int minElevationFromStart;

  const AiCourseProfile({
    required this.venueCode,
    required this.trackType,
    required this.raceDistance,
    required this.lapDistance,
    required this.isLeftHanded,
    required this.isStraightCourse,
    required this.sections,
    required this.samples,
    required this.startElevation,
    required this.goalElevation,
    required this.maxElevation,
    required this.maxElevationFromStart,
    required this.minElevation,
    required this.minElevationFromStart,
  });

  /// 最高点と最低点の差（m）
  double get elevationRange => maxElevation - minElevation;

  /// ゴール前直線（最後の区間が finish のときだけ。直線コースなどは null）
  AiCourseSectionProfile? get finalStraight {
    if (sections.isEmpty) return null;
    final last = sections.last;
    return last.rawName.toLowerCase() == 'finish' ? last : null;
  }
}

/// 出馬表の表記から、コースデータの種別キーを決める。
/// レース情報タブ（race_info_tab.dart の _mapToTrackTypeKey）と同じ規則。
String aiTrackTypeKeyOf({
  String? trackType,
  String? direction,
  String? courseInOut,
}) {
  final tt = trackType ?? '';
  final dir = direction ?? '';
  final inOut = courseInOut ?? '';

  if (tt.contains('ダ')) return 'dirt';
  if (dir.contains('直')) return 'shiba_straight';
  if (inOut.contains('外')) return 'shiba_outer';
  if (inOut.contains('内')) return 'shiba_inner';
  return 'shiba';
}

/// レースのコースデータを探す。
/// 'shiba' で見つからないときは内回りで探し直す（レース情報タブと同じ）。
/// 障害（[trackType] に「障」）、距離不明、raceId が6文字未満、データが無いときは null。
RaceCourseData? findAiRaceCourse({
  required String raceId,
  required int? distance,
  required String? trackType,
  String? direction,
  String? courseInOut,
}) {
  if (raceId.length < 6 || distance == null) return null;
  if ((trackType ?? '').contains('障')) return null;

  final venueCode = raceId.substring(4, 6);
  final key = aiTrackTypeKeyOf(
    trackType: trackType,
    direction: direction,
    courseInOut: courseInOut,
  );

  var course = CourseElevations.findRaceCourse(venueCode, distance, key);
  if (course == null && key == 'shiba') {
    course = CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
  }
  return course;
}

/// 区間名の日本語表記。知らない名前はそのまま返す。
String aiCourseSectionLabel(String rawName) {
  switch (rawName.toLowerCase()) {
    case 'start':
      return 'スタート';
    case 'start_turf':
      return 'スタート(芝部分)';
    case 'start_dirt':
      return 'スタート(ダート部分)';
    case 'backstretch':
      return '向正面';
    case 'corner_1':
      return '1コーナー';
    case 'corner_2':
      return '2コーナー';
    case 'corner_3':
      return '3コーナー';
    case 'corner_4':
      return '4コーナー';
    case 'home_straight':
      return 'スタンド前直線';
    case 'finish':
      return 'ゴール前直線';
    case 'straight':
      return '直線';
    default:
      return rawName;
  }
}

/// 区間名から分かる路面。分からないときは null。
String? aiCourseSectionSurface(String rawName) {
  final lower = rawName.toLowerCase();
  if (lower.contains('turf') || lower.contains('shiba')) return '芝';
  if (lower.contains('dirt')) return 'ダート';
  return null;
}

/// コースデータから要約を作る。
/// 標高は [sampleStepMeters] ごとにスタートから取り、最後にゴール地点を加える（0以下なら100）。
AiCourseProfile buildAiCourseProfile(
  RaceCourseData course, {
  int sampleStepMeters = 100,
}) {
  final raceDistance = course.raceDistance;
  final drawData = ElevationLogic.generateRaceChartData(course);

  // グラフ用の点を「スタートからの距離(m) → 標高」の表にする。
  // 右回りはグラフで左右反転されている（左端がゴール）ので、距離から引いて戻す。
  final elevationByFromStart = <int, double>{};
  for (final spot in drawData.spots) {
    final fromStart = course.isLeftHanded ? spot.x : raceDistance - spot.x;
    elevationByFromStart.putIfAbsent(fromStart.round(), () => spot.y);
  }

  double elevationAt(double meters) {
    final key = meters.round().clamp(0, raceDistance).toInt();
    return elevationByFromStart[key] ?? 0.0;
  }

  final sections = <AiCourseSectionProfile>[
    for (final section in course.sections)
      AiCourseSectionProfile(
        rawName: section.name,
        label: aiCourseSectionLabel(section.name),
        surface: aiCourseSectionSurface(section.name),
        startMeters: section.startDistance,
        endMeters: section.endDistance,
        startElevation: elevationAt(section.startDistance),
        endElevation: elevationAt(section.endDistance),
      ),
  ];

  final step = sampleStepMeters > 0 ? sampleStepMeters : 100;
  final samples = <AiElevationSample>[];
  for (int m = 0; m < raceDistance; m += step) {
    samples.add(AiElevationSample(
      fromStartMeters: m,
      remainingMeters: raceDistance - m,
      elevation: elevationAt(m.toDouble()),
    ));
  }
  samples.add(AiElevationSample(
    fromStartMeters: raceDistance,
    remainingMeters: 0,
    elevation: elevationAt(raceDistance.toDouble()),
  ));

  double maxElevation = elevationAt(0);
  int maxElevationFromStart = 0;
  double minElevation = maxElevation;
  int minElevationFromStart = 0;
  for (int m = 1; m <= raceDistance; m++) {
    final e = elevationAt(m.toDouble());
    if (e > maxElevation) {
      maxElevation = e;
      maxElevationFromStart = m;
    }
    if (e < minElevation) {
      minElevation = e;
      minElevationFromStart = m;
    }
  }

  return AiCourseProfile(
    venueCode: course.venueCode,
    trackType: course.baseData.trackType,
    raceDistance: raceDistance,
    lapDistance: course.baseData.lapDistance,
    isLeftHanded: course.isLeftHanded,
    isStraightCourse: course.baseData.trackType.contains('straight'),
    sections: sections,
    samples: samples,
    startElevation: elevationAt(0),
    goalElevation: elevationAt(raceDistance.toDouble()),
    maxElevation: maxElevation,
    maxElevationFromStart: maxElevationFromStart,
    minElevation: minElevation,
    minElevationFromStart: minElevationFromStart,
  );
}
