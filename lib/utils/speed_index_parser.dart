// lib/utils/speed_index_parser.dart

/// スピード指数算出用に、既存の HorseRaceRecord が保持する各種文字列フィールドを
/// 数値・構造化データへパースする純粋関数群。
library;

/// レースタイム文字列を秒(double)へ変換する。
/// 例: "2:04.8" → 124.8, "3:50.9" → 230.9
/// 分区切りの ":" を含まない場合は秒のみとして解釈する。
/// 変換不能、または 0以下 もしくは 1200 を超える異常値は null を返す。
double? parseRaceTime(String raceTime) {
  final trimmed = raceTime.trim();
  if (trimmed.isEmpty) return null;

  double? seconds;
  if (trimmed.contains(':')) {
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final secPart = double.tryParse(parts[1]);
    if (minutes == null || secPart == null) return null;
    seconds = minutes * 60 + secPart;
  } else {
    seconds = double.tryParse(trimmed);
  }

  if (seconds == null || seconds <= 0 || seconds > 1200) return null;
  return seconds;
}

/// 距離文字列から馬場種別と距離(m)を抽出する。
/// 例: "芝1800" → (surface: '芝', meters: 1800)
///     "ダ1800" → (surface: 'ダ', meters: 1800)
///     "障3380" → (surface: '障', meters: 3380)
/// 馬場種別・数値のいずれかが取得できない場合は null を返す。
({String surface, int meters})? parseDistance(String distance) {
  final trimmed = distance.trim();
  if (trimmed.isEmpty) return null;

  final match = RegExp(r'^(芝|ダ|障)(\d+)$').firstMatch(trimmed);
  if (match == null) return null;

  final surface = match.group(1)!;
  final meters = int.tryParse(match.group(2)!);
  if (meters == null) return null;

  return (surface: surface, meters: meters);
}

/// 斤量文字列を数値(double)へ変換する。
/// 例: "58.5" → 58.5, "57" → 57.0
/// 変換不能な場合は null を返す。
double? parseCarriedWeight(String carriedWeight) {
  final trimmed = carriedWeight.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

/// 馬体重文字列から体重と増減(kg)を抽出する。
/// 例: "490(+2)" → (weight: 490, diff: 2), "488(-10)" → (weight: 488, diff: -10)
/// 増減カッコが無い場合は diff: null を返す。体重が取得できない場合は null を返す。
({int weight, int? diff})? parseHorseWeight(String horseWeight) {
  final trimmed = horseWeight.trim();
  if (trimmed.isEmpty) return null;

  final match = RegExp(r'^(\d+)(?:\(([+-]?\d+)\))?$').firstMatch(trimmed);
  if (match == null) return null;

  final weight = int.tryParse(match.group(1)!);
  if (weight == null) return null;

  final diffStr = match.group(2);
  final diff = diffStr != null ? int.tryParse(diffStr) : null;

  return (weight: weight, diff: diff);
}

/// ペース文字列から前半・後半3ハロンタイム(秒)を抽出する。
/// 例: "35.4-38.0" → (front: 35.4, back: 38.0)
/// 変換不能な場合はそれぞれ null を返す（両方 null の場合は全体で null）。
({double? front, double? back})? parsePace(String pace) {
  final trimmed = pace.trim();
  if (trimmed.isEmpty) return null;

  final parts = trimmed.split('-');
  if (parts.length != 2) return null;

  final front = double.tryParse(parts[0].trim());
  final back = double.tryParse(parts[1].trim());
  if (front == null && back == null) return null;

  return (front: front, back: back);
}

/// 開催文字列から開催回・競馬場名・開催日を抽出する。
/// 例: "1阪神3" → (kai: 1, track: '阪神', day: 3)
/// 変換不能な場合は null を返す。
({int kai, String track, int day})? parseVenue(String venue) {
  final trimmed = venue.trim();
  if (trimmed.isEmpty) return null;

  final match = RegExp(r'^(\d+)([^\d]+?)(\d+)$').firstMatch(trimmed);
  if (match == null) return null;

  final kai = int.tryParse(match.group(1)!);
  final track = match.group(2)!;
  final day = int.tryParse(match.group(3)!);
  if (kai == null || track.isEmpty || day == null) return null;

  return (kai: kai, track: track, day: day);
}
