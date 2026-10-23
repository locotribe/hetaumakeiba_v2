// lib/logic/training_record.dart

// [追加] 出走の意味 調教の行 Step1: 前走の後の調教（pakara の坂路・ウッド、アプリ独自の評価、netkeiba の追い切りと脚色）と近況（放牧の投稿）から、
// 「出走の意味」の調教・近況の行の文を作る純粋関数と、計算し直しの判定に使う指紋。設計は memory/本気度_出走の意味_調教の行_設計書.md の5章・4-1。
// DB・画面・通信には触れない (v.2026.10.24+26102401)

import 'package:hetaumakeiba_v2/logic/training_evaluation.dart';
import 'package:hetaumakeiba_v2/models/horse_condition_post_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

/// 調教のない期間を出す最短の日数（これ以上のときだけ出す。仮の値）
const int kTrainingGapDaysToShow = 14;

/// 近況の投稿日を並べる最大の件数。これより多い分は「ほか○件」
const int kConditionPostDatesMax = 5;

/// レース全体の注記（R3）の文
const String kTrainingScopeNote =
    '調教の行は坂路・ウッドの時計だけを数えています（ポリトラック・DP・芝・外厩は含まない）。netkeiba の行は追い切りだけ';

/// 基準差の比べの誤差
const double _kDiffEpsilon = 0.001;

/// 1頭分の調教・近況の行の文。出さない行は null。
class TrainingRecordLines {
  /// T1 前走後の坂路・ウッドの本数（いつも出す）
  final String countFact;

  /// T1 の補足（前走の日まで取り切れていないとき）
  final String? countDetail;

  /// T2 調教のない期間（14日以上のときだけ）
  final String? gapFact;

  /// T5 アプリ独自の評価（基準差が出せる調教が1本以上のときだけ）
  final String? evaluationFact;

  /// T5 の補足（最終・鬼脚・意図）
  final String? evaluationDetail;

  /// T6 netkeiba の追い切り（1本以上のときだけ）
  final String? netkeibaFact;

  /// T6 の補足（最終追切の評価・脚色の無いとき）
  final String? netkeibaDetail;

  /// T4 近況（前走後に放牧の投稿があるときだけ）
  final String? postFact;

  const TrainingRecordLines({
    required this.countFact,
    this.countDetail,
    this.gapFact,
    this.evaluationFact,
    this.evaluationDetail,
    this.netkeibaFact,
    this.netkeibaDetail,
    this.postFact,
  });
}

/// 日付を YYYYMMDD にする。
String trainingYmdOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';

/// YYYYMMDD を日付（UTC の0時）にする。読めなければ null。
DateTime? _dateOfYmd(String ymd) {
  if (!RegExp(r'^\d{8}$').hasMatch(ymd)) return null;
  return DateTime.utc(int.parse(ymd.substring(0, 4)),
      int.parse(ymd.substring(4, 6)), int.parse(ymd.substring(6, 8)));
}

DateTime _utcDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

int _daysBetween(DateTime from, DateTime to) =>
    _utcDay(to).difference(_utcDay(from)).inDays;

/// 日付の表示（今回のレースと同じ年は「9/15」、違う年は「2025/9/15」）。
String _shortDate(DateTime date, DateTime raceDate) {
  final md = '${date.month}/${date.day}';
  return date.year == raceDate.year ? md : '${date.year}/$md';
}

/// 前走の日の翌日からレース日の前日までか（YYYYMMDD の文字列で比べる）。
bool _inPeriod(String ymd, String fromYmd, String raceYmd) {
  if (!RegExp(r'^\d{8}$').hasMatch(ymd)) return false;
  return ymd.compareTo(fromYmd) > 0 && ymd.compareTo(raceYmd) < 0;
}

/// 基準差の表示（「-1.2」「+0.4」「0.0」）。調教タイムの画面と同じ書き方。
String _diffText(double diff) {
  final sign = diff > 0 ? '+' : '';
  return '$sign${diff.toStringAsFixed(1)}';
}

/// 意図のラベルの括弧の前まで（「終い特化(キレ確認)」→「終い特化」）。
String _shortIntentLabel(TrainingIntent intent) {
  final index = intent.label.indexOf('(');
  return index < 0 ? intent.label : intent.label.substring(0, index);
}

