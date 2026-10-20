// lib/logic/condition_record.dart

// [追加] 出走の意味 条件と騎手成績 Step1: 今回のレースの条件（距離・コース）と騎手について、過去走の着度数・3着圏・掲示板圏・勝ち馬との差を出す純粋関数。
// 3着圏・掲示板圏は、その走のレースの全着順のタイムで区切る（3着馬・5着馬の差＋0.1秒以内）。集計はJRAの平地の走だけ。
// 決定は memory/本気度_出走の意味_項目追加_考察.md の7章、設計は memory/本気度_出走の意味_条件と騎手成績_設計書.md。DB・画面・通信には触れない (v.2026.10.20+26102001)

import 'package:hetaumakeiba_v2/logic/previous_race.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

/// 3着圏・掲示板圏の区切り（3着馬・5着馬の差）に足す余裕（秒）
const double kPlaceZoneMarginSec = 0.1;

/// 勝ち馬との差を並べる走の数（新しい順）。これより多い分は「ほか○走」
const int kMarginListMax = 5;

/// 小数の比べの誤差
const double _kTimeEpsilon = 0.001;

/// JRAの競馬場コード（レースIDの5〜6桁目）→ 名前
const Map<String, String> kJraVenueNames = {
  '01': '札幌',
  '02': '函館',
  '03': '福島',
  '04': '新潟',
  '05': '東京',
  '06': '中山',
  '07': '中京',
  '08': '京都',
  '09': '阪神',
  '10': '小倉',
};

/// 1走の区分（その走のレースの全着順のタイムで決める）。
enum PlaceZone {
  /// 3着圏（勝ち馬との差が 3着馬の差＋0.1秒 以内）
  place3,

  /// 掲示板圏（5着馬の差＋0.1秒 以内。3着圏は含まない）
  board,

  /// それより後ろ（中止・失格を含む）
  outside,

  /// 全着順が無い・区切りが無い・その馬のタイムが読めない
  unknown,
}

/// 平地の走の芝ダと距離。
class FlatCourse {
  /// 「芝」か「ダ」
  final String trackType;

  /// 距離（m）
  final int distance;

  const FlatCourse(this.trackType, this.distance);
}

/// JRAのレースか（レースIDが12桁の数字で、5〜6桁目が01〜10）。
bool isJraRaceId(String raceId) {
  final id = raceId.trim();
  if (!RegExp(r'^\d{12}$').hasMatch(id)) return false;
  final code = int.parse(id.substring(4, 6));
  return code >= 1 && code <= 10;
}

/// 過去走の距離（「芝2000」「ダ1800」）から芝ダと距離を読む。障害・読めないときは null。
FlatCourse? flatCourseOf(String distanceText) {
  final match = RegExp(r'^(芝|ダ)(\d+)').firstMatch(distanceText.trim());
  if (match == null) return null;
  return FlatCourse(match.group(1)!, int.parse(match.group(2)!));
}

/// 着順の先頭の数字（「4(降)」→4）。数字で始まらなければ null。
int? rankNumberOf(String rank) {
  final match = RegExp(r'^(\d+)').firstMatch(rank.trim());
  return match == null ? null : int.parse(match.group(1)!);
}

/// タイム（「1:58.3」「58.3」）を秒にする。読めなければ null。
double? parseRaceTimeSec(String text) {
  final match =
      RegExp(r'^(?:(\d+):)?(\d+(?:\.\d+)?)$').firstMatch(text.trim());
  if (match == null) return null;
  final minutes = match.group(1) == null ? 0 : int.parse(match.group(1)!);
  return minutes * 60 + double.parse(match.group(2)!);
}

/// 全着順のコース（raceInfo の先頭。例「芝右 外1600m」）から外回りかを読む。
/// 外回り=true、距離が読めて「外」が無い=false、読めない（結果が無い・発走時刻だけ等）=null。
bool? isOuterCourseOf(RaceResult? result) {
  if (result == null) return null;
  final head = result.raceInfo.split('/').first;
  if (!RegExp(r'\d+m').hasMatch(head)) return null;
  return RegExp(r'(芝|ダ)[右左]\s*外').hasMatch(head);
}

