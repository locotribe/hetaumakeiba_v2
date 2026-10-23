// lib/logic/pakara_backfill.dart

// [追加] 出走の意味 調教の行 Step3: pakara の調教を前走の日まで遡って取る手順。
// pakara は 1回に 1頭 1種別 10本まで・指定した日より前の分を返すので、最古の日の翌日を指定して取り直し、前走の日に届くまで繰り返す。
// 通信・保存・印は呼び出し側から受け取る関数で行う（ここは通信しない。テストでは差し替える） (v.2026.10.24+26102403)

import 'dart:convert';

import 'package:hetaumakeiba_v2/logic/previous_race.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

/// pakara が 1回の要求で 1頭 1種別について返す最大の本数
const int kPakaraPageSize = 10;

/// 1頭 1種別で、続きを取る要求の最大の回数（最初の要求は数えない）
const int kPakaraBackfillMaxRequests = 12;

/// pakara を前走の日まで取り終えた印の SharedPreferences のキー
String pakaraBackfillPrefKey(String horseId, String lastStartYmd) =>
    'pakara_backfill_${horseId}_$lastStartYmd';

/// 日付を YYYYMMDD の文字列にする。
String ymdOfDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

/// YYYYMMDD の翌日。8桁の数字でなければ null。
String? nextYmdOf(String ymd) {
  if (!RegExp(r'^\d{8}$').hasMatch(ymd)) return null;
  final date = DateTime.utc(
    int.parse(ymd.substring(0, 4)),
    int.parse(ymd.substring(4, 6)),
    int.parse(ymd.substring(6, 8)),
  ).add(const Duration(days: 1));
  return ymdOfDate(date);
}

/// 日付（YYYYMMDD）のうち一番古いもの。8桁の数字が1つも無ければ null。
String? oldestYmdOf(Iterable<String> dates) {
  String? oldest;
  for (final date in dates) {
    if (!RegExp(r'^\d{8}$').hasMatch(date)) continue;
    if (oldest == null || date.compareTo(oldest) < 0) oldest = date;
  }
  return oldest;
}

/// pakara の返事（JSON の文字列）を調教の行にする。読めない返事（配列でない・JSON でない）は null。
/// 時計が 0以下・500秒より大きい行は計測エラーとして null にする（今の TrainingDataService と同じ）。
List<TrainingTimeModel>? parsePakaraResponse(String body, String trackType) {
  final dynamic decoded;
  try {
    decoded = json.decode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! List) return null;
  final rows = <TrainingTimeModel>[];
  for (final horse in decoded) {
    if (horse is! Map) continue;
    final horseId = horse['name']?.toString() ?? '';
    if (horseId.isEmpty) continue;
    final cyoukyou = horse['cyoukyou'];
    if (cyoukyou is! List) continue;
    for (final c in cyoukyou) {
      if (c is! Map) continue;
      final location = c['kyuusya']?.toString() ?? '不明';
      rows.add(TrainingTimeModel(
        horseId: horseId,
        trainingDate: c['date']?.toString() ?? '',
        trainingTime: c['time']?.toString() ?? '',
        trackType: trackType,
        location: location,
        f6: _parsePakaraTime(c['f6']?.toString()),
        f5: _parsePakaraTime(c['f5']?.toString()),
        f4: _parsePakaraTime(c['f4']?.toString()),
        f3: _parsePakaraTime(c['f3']?.toString()),
        f2: _parsePakaraTime(c['f2']?.toString()),
        f1: _parsePakaraTime(c['f1']?.toString()),
        stableName: location,
      ));
    }
  }
  return rows;
}

double? _parsePakaraTime(String? text) {
  if (text == null || text.isEmpty) return null;
  final time = double.tryParse(text);
  if (time == null) return null;
  if (time <= 0.0 || time > 500.0) return null;
  return time;
}

/// 馬ごとの「前走の日（YYYYMMDD）」。基準の日より前に実際に出走した一番新しい走の日。
/// 前走が無い馬（過去走が無い・新馬）は含めない。
Map<String, String> pakaraBackfillTargets({
  required Map<String, List<HorseRaceRecord>> recordsByHorseId,
  required DateTime raceDay,
}) {
  final targets = <String, String>{};
  for (final entry in recordsByHorseId.entries) {
    final starts = startsBefore(entry.value, raceDay);
    if (starts.isEmpty) continue;
    targets[entry.key] = ymdOfDate(starts.first.date);
  }
  return targets;
}

/// 1頭 1種別について、続きを取るかの判定。
class PakaraBackfillDecision {
  /// 前走の日まで取り終えた（これ以上取らない）
  final bool complete;

  /// 続きを取るときの `date`（最古の日の翌日）。null なら続きを取らない
  final String? nextDate;

  const PakaraBackfillDecision({required this.complete, this.nextDate});

  /// 取り終えていないのに止める（回数の上限・進まない）
  bool get stoppedIncomplete => !complete && nextDate == null;
}

/// 直前の要求でその馬・その種別に返った行から、続きを取るかを決める。
///
/// - [returnedDates] 直前の要求でその馬に返った行の調教日（YYYYMMDD）
/// - [lastStartYmd] 前走の日
/// - [previousOldest] 1つ前の要求で返った行の最古日（最初の判定では null）
/// - [followUpRequests] ここまでに行った「続きの要求」の回数
///
/// 取り終えた: 返った行が 10本未満、または最古日が前走の日以前。
/// 止める（取り終えていない）: 最古日が前回と同じか新しい（進まない）、続きの要求が上限に達した、最古日が読めない。
PakaraBackfillDecision decidePakaraBackfill({
  required List<String> returnedDates,
  required String lastStartYmd,
  String? previousOldest,
  required int followUpRequests,
}) {
  if (returnedDates.length < kPakaraPageSize) {
    return const PakaraBackfillDecision(complete: true);
  }
  final oldest = oldestYmdOf(returnedDates);
  if (oldest == null) {
    return const PakaraBackfillDecision(complete: false);
  }
  if (oldest.compareTo(lastStartYmd) <= 0) {
    return const PakaraBackfillDecision(complete: true);
  }
  if (previousOldest != null && oldest.compareTo(previousOldest) >= 0) {
    return const PakaraBackfillDecision(complete: false);
  }
  if (followUpRequests >= kPakaraBackfillMaxRequests) {
    return const PakaraBackfillDecision(complete: false);
  }
  final next = nextYmdOf(oldest);
  if (next == null) {
    return const PakaraBackfillDecision(complete: false);
  }
  return PakaraBackfillDecision(complete: false, nextDate: next);
}