/// 並べ替える（比べて同じものは入力の順のまま）。
List<T> _stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = List<MapEntry<int, T>>.generate(
      items.length, (i) => MapEntry(i, items[i]));
  indexed.sort((a, b) {
    final result = compare(a.value, b.value);
    return result != 0 ? result : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

/// 数えた文字を多い順に並べる（同じ数は出てきた順）。
List<MapEntry<String, int>> _sortedCounts(Map<String, int> counts) {
  final entries = counts.entries.toList();
  final order = {for (var i = 0; i < entries.length; i++) entries[i].key: i};
  entries.sort((a, b) {
    final byCount = b.value.compareTo(a.value);
    if (byCount != 0) return byCount;
    return order[a.key]!.compareTo(order[b.key]!);
  });
  return entries;
}

/// 1頭分の調教・近況の行の文を作る。
///
/// [previousStartDate] 前走の日（この翌日からレース日の前日までの分を使う）。
/// [pakara] その馬の pakara の調教（期間外を含んでよい）。
/// [netkeibaSessions] その馬の netkeiba の調教（期間外・source は問わない）。
/// [finalOikiriRank] このレースの最終追切の評価（A〜E）。無ければ null。
/// [posts] その馬の近況の投稿。
/// [backfillComplete] pakara を前走の日まで取り終えたか（false なら T1 に補足を付ける）。
TrainingRecordLines trainingRecordLinesOf({
  required DateTime raceDate,
  required DateTime previousStartDate,
  List<TrainingTimeModel> pakara = const [],
  List<NetkeibaTrainingSession> netkeibaSessions = const [],
  String? finalOikiriRank,
  List<HorseConditionPost> posts = const [],
  bool backfillComplete = true,
}) {
  final raceYmd = trainingYmdOf(raceDate);
  final fromYmd = trainingYmdOf(previousStartDate);
  final previousText = _shortDate(previousStartDate, raceDate);

  // ---- T1 本数 ----
  final rows = _stableSorted(
      pakara
          .where((t) =>
              (t.trackType == '坂路' || t.trackType == 'ウッド') &&
              _inPeriod(t.trainingDate, fromYmd, raceYmd))
          .toList(), (a, b) {
    final byDate = a.trainingDate.compareTo(b.trainingDate);
    if (byDate != 0) return byDate;
    return a.trainingTime.compareTo(b.trainingTime);
  });
  final hanroCount = rows.where((t) => t.trackType == '坂路').length;
  final woodCount = rows.where((t) => t.trackType == 'ウッド').length;
  final String countFact;
  if (rows.isEmpty) {
    countFact = '前走（$previousText）後の坂路・ウッドの調教なし';
  } else {
    final kinds = <String>[
      if (hanroCount > 0) '坂路$hanroCount本',
      if (woodCount > 0) 'ウッド$woodCount本',
    ];
    final first = _dateOfYmd(rows.first.trainingDate)!;
    final latest = _dateOfYmd(rows.last.trainingDate)!;
    countFact = '前走（$previousText）後の坂路・ウッド ${kinds.join('・')}'
        '（最初は前走の${_daysBetween(previousStartDate, first)}日後・'
        '最新は${_daysBetween(latest, raceDate)}日前）';
  }
  final countDetail = backfillComplete ? null : '前走の日まで取り切れていない可能性あり';

  // ---- T2 調教のない期間 ----
  String? gapFact;
  if (rows.isNotEmpty) {
    final points = <DateTime>[_utcDay(previousStartDate)];
    for (final ymd in rows.map((t) => t.trainingDate).toSet()) {
      points.add(_dateOfYmd(ymd)!);
    }
    points.sort();
    var bestDays = -1;
    DateTime? bestFrom;
    DateTime? bestTo;
    for (var i = 0; i < points.length - 1; i++) {
      final days = _daysBetween(points[i], points[i + 1]) - 1;
      if (days > bestDays) {
        bestDays = days;
        bestFrom = points[i];
        bestTo = points[i + 1];
      }
    }
    if (bestDays >= kTrainingGapDaysToShow &&
        bestFrom != null &&
        bestTo != null) {
      final start = bestFrom.add(const Duration(days: 1));
      final end = bestTo.subtract(const Duration(days: 1));
      gapFact = '調教のない期間 最長$bestDays日'
          '（${_shortDate(start, raceDate)}〜${_shortDate(end, raceDate)}）';
    }
  }

  // ---- T5 アプリ独自の評価 ----
  String? evaluationFact;
  String? evaluationDetail;
  final comparable = <TrainingTimeModel>[];
  final diffs = <double>[];
  for (final t in rows) {
    if (!isComparableCourse(t)) continue;
    final diff = baseDiff(t);
    if (diff == null) continue;
    comparable.add(t);
    diffs.add(diff);
  }
  if (comparable.isNotEmpty) {
    final faster = diffs.where((d) => d < -_kDiffEpsilon).length;
    var fastestIndex = 0;
    for (var i = 1; i < diffs.length; i++) {
      if (diffs[i] < diffs[fastestIndex] - _kDiffEpsilon) fastestIndex = i;
    }
    final fastest = comparable[fastestIndex];
    evaluationFact = '基準より速い $faster本／比べられる ${comparable.length}本'
        '（最速 ${fastest.trackType} ${_diffText(diffs[fastestIndex])}・'
        '${_shortDate(_dateOfYmd(fastest.trainingDate)!, raceDate)}）';

    final last = comparable.last;
    final lastIntent = trainingIntent(last);
    final parts = <String>[
      '最終 ${_shortDate(_dateOfYmd(last.trainingDate)!, raceDate)} '
          '${last.trackType} 基準差 ${_diffText(diffs.last)}'
          '${lastIntent == null ? '' : '・${_shortIntentLabel(lastIntent)}'}',
    ];
    final oniashi = rows.where(isOniashi).length;
    if (oniashi > 0) parts.add('鬼脚 $oniashi本');
    final intentCounts = <String, int>{};
    for (final t in rows) {
      final intent = trainingIntent(t);
      if (intent == null) continue;
      final label = _shortIntentLabel(intent);
      intentCounts[label] = (intentCounts[label] ?? 0) + 1;
    }
    if (intentCounts.isNotEmpty) {
      parts.add('意図 ${_sortedCounts(intentCounts).map((e) => '${e.key}${e.value}').join('・')}');
    }
    evaluationDetail = parts.join('／');
  }

  // ---- T6 netkeiba の追い切り ----
  String? netkeibaFact;
  String? netkeibaDetail;
  final sessions = _stableSorted(
      netkeibaSessions
          .where((s) => _inPeriod(s.trainingDate, fromYmd, raceYmd))
          .toList(), (a, b) {
    final byDate = a.trainingDate.compareTo(b.trainingDate);
    if (byDate != 0) return byDate;
    return a.seq.compareTo(b.seq);
  });
  if (sessions.isNotEmpty) {
    final loadCounts = <String, int>{};
    var noLoad = 0;
    final courses = <String>[];
    for (final s in sessions) {
      final load = s.trainingLoad?.trim() ?? '';
      if (load.isEmpty) {
        noLoad++;
      } else {
        loadCounts[load] = (loadCounts[load] ?? 0) + 1;
      }
      final course = s.courseRaw.trim();
      if (course.isNotEmpty && !courses.contains(course)) courses.add(course);
    }
    final loadParts = <String>[
      for (final e in _sortedCounts(loadCounts)) '${e.key}${e.value}',
      if (noLoad > 0) '脚色なし$noLoad',
    ];
    netkeibaFact = 'netkeiba 追い切り ${sessions.length}本'
        '（${loadParts.join('・')}）'
        '${courses.join('・')}';
    final detailParts = <String>[
      if (finalOikiriRank != null && finalOikiriRank.trim().isNotEmpty)
        '最終追切の評価 ${finalOikiriRank.trim()}',
      if (loadCounts.isEmpty) '脚色なし（公開前か未掲載。重賞は前日・GⅠは前々日の13時頃）',
    ];
    netkeibaDetail = detailParts.isEmpty ? null : detailParts.join('／');
  }

  // ---- T4 近況 ----
  String? postFact;
  final layoffDates = <String>[];
  final sortedPosts = _stableSorted(posts.toList(), (a, b) {
    final byTime = a.postedAt.compareTo(b.postedAt);
    if (byTime != 0) return byTime;
    return a.seq.compareTo(b.seq);
  });
  for (final p in sortedPosts) {
    if (!p.isLayoffPost) continue;
    final ymd = p.postedDate;
    if (!_inPeriod(ymd, fromYmd, raceYmd)) continue;
    if (!layoffDates.contains(ymd)) layoffDates.add(ymd);
  }
  if (layoffDates.isNotEmpty) {
    final shown = layoffDates
        .take(kConditionPostDatesMax)
        .map((ymd) => _shortDate(_dateOfYmd(ymd)!, raceDate))
        .join('・');
    final rest = layoffDates.length - kConditionPostDatesMax;
    postFact = '前走後に放牧の投稿あり（投稿日 $shown${rest > 0 ? '・ほか$rest件' : ''}）';
  }

  return TrainingRecordLines(
    countFact: countFact,
    countDetail: countDetail,
    gapFact: gapFact,
    evaluationFact: evaluationFact,
    evaluationDetail: evaluationDetail,
    netkeibaFact: netkeibaFact,
    netkeibaDetail: netkeibaDetail,
    postFact: postFact,
  );
}

/// 計算し直しの判定に使う、1頭分の指紋（設計書 4-1）。レース日より前の分だけを数える。
/// 「馬ID:pakaraの本数:pakaraの最新日:netkeibaの本数:脚色ありの本数:近況の件数」。
String trainingFingerprintOf({
  required String horseId,
  required DateTime raceDate,
  List<TrainingTimeModel> pakara = const [],
  List<NetkeibaTrainingSession> netkeibaSessions = const [],
  List<HorseConditionPost> posts = const [],
}) {
  final raceYmd = trainingYmdOf(raceDate);
  bool before(String ymd) =>
      RegExp(r'^\d{8}$').hasMatch(ymd) && ymd.compareTo(raceYmd) < 0;
  final pakaraBefore = pakara.where((t) => before(t.trainingDate)).toList();
  var latest = '';
  for (final t in pakaraBefore) {
    if (t.trainingDate.compareTo(latest) > 0) latest = t.trainingDate;
  }
  final sessionsBefore =
      netkeibaSessions.where((s) => before(s.trainingDate)).toList();
  final withLoad = sessionsBefore
      .where((s) => (s.trainingLoad?.trim() ?? '').isNotEmpty)
      .length;
  final postsBefore = posts.where((p) => before(p.postedDate)).length;
  return '$horseId:${pakaraBefore.length}:$latest:${sessionsBefore.length}:$withLoad:$postsBefore';
}