/// [raceDate] より前のJRAの平地の出走（新しい順）。取消・除外は含めない（startsBefore と同じ）。
List<HorseRaceRecord> jraFlatStartsBefore(
  List<HorseRaceRecord> records,
  DateTime raceDate,
) {
  return [
    for (final start in startsBefore(records, raceDate))
      if (isJraRaceId(start.record.raceId) &&
          flatCourseOf(start.record.distance) != null)
        start.record,
  ];
}

/// 1走の区分。[result] はその走のレースの全着順（無ければ null）。
PlaceZone placeZoneOf({
  required HorseRaceRecord record,
  required RaceResult? result,
}) {
  if (result == null) return PlaceZone.unknown;

  // 着順が数字でタイムが読める馬を着順の順に
  final finishers = <MapEntry<int, double>>[];
  for (final horse in result.horseResults) {
    final rank = rankNumberOf(horse.rank);
    final time = parseRaceTimeSec(horse.time);
    if (rank == null || time == null) continue;
    finishers.add(MapEntry(rank, time));
  }
  if (finishers.length < 3) return PlaceZone.unknown;
  finishers.sort((a, b) => a.key.compareTo(b.key));
  var winnerTime = finishers.first.value;
  for (final finisher in finishers) {
    if (finisher.value < winnerTime) winnerTime = finisher.value;
  }
  final third = finishers[2].value - winnerTime;
  final fifth =
      finishers[finishers.length >= 5 ? 4 : finishers.length - 1].value -
          winnerTime;

  // 中止・失格はタイムが無いので圏外（全着順はあるので「全着順の無い走」には数えない）
  final rankText = record.rank.trim();
  if (rankText == '中' || rankText == '失') return PlaceZone.outside;

  HorseResult? mine;
  for (final horse in result.horseResults) {
    if (horse.horseId == record.horseId) {
      mine = horse;
      break;
    }
  }
  final myTime = mine == null ? null : parseRaceTimeSec(mine.time);
  if (myTime == null) return PlaceZone.unknown;
  final diff = myTime - winnerTime;
  if (diff <= third + kPlaceZoneMarginSec + _kTimeEpsilon) {
    return PlaceZone.place3;
  }
  if (diff <= fifth + kPlaceZoneMarginSec + _kTimeEpsilon) {
    return PlaceZone.board;
  }
  return PlaceZone.outside;
}

/// 勝ち馬との差の文字（過去走の着差の列。1着は「勝」、中止は「中止」、失格は「失格」、読めなければ「-」）。
String marginTextOf(HorseRaceRecord record) {
  final rank = record.rank.trim();
  if (rank == '中') return '中止';
  if (rank == '失') return '失格';
  if (rankNumberOf(rank) == 1) return '勝';
  final value = double.tryParse(record.margin.trim());
  if (value == null) return '-';
  return value.toStringAsFixed(1);
}

/// 着度数・3着圏・掲示板圏の回数と、勝ち馬との差の文字。
class ConditionTally {
  /// 出走数
  final int starts;

  /// 1着・2着・3着・着外（中止・失格は着外）
  final int wins;
  final int seconds;
  final int thirds;
  final int others;

  /// 3着圏の回数
  final int place3;

  /// 掲示板圏の回数（3着圏を含む）
  final int board;

  /// 全着順の無い走（3着圏・掲示板圏を判定できなかった走）
  final int unknownResults;

  /// 勝ち馬との差の文字（新しい順・全部）
  final List<String> marginTexts;

  const ConditionTally({
    required this.starts,
    required this.wins,
    required this.seconds,
    required this.thirds,
    required this.others,
    required this.place3,
    required this.board,
    required this.unknownResults,
    required this.marginTexts,
  });
}

