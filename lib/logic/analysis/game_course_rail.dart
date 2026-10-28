// lib/logic/analysis/game_course_rail.dart
// [追加] 展開シミュ改良Step3(案C): レースの使用コース(A〜Dコース)・コースが替わってからの日数・内の馬場の傷みのしきい値を作る純粋ロジック。
// 出典は JRA「馬場概要」ページ(開催ごと)と「2026年度 競馬番組の要点」。参照実装は原型の course_rail2.py。
// 設計は memory/展開シミュ_改良案_考察.md の案C と「オーナーの判断(2026-10-28 午前)と、それを受けた検証」 (v.2026.10.28+26102803)

import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';

/// 使用コースの区切り。[days] が null なら、その開催の残り全部(最後の区切りだけ)。
class GameRailSegment {
  final String course;
  final int? days;
  const GameRailSegment(this.course, this.days);
}

/// 1つの開催(回)の使用コース。
class GameMeeting {
  /// 開催の日数(分からなければ null)
  final int? totalDays;
  final List<GameRailSegment> segments;

  /// 前の開催(1つ前の回)から間をあけずに続く開催なら true(傷みの日数を通して数える)
  final bool continuesFromPrevious;

  const GameMeeting(this.totalDays, this.segments, this.continuesFromPrevious);
}

/// レースの使用コースと傷み。
class GameCourseRailInfo {
  /// 今日の使用コース('A'〜'D')
  final String course;

  /// コースが替わってからの日数(1始まり。続けて同じコースを使った日を、前の開催も通して数える)
  final int daysSinceChange;

  /// 傷みのしきい値(今日の内柵からの距離 m。直線部)。GameRaceConfig.wearThresholds に渡す
  final List<double> wearThresholds;

  /// 傷みのしきい値(曲線部)。GameRaceConfig.wearThresholdsCurve に渡す
  final List<double> wearThresholdsCurve;

  const GameCourseRailInfo({
    required this.course,
    required this.daysSinceChange,
    required this.wearThresholds,
    required this.wearThresholdsCurve,
  });
}

class GameCourseRail {
  GameCourseRail._();

  /// エンジンの1レーン(m。1頭分 = コース幅の18分の1)
  static const double laneMeters = GameRaceEngine.courseWidthMeters / 18.0;

  /// 開催ごとの使用コース。キーは「年-場-回」(例 '2026-05-04' = 2026年 東京 4回)。
  /// 2025年10月〜2026年12月。間をあけずに続く開催(馬場概要が1つのページにまとまっている開催)は日数を通して数える。
  /// 中山5・阪神5・中京4・福島3(2026)は馬場概要がまだ無いので、番組の要点の表から作った
  static const Map<String, GameMeeting> meetings = {
    // ---- 2025年(10〜12月) ----
    '2025-03-03': GameMeeting(
        6, [GameRailSegment('A', 4), GameRailSegment('B', 2)], false), // 福島3回
    '2025-04-04': GameMeeting(4, [GameRailSegment('A', 4)], false), // 新潟4回
    '2025-05-04': GameMeeting(
        11, [GameRailSegment('A', 9), GameRailSegment('B', 2)], false), // 東京4回
    '2025-05-05': GameMeeting(
        8, [GameRailSegment('B', 4), GameRailSegment('C', 4)], true), // 東京5回
    '2025-06-05': GameMeeting(8, [GameRailSegment('A', 8)], false), // 中山5回
    '2025-07-05': GameMeeting(6, [GameRailSegment('A', 6)], false), // 中京5回
    '2025-08-03': GameMeeting(
        11, [GameRailSegment('A', 9), GameRailSegment('B', 2)], false), // 京都3回
    '2025-08-04': GameMeeting(
        8, [GameRailSegment('B', 4), GameRailSegment('C', 4)], true), // 京都4回
    '2025-09-05': GameMeeting(
        8, [GameRailSegment('A', 6), GameRailSegment('B', 2)], false), // 阪神5回
    // ---- 2026年 ----
    '2026-01-01': GameMeeting(8, [GameRailSegment('A', 8)], false), // 札幌1回
    '2026-01-02': GameMeeting(
        6, [GameRailSegment('B', 4), GameRailSegment('C', 2)], true), // 札幌2回
    '2026-02-01': GameMeeting(
        12, [GameRailSegment('A', 8), GameRailSegment('B', 4)], false), // 函館1回
    '2026-03-01': GameMeeting(
        6, [GameRailSegment('A', 4), GameRailSegment('B', 2)], false), // 福島1回
    '2026-03-02': GameMeeting(
        8, [GameRailSegment('A', 4), GameRailSegment('B', 4)], false), // 福島2回
    '2026-03-03': GameMeeting(null,
        [GameRailSegment('A', 4), GameRailSegment('B', null)], false), // 福島3回
    '2026-04-01': GameMeeting(8, [GameRailSegment('B', 8)], false), // 新潟1回
    '2026-04-02': GameMeeting(8, [GameRailSegment('A', 8)], false), // 新潟2回
    '2026-04-03': GameMeeting(4, [GameRailSegment('A', 4)], true), // 新潟3回
    '2026-04-04': GameMeeting(4, [GameRailSegment('A', 4)], false), // 新潟4回
    '2026-05-01': GameMeeting(8, [GameRailSegment('D', 8)], false), // 東京1回
    '2026-05-02': GameMeeting(
        12,
        [
          GameRailSegment('A', 6),
          GameRailSegment('B', 4),
          GameRailSegment('C', 2)
        ],
        false), // 東京2回
    '2026-05-03': GameMeeting(
        6, [GameRailSegment('C', 4), GameRailSegment('D', 2)], true), // 東京3回
    '2026-05-04': GameMeeting(
        11, [GameRailSegment('A', 9), GameRailSegment('B', 2)], false), // 東京4回
    '2026-05-05': GameMeeting(
        9, [GameRailSegment('B', 4), GameRailSegment('C', 5)], true), // 東京5回
    '2026-06-01': GameMeeting(
        9, [GameRailSegment('B', 2), GameRailSegment('C', 7)], false), // 中山1回
    '2026-06-02': GameMeeting(8, [GameRailSegment('A', 8)], false), // 中山2回
    '2026-06-03': GameMeeting(
        8,
        [
          GameRailSegment('A', 2),
          GameRailSegment('B', 4),
          GameRailSegment('C', 2)
        ],
        true), // 中山3回
    '2026-06-04': GameMeeting(
        9, [GameRailSegment('B', 4), GameRailSegment('C', 5)], false), // 中山4回
    '2026-06-05':
        GameMeeting(null, [GameRailSegment('A', null)], false), // 中山5回
    '2026-07-01': GameMeeting(
        6, [GameRailSegment('A', 4), GameRailSegment('B', 2)], false), // 中京1回
    '2026-07-02': GameMeeting(8, [GameRailSegment('A', 8)], false), // 中京2回
    '2026-07-03': GameMeeting(4, [GameRailSegment('B', 4)], true), // 中京3回
    '2026-07-04': GameMeeting(null,
        [GameRailSegment('A', 4), GameRailSegment('B', null)], false), // 中京4回
    '2026-08-01': GameMeeting(9, [GameRailSegment('A', 9)], false), // 京都1回
    '2026-08-02': GameMeeting(6, [GameRailSegment('B', 6)], true), // 京都2回
    '2026-08-03': GameMeeting(
        12, [GameRailSegment('C', 6), GameRailSegment('D', 6)], false), // 京都3回
    '2026-08-04': GameMeeting(
        11, [GameRailSegment('A', 9), GameRailSegment('B', 2)], false), // 京都4回
    '2026-08-05': GameMeeting(
        8, [GameRailSegment('B', 4), GameRailSegment('C', 4)], true), // 京都5回
    '2026-09-01': GameMeeting(10, [GameRailSegment('A', 10)], false), // 阪神1回
    '2026-09-02': GameMeeting(
        8, [GameRailSegment('A', 4), GameRailSegment('B', 4)], true), // 阪神2回
    '2026-09-03': GameMeeting(6, [GameRailSegment('B', 6)], false), // 阪神3回
    '2026-09-04': GameMeeting(
        9, [GameRailSegment('A', 4), GameRailSegment('B', 5)], false), // 阪神4回
    '2026-09-05': GameMeeting(null,
        [GameRailSegment('A', 6), GameRailSegment('B', null)], false), // 阪神5回
    '2026-10-01': GameMeeting(
        12, [GameRailSegment('A', 6), GameRailSegment('B', 6)], false), // 小倉1回
    '2026-10-02': GameMeeting(8, [GameRailSegment('A', 8)], false), // 小倉2回
  };

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

