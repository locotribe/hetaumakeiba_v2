// lib/logic/race_info_parser.dart

// [修正] 過去レース表記揺れ吸収: netkeibaの結果ページの書き方「芝右 外1600m」「芝直線1000m」
// 「芝右 内2周3600m」「障芝 外-内2850m」と、race.netkeibaの書き方「芝2200m (右 外 C)」を
// 読めるようにした。書いてあることだけを読み、無印(内回り)の courseInOut は null のままにする。
// 障害は trackType='障' で返す。ばんえい(直200m)は対象外で全て null (v.2026.9.30+26093004)

/// raceInfoテキストから抽出したコース情報
class RaceCourseInfo {
  final String? trackType;
  final String? direction;
  final int? distanceValue;
  final String? courseInOut;

  const RaceCourseInfo({
    this.trackType,
    this.direction,
    this.distanceValue,
    this.courseInOut,
  });
}

class RaceInfoParser {
  // race.netkeiba の書き方(確定直後の結果・出馬表と同じ):
  //   "15:45発走 / 芝2200m (右 外 C) / 天候:雨 / 馬場:重"
  // 括弧の中の方向より後ろは、出馬表(shutuba_table_scraper_service)と同じく
  // そのまま courseInOut にする(例: "外 C" / "A" / "内2周 A")。
  static final RegExp _raceNetkeibaPattern = RegExp(
      r'(障|芝|ダ)(芝|ダート)?(\d+)m\s*\((右|左|直線|直)(?:\s+([^)]+))?\)');

  // db.netkeiba(結果ページ)の書き方:
  //   "芝右 外1600m / 天候 : 晴 / 芝 : 良 / 発走 : 15:30"
  // 外回りだけ距離の前に「外」が付き、内回りは無印。例:
  //   芝右1800m / 芝右 外1600m / 芝直線1000m / 芝右 内2周3600m / ダ右1800m
  //   障芝2750m / 障芝 外-内2850m / 障芝 ダート2880m
  // 旧形式の "芝右2200m(内)" も読む。
  static final RegExp _dbNetkeibaPattern = RegExp(
      r'(障|芝|ダ)(芝|ダート)?(右|左|直線|直)?\s*((?:外-内|内-外|外|内)(?:\d周)?)?\s*(?:ダート)?(\d+)m(?:\((外|内)\))?');

  /// RaceResult.raceInfoからコース情報を抽出する。
  /// マッチしない場合は全てnullの[RaceCourseInfo]を返す。
  static RaceCourseInfo parse(String raceInfo) {
    final netkeibaMatch = _raceNetkeibaPattern.firstMatch(raceInfo);
    if (netkeibaMatch != null) {
      final inOut = netkeibaMatch.group(5)?.trim();
      return RaceCourseInfo(
        trackType: netkeibaMatch.group(1),
        direction: _normalizeDirection(netkeibaMatch.group(4)),
        distanceValue: int.tryParse(netkeibaMatch.group(3)!),
        courseInOut: (inOut == null || inOut.isEmpty) ? null : inOut,
      );
    }

    final dbMatch = _dbNetkeibaPattern.firstMatch(raceInfo);
    if (dbMatch == null) return const RaceCourseInfo();

    return RaceCourseInfo(
      trackType: dbMatch.group(1),
      direction: _normalizeDirection(dbMatch.group(3)),
      distanceValue: int.tryParse(dbMatch.group(5)!),
      courseInOut: dbMatch.group(4) ?? dbMatch.group(6),
    );
  }

  /// 方向の「直線」を出馬表と同じ「直」にそろえる。
  static String? _normalizeDirection(String? raw) {
    if (raw == null) return null;
    if (raw == '直線') return '直';
    return raw;
  }
}