/// [starts]（新しい順）を数える。[resultsById] はレースID → 全着順。
ConditionTally tallyOf(
  List<HorseRaceRecord> starts,
  Map<String, RaceResult> resultsById,
) {
  var wins = 0;
  var seconds = 0;
  var thirds = 0;
  var others = 0;
  var place3 = 0;
  var board = 0;
  var unknown = 0;
  final margins = <String>[];
  for (final record in starts) {
    final rank = rankNumberOf(record.rank);
    if (rank == 1) {
      wins++;
    } else if (rank == 2) {
      seconds++;
    } else if (rank == 3) {
      thirds++;
    } else {
      others++;
    }
    final zone = placeZoneOf(
      record: record,
      result: resultsById[record.raceId],
    );
    switch (zone) {
      case PlaceZone.place3:
        place3++;
        board++;
        break;
      case PlaceZone.board:
        board++;
        break;
      case PlaceZone.outside:
        break;
      case PlaceZone.unknown:
        unknown++;
        break;
    }
    margins.add(marginTextOf(record));
  }
  return ConditionTally(
    starts: starts.length,
    wins: wins,
    seconds: seconds,
    thirds: thirds,
    others: others,
    place3: place3,
    board: board,
    unknownResults: unknown,
    marginTexts: margins,
  );
}

/// 「5走 2-2-0-1（3着圏 4回・掲示板圏 5回）」。[withStarts] が false なら走数を書かない（騎手の行）。
String tallyText(ConditionTally tally, {bool withStarts = true}) {
  final counts =
      '${tally.wins}-${tally.seconds}-${tally.thirds}-${tally.others}';
  final notes = <String>[
    '3着圏 ${tally.place3}回',
    '掲示板圏 ${tally.board}回',
    if (tally.unknownResults > 0) '全着順の無い走 ${tally.unknownResults}',
  ];
  final prefix = withStarts ? '${tally.starts}走 ' : '';
  return '$prefix$counts（${notes.join('・')}）';
}

/// 「勝ち馬との差（秒） 勝・0.1・1.2（ほか3走）」。走が無ければ null。
String? marginListText(ConditionTally tally) {
  if (tally.marginTexts.isEmpty) return null;
  final shown = tally.marginTexts.take(kMarginListMax).join('・');
  final rest = tally.marginTexts.length - kMarginListMax;
  final restText = rest > 0 ? '（ほか$rest走）' : '';
  return '勝ち馬との差（秒） $shown$restText';
}

/// 前走との比較の文。前走（[raceDate] より前の一番新しい出走。JRA・地方・外国・障害を問わない）が無い・距離が読めないときは null。
String? previousRaceComparisonText({
  required List<HorseRaceRecord> records,
  required DateTime raceDate,
  required String trackType,
  required int distance,
}) {
  final previous = previousStartOf(records, raceDate);
  if (previous == null) return null;
  final now = '$trackType${distance}m';
  final previousDistance = previous.distance.trim();
  if (previousDistance.startsWith('障')) {
    return '前走 障害 → 今回 $now（障害から平地）';
  }
  final course = flatCourseOf(previousDistance);
  if (course == null) return null;
  final diff = distance - course.distance;
  final distanceText = diff == 0
      ? '同距離'
      : diff > 0
          ? '${diff}m延長'
          : '${-diff}m短縮';
  final String surfaceText;
  if (course.trackType == trackType) {
    surfaceText = '';
  } else if (trackType == '芝') {
    surfaceText = 'ダートから芝・';
  } else {
    surfaceText = '芝からダート・';
  }
  return '前走 ${course.trackType}${course.distance}m → 今回 $now（$surfaceText$distanceText）';
}

/// 条件の行の中身（前走との比較・距離の実績・コースの実績）。
class ConditionRecordLines {
  /// 前走との比較（無ければ null）
  final String? comparison;

  /// 距離の実績（「芝2000mは 5走 …」「芝2000mは実績なし」）
  final String distanceFact;