  static String _key(String year, String venue, int kai) =>
      '$year-$venue-${kai.toString().padLeft(2, '0')}';

  /// その開催の1〜[days]日目の使用コース。表に無ければ null
  static List<String>? coursesOf(String year, String venue, int kai, int days) {
    final m = meetings[_key(year, venue, kai)];
    if (m == null) return null;
    int fixed = 0;
    for (final s in m.segments) {
      fixed += s.days ?? 0;
    }
    final out = <String>[];
    for (final s in m.segments) {
      final d = s.days;
      final len = d ?? (days - fixed > 0 ? days - fixed : 0);
      for (int k = 0; k < len; k++) {
        out.add(s.course);
      }
    }
    while (out.length < days) {
      out.add(m.segments.last.course);
    }
    return out.sublist(0, days);
  }

  /// レースID(年4桁+場2桁+回2桁+日目2桁+レース番号2桁)から、使用コースと傷み。表に無い・読めないときは null
  static GameCourseRailInfo? infoOf(String raceId) {
    if (raceId.length < 10) return null;
    final year = raceId.substring(0, 4);
    final venue = raceId.substring(4, 6);
    final kai = int.tryParse(raceId.substring(6, 8));
    final day = int.tryParse(raceId.substring(8, 10));
    if (kai == null || day == null || day < 1) return null;
    final cur = coursesOf(year, venue, kai, day);
    if (cur == null || cur.isEmpty) return null;
    // 今日より前の使用日(古い順)。続けて数える前の開催は、全部の日を前に足す
    var hist = cur.sublist(0, cur.length - 1);
    int k = kai;
    while (meetings[_key(year, venue, k)]!.continuesFromPrevious) {
      final prev = meetings[_key(year, venue, k - 1)];
      final total = prev?.totalDays;
      if (prev == null || total == null) return null;
      hist = [...coursesOf(year, venue, k - 1, total)!, ...hist];
      k--;
    }
    final today = cur.last;
    final rails = railOffsets[venue];
    if (rails == null || rails[today] == null) return null;
    for (final c in hist) {
      if (rails[c] == null) return null;
    }
    int days = 1;
    for (int j = hist.length - 1; j >= 0; j--) {
      if (hist[j] != today) break;
      days++;
    }
    final straight = <double>[];
    final curve = <double>[];
    for (int i = 0; i < hist.length; i++) {
      final r = rails[hist[i]]!;
      straight.add(r[0] + (i + 1) * laneMeters - rails[today]![0]);
      curve.add(r[1] + (i + 1) * laneMeters - rails[today]![1]);
    }
    return GameCourseRailInfo(
      course: today,
      daysSinceChange: days,
      wearThresholds: straight,
      wearThresholdsCurve: curve,
    );
  }
}