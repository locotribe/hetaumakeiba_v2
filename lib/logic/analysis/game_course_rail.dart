// lib/logic/analysis/game_course_rail.dart
// [修正] 展開シミュ改良Step8: 使用コース(A〜Dコース)を出馬表の「(左 B)」から読み、内の馬場の傷みのしきい値を、開催の日目と今日の使用コースだけから作る純粋ロジックにした。
// 開催ごとの使用コースの表(2025年10月〜2026年12月)はやめた。傷みは、Aコースの内柵を基準にした傷みの地図(過去の使用日 i 日目で i レーン分が傷む)を、
// 今日の内柵の所から読む(いつコースが替わったかは使わない)。続けて数える開催も、その開催の1日目から数える。
// 参照実装は Claude outputs/展開シミュ_ゲーム式原型/course_rail3.py。設計は memory/展開シミュ_使用コース_設計書.md (v.2026.10.30+26103007)

import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';

/// レースの使用コースと傷み。
class GameCourseRailInfo {
  /// 今日の使用コース('A'〜'D')
  final String course;

  /// 傷みのしきい値(今日の内柵からの距離 m。直線部)。GameRaceConfig.wearThresholds に渡す
  final List<double> wearThresholds;

  /// 傷みのしきい値(曲線部)。GameRaceConfig.wearThresholdsCurve に渡す
  final List<double> wearThresholdsCurve;

  const GameCourseRailInfo({
    required this.course,
    required this.wearThresholds,
    required this.wearThresholdsCurve,
  });
}

class GameCourseRail {
  GameCourseRail._();

  /// エンジンの1レーン(m。1頭分 = コース幅の18分の1)
  static const double laneMeters = GameRaceEngine.courseWidthMeters / 18.0;

  /// 場ごとの、Aコースからの内柵の移動幅(m)。コース → [直線部, 曲線部]。馬場概要の「Aコースから○メートル外に内柵を設置」
  static const Map<String, Map<String, List<double>>> railOffsets = {
    '01': {
      'A': [0.0, 0.0],
      'B': [1.5, 1.5],
      'C': [3.0, 3.0]
    }, // 札幌
    '02': {
      'A': [0.0, 0.0],
      'B': [4.0, 4.0]
    }, // 函館
    '03': {
      'A': [0.0, 0.0],
      'B': [2.0, 2.0]
    }, // 福島
    '04': {
      'A': [0.0, 0.0],
      'B': [4.0, 4.0]
    }, // 新潟
    '05': {
      'A': [0.0, 0.0],
      'B': [3.0, 3.0],
      'C': [6.0, 6.0],
      'D': [9.0, 9.0]
    }, // 東京
    '06': {
      'A': [0.0, 0.0],
      'B': [3.0, 3.0],
      'C': [6.0, 6.0]
    }, // 中山
    '07': {
      'A': [0.0, 0.0],
      'B': [3.0, 3.0]
    }, // 中京
    '08': {
      'A': [0.0, 0.0],
      'B': [4.0, 3.0],
      'C': [7.0, 6.0],
      'D': [10.0, 9.0]
    }, // 京都
    '09': {
      'A': [0.0, 0.0],
      'B': [3.0, 4.0]
    }, // 阪神
    '10': {
      'A': [0.0, 0.0],
      'B': [3.0, 3.0]
    }, // 小倉
  };

  /// 出馬表のコースの表記(PredictionRaceData.courseInOut。例 'B'・'外 B'・'内2周 A')から、使用コース('A'〜'D')。
  /// 末尾が A〜D の1文字でなければ null(ダートなど、使用コースが書かれていないレース)
  static String? courseOf(String? courseInOut) {
    if (courseInOut == null) return null;
    final m = RegExp(r'(?:^|\s)([A-D])$').firstMatch(courseInOut.trim());
    return m?.group(1);
  }

  /// レースID(年4桁+場2桁+回2桁+日目2桁+レース番号2桁)と出馬表のコースの表記から、使用コースと傷み。
  /// 傷みのしきい値は、過去の使用日 i 日目(i = 1〜日目−1)ごとに「i レーン分 − 今日の内柵の移動幅」。
  /// 使用コースが読めない・その場に無いコース・場がJRAでない・日目が読めないときは null
  static GameCourseRailInfo? infoOf(String raceId, String? courseInOut) {
    if (raceId.length < 10) return null;
    final venue = raceId.substring(4, 6);
    final day = int.tryParse(raceId.substring(8, 10));
    if (day == null || day < 1) return null;
    final course = courseOf(courseInOut);
    if (course == null) return null;
    final today = railOffsets[venue]?[course];
    if (today == null) return null;
    final straight = <double>[];
    final curve = <double>[];
    for (int i = 1; i < day; i++) {
      straight.add(i * laneMeters - today[0]);
      curve.add(i * laneMeters - today[1]);
    }
    return GameCourseRailInfo(
      course: course,
      wearThresholds: straight,
      wearThresholdsCurve: curve,
    );
  }
}