  /// 距離の実績の補足（勝ち馬との差。実績なしは null）
  final String? distanceDetail;

  /// コースの実績（距離の実績が無い・競馬場名が分からないときは null）
  final String? courseFact;

  /// コースの実績の補足（実績なしは null）
  final String? courseDetail;

  const ConditionRecordLines({
    required this.comparison,
    required this.distanceFact,
    required this.distanceDetail,
    required this.courseFact,
    required this.courseDetail,
  });
}

/// 過去走の芝ダと距離が今回とちょうど同じか。
bool _isSameDistance(HorseRaceRecord record, String trackType, int distance) {
  final course = flatCourseOf(record.distance);
  return course != null &&
      course.trackType == trackType &&
      course.distance == distance;
}

/// 今回のレースの条件（芝ダ・距離・競馬場・内外）で、前走との比較と距離・コースの実績を出す。
/// [trackType] が「芝」「ダ」でない、または [distance] が0以下なら null。
ConditionRecordLines? conditionRecordLinesOf({
  required List<HorseRaceRecord> records,
  required Map<String, RaceResult> resultsById,
  required DateTime raceDate,
  required String trackType,
  required int distance,
  required String venueCode,
  required bool isOuterCourse,
}) {
  if ((trackType != '芝' && trackType != 'ダ') || distance <= 0) return null;

  final comparison = previousRaceComparisonText(
    records: records,
    raceDate: raceDate,
    trackType: trackType,
    distance: distance,
  );

  final label = '$trackType${distance}m';
  final distanceStarts = [
    for (final record in jraFlatStartsBefore(records, raceDate))
      if (_isSameDistance(record, trackType, distance)) record,
  ];
  if (distanceStarts.isEmpty) {
    return ConditionRecordLines(
      comparison: comparison,
      distanceFact: '$labelは実績なし',
      distanceDetail: null,
      courseFact: null,
      courseDetail: null,
    );
  }
  final distanceTally = tallyOf(distanceStarts, resultsById);

  String? courseFact;
  String? courseDetail;
  final venueName = kJraVenueNames[venueCode] ?? '';
  if (venueName.isNotEmpty) {
    final courseStarts = [
      for (final record in distanceStarts)
        if (record.raceId.trim().substring(4, 6) == venueCode &&
            (isOuterCourseOf(resultsById[record.raceId]) == null ||
                isOuterCourseOf(resultsById[record.raceId]) == isOuterCourse))
          record,
    ];
    final courseLabel = '$venueName$label${isOuterCourse ? '（外）' : ''}';
    if (courseStarts.isEmpty) {
      courseFact = 'うち$courseLabelは実績なし';
    } else {
      final courseTally = tallyOf(courseStarts, resultsById);
      courseFact = 'うち$courseLabelは ${tallyText(courseTally)}';
      courseDetail = marginListText(courseTally);
    }
  }

  return ConditionRecordLines(
    comparison: comparison,
    distanceFact: '$labelは ${tallyText(distanceTally)}',
    distanceDetail: marginListText(distanceTally),
    courseFact: courseFact,
    courseDetail: courseDetail,
  );
}

/// 今回の騎手（[jockeyId]）のこの馬での成績「この馬で 0-1-0-1（3着圏 1回・掲示板圏 2回）」。
/// JRAの平地で乗った走が無い・騎手IDが空なら null。
String? jockeyRecordTextOf({
  required List<HorseRaceRecord> records,
  required Map<String, RaceResult> resultsById,
  required DateTime raceDate,
  required String jockeyId,
}) {
  final id = jockeyId.trim();
  if (id.isEmpty) return null;
  final starts = [
    for (final record in jraFlatStartsBefore(records, raceDate))
      if (record.jockeyId.trim() == id) record,
  ];
  if (starts.isEmpty) return null;
  return 'この馬で ${tallyText(tallyOf(starts, resultsById), withStarts: false)}';
}
