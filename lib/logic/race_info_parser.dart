// lib/logic/race_info_parser.dart
// [追加] レース結果のraceInfoテキストからコース情報を復元する共通パーサー (v.13.41.1)

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
  // 例: "ダ右1900m / 天候 : 雨 / ダート : 稍重" や "芝右2200m(内) / 天候 : 晴 / 芝 : 良" から
  // トラック種別・方向・距離・内外回りを抽出する。
  static final RegExp _courseInfoPattern =
      RegExp(r'(芝|ダ|障)(右|左|直)?(\d+)m(?:\((外|内)\))?');

  /// RaceResult.raceInfoからコース情報を抽出する。
  /// マッチしない場合は全てnullの[RaceCourseInfo]を返す。
  static RaceCourseInfo parse(String raceInfo) {
    final match = _courseInfoPattern.firstMatch(raceInfo);
    if (match == null) return const RaceCourseInfo();

    return RaceCourseInfo(
      trackType: match.group(1),
      direction: match.group(2),
      distanceValue: int.tryParse(match.group(3)!),
      courseInOut: match.group(4),
    );
  }
}