/// 遡りの結果（ログ用）。
class PakaraBackfillResult {
  /// 遡りの対象にした馬の数（印のある馬を除く）
  final int targetCount;

  /// 通信した回数
  final int requestCount;

  /// 保存した行数
  final int savedRows;

  /// 坂路・ウッドの両方で前走の日まで取り終えて、印を付けた馬の数
  final int completedHorses;

  const PakaraBackfillResult({
    required this.targetCount,
    required this.requestCount,
    required this.savedRows,
    required this.completedHorses,
  });
}

/// 全頭の pakara の調教を、前走の日まで遡って取る。
///
/// 手順（種別＝坂路・ウッドごとに）:
/// 1. `date`＝レース日・全頭まとめて1回。返った行を保存する。
/// 2. 馬ごとに、返った行が 10本で最古日が前走の日より後なら、`date`＝最古日の翌日・その馬だけで続きを取る。前走の日に届く・10本未満・進まない・上限のどれかで止める。
/// 両方の種別が「前走の日に届いた（または10本未満）」になった馬にだけ印を付ける。通信の失敗・上限・進まないで止まった馬には付けない（次の機会に取り直す）。
class PakaraBackfillRunner {
  /// 1ページ取る。失敗は null
  final Future<List<TrainingTimeModel>?> Function(
      String trackType, String date, List<String> horseIds) fetchPage;

  /// 取った行を保存する
  final Future<void> Function(List<TrainingTimeModel> rows) saveRows;

  /// 前走の日まで取り終えた印があるか
  final Future<bool> Function(String horseId, String lastStartYmd) isMarked;

  /// 印を付ける
  final Future<void> Function(String horseId, String lastStartYmd) mark;

  /// 要求と要求の間の待ち
  final Future<void> Function() waitInterval;

  const PakaraBackfillRunner({
    required this.fetchPage,
    required this.saveRows,
    required this.isMarked,
    required this.mark,
    required this.waitInterval,
  });

  static const List<String> trackTypes = ['坂路', 'ウッド'];

  /// [raceYmd] レース日（YYYYMMDD）。[lastStartByHorse] 馬ID → 前走の日（YYYYMMDD）
  Future<PakaraBackfillResult> run({
    required String raceYmd,
    required Map<String, String> lastStartByHorse,
  }) async {
    final targets = <String>[];
    for (final entry in lastStartByHorse.entries) {
      if (!await isMarked(entry.key, entry.value)) targets.add(entry.key);
    }
    if (targets.isEmpty) {
      return const PakaraBackfillResult(
          targetCount: 0, requestCount: 0, savedRows: 0, completedHorses: 0);
    }

    var requestCount = 0;
    var savedRows = 0;
    final completedTypes = {for (final id in targets) id: <String>{}};

    Future<List<TrainingTimeModel>?> request(
        String trackType, String date, List<String> ids) async {
      if (requestCount > 0) await waitInterval();
      requestCount++;
      return fetchPage(trackType, date, ids);
    }

    Future<List<TrainingTimeModel>> saveFor(
        List<TrainingTimeModel> rows, bool Function(String) wanted) async {
      final kept = rows.where((r) => wanted(r.horseId)).toList();
      if (kept.isNotEmpty) {
        await saveRows(kept);
        savedRows += kept.length;
      }
      return kept;
    }

    for (final trackType in trackTypes) {
      final first = await request(trackType, raceYmd, targets);
      if (first == null) continue;
      final firstRows = await saveFor(first, completedTypes.containsKey);
      final datesByHorse = <String, List<String>>{};
      for (final row in firstRows) {
        datesByHorse.putIfAbsent(row.horseId, () => []).add(row.trainingDate);
      }

      for (final horseId in targets) {
        final lastStart = lastStartByHorse[horseId]!;
        var dates = datesByHorse[horseId] ?? <String>[];
        String? previousOldest;
        var followUps = 0;
        while (true) {
          final decision = decidePakaraBackfill(
            returnedDates: dates,
            lastStartYmd: lastStart,
            previousOldest: previousOldest,
            followUpRequests: followUps,
          );
          if (decision.complete) {
            completedTypes[horseId]!.add(trackType);
            break;
          }
          final nextDate = decision.nextDate;
          if (nextDate == null) break;
          previousOldest = oldestYmdOf(dates);
          final page = await request(trackType, nextDate, [horseId]);
          followUps++;
          if (page == null) break;
          final rows = await saveFor(page, (id) => id == horseId);
          dates = rows.map((r) => r.trainingDate).toList();
        }
      }
    }

    var completedHorses = 0;
    for (final horseId in targets) {
      if (completedTypes[horseId]!.length == trackTypes.length) {
        await mark(horseId, lastStartByHorse[horseId]!);
        completedHorses++;
      }
    }
    return PakaraBackfillResult(
      targetCount: targets.length,
      requestCount: requestCount,
      savedRows: savedRows,
      completedHorses: completedHorses,
    );
  }
}
