// lib/logic/past_record_status.dart

// [追加] 過去走の取得状況ポップアップ: 馬ごとの戦績の取得結果の保存形式・ログイン切れの判定・ポップアップに出す状況の組み立てを行う純粋なロジック。
// DB・通信・SharedPreferences には触れない (v.2026.11.5+26110501)

import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';

/// 競走馬ページから戦績を取得した結果の種類。
enum HorseFetchOutcomeKind {
  /// 戦績を1件以上取得できた。
  ok,

  /// ページは正常に取得できたが、戦績が0件だった（新馬戦など、初出走の馬）。
  noRecords,

  /// 通信エラー・HTTPエラーなどで取得できなかった。
  failed,
}

/// 1頭の戦績を最後に取得したときの結果。
class HorseFetchOutcome {
  final HorseFetchOutcomeKind kind;

  /// 取得した日時。
  final DateTime? at;

  /// タイム指数が伏せ字（**）のままだったか（ログイン切れの可能性）。
  final bool maskedIndexSuspected;

  const HorseFetchOutcome({
    required this.kind,
    this.at,
    this.maskedIndexSuspected = false,
  });

  /// SharedPreferences に保存する文字列にする。
  String encode() =>
      '${kind.name}|${at?.toIso8601String() ?? ''}|${maskedIndexSuspected ? 1 : 0}';

  /// [encode] の逆。読めない文字列は null を返す。
  static HorseFetchOutcome? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    HorseFetchOutcomeKind? kind;
    for (final k in HorseFetchOutcomeKind.values) {
      if (k.name == parts[0]) kind = k;
    }
    if (kind == null) return null;
    return HorseFetchOutcome(
      kind: kind,
      at: parts[1].isEmpty ? null : DateTime.tryParse(parts[1]),
      maskedIndexSuspected: parts[2] == '1',
    );
  }
}

/// netkeiba の競走馬ページのタイム指数の列が、ログイン切れで伏せ字になっているかを判定する。
///
/// [timeIndexTexts] は新しい走から順に並べたタイム指数の列の文字列。
/// 未ログインのときは最新走以外が「**」になるため、最新走を除いた走が2つ以上あり、
/// そのすべてに「**」が含まれるときだけ true にする（走が少ない馬や、
/// 本当に指数が無い走が混ざる場合に誤って判定しないため）。
bool isTimeIndexMasked(List<String> timeIndexTexts) {
  if (timeIndexTexts.length < 3) return false;
  final older = timeIndexTexts.sublist(1);
  return older.every((t) => t.contains('**'));
}

/// ポップアップに出す出走馬1頭分の情報。
class PastRecordHorse {
  final String horseId;
  final String horseName;
  final int horseNumber;

  const PastRecordHorse({
    required this.horseId,
    required this.horseName,
    required this.horseNumber,
  });

  /// 「3番 ○○」の形の表示名。馬番が分からないときは馬名だけ。
  String get label => horseNumber > 0 ? '$horseNumber番 $horseName' : horseName;
}

/// 全体の状況。上に行くほど深刻。
enum PastRecordsOverall {
  /// 取得に失敗したデータがある。
  failed,

  /// 欠けているデータがある。
  missing,

  /// ログイン切れの可能性がある（データそのものは揃っている）。
  loginSuspected,

  /// すべて揃っている。
  complete,
}

/// 過去走の取得状況（ポップアップの表示内容）。
class PastRecordsReport {
  /// 戦績を取得済みの馬（戦績が1件以上ある馬。取得失敗の馬は含まない）。
  final List<PastRecordHorse> fetchedHorses;

  /// 初出走で戦績が無い馬（正常）。
  final List<PastRecordHorse> debutHorses;

  /// 戦績をまだ取得していない馬。
  final List<PastRecordHorse> missingHorses;

  /// 戦績の取得に失敗した馬。
  final List<PastRecordHorse> failedHorses;

  /// 最後の取得でタイム指数が伏せ字だった馬（取得済みの馬のうち）。
  final List<PastRecordHorse> maskedHorses;

  /// 戦績に出てくるレースの数。
  final int pastRaceTotal;

  /// 結果を保存済みのレースの数（速報版を含む）。
  final int savedRaceCount;

  /// 結果が未保存で、まだ取得を試みていないレースのID。
  final List<String> unsavedRaceIds;

  /// 結果が未保存で、前回の取得に失敗したレースのID。
  final List<String> failedRaceIds;

  /// 保存済みだが速報版で、取り直す対象のレースのID。
  final List<String> provisionalRaceIds;

  /// netkeiba にログインしている記録があるか。
  final bool isLoggedIn;

  /// 出走馬の戦績ステップの状態と、その最終更新日時。
  final PreparationState performanceState;
  final DateTime? performanceUpdatedAt;

  /// 戦績内レース結果ステップの状態。
  final PreparationState pastResultsState;

  const PastRecordsReport({
    required this.fetchedHorses,
    required this.debutHorses,
    required this.missingHorses,
    required this.failedHorses,
    required this.maskedHorses,
    required this.pastRaceTotal,
    required this.savedRaceCount,
    required this.unsavedRaceIds,
    required this.failedRaceIds,
    required this.provisionalRaceIds,
    required this.isLoggedIn,
    required this.performanceState,
    required this.performanceUpdatedAt,
    required this.pastResultsState,
  });

  /// ログインしている記録があるのに伏せ字が混ざっている（ログイン切れの可能性）。
  bool get loginSuspected => isLoggedIn && maskedHorses.isNotEmpty;

  /// 取得処理の記録が「実行中」になっている。
  bool get hasRunningRecord =>
      performanceState == PreparationState.running ||
      pastResultsState == PreparationState.running;

  PastRecordsOverall get overall {
    if (failedHorses.isNotEmpty || failedRaceIds.isNotEmpty) {
      return PastRecordsOverall.failed;
    }
    if (missingHorses.isNotEmpty ||
        unsavedRaceIds.isNotEmpty ||
        provisionalRaceIds.isNotEmpty) {
      return PastRecordsOverall.missing;
    }
    if (loginSuspected) return PastRecordsOverall.loginSuspected;
    return PastRecordsOverall.complete;
  }
}

/// 馬ごとの戦績の件数・取得結果と、戦績内レース結果の保存状況から、ポップアップに出す状況を組み立てる。
///
/// - [recordCountByHorse]: 馬ID → DB にある戦績の件数
/// - [outcomeByHorse]: 馬ID → 最後に戦績を取得したときの結果（無ければ未記録）
/// - [pastRaceIds]: 戦績に出てくるレースのID
/// - [savedRaceIds]: そのうち結果を保存済みのレースのID
/// - [provisionalRaceIds]: 保存済みのうち速報版のレースのID
/// - [failedRaceIds]: 前回の取得に失敗したレースのID
PastRecordsReport buildPastRecordsReport({
  required List<PastRecordHorse> horses,
  required Map<String, int> recordCountByHorse,
  required Map<String, HorseFetchOutcome> outcomeByHorse,
  required Set<String> pastRaceIds,
  required Set<String> savedRaceIds,
  required Set<String> provisionalRaceIds,
  required Set<String> failedRaceIds,
  required bool isLoggedIn,
  required PreparationState performanceState,
  required DateTime? performanceUpdatedAt,
  required PreparationState pastResultsState,
}) {
  final fetched = <PastRecordHorse>[];
  final debut = <PastRecordHorse>[];
  final missing = <PastRecordHorse>[];
  final failed = <PastRecordHorse>[];
  final masked = <PastRecordHorse>[];

  for (final horse in horses) {
    final count = recordCountByHorse[horse.horseId] ?? 0;
    final outcome = outcomeByHorse[horse.horseId];
    if (outcome?.kind == HorseFetchOutcomeKind.failed) {
      failed.add(horse);
    } else if (count > 0) {
      fetched.add(horse);
      if (outcome != null && outcome.maskedIndexSuspected) {
        masked.add(horse);
      }
    } else if (outcome?.kind == HorseFetchOutcomeKind.noRecords) {
      debut.add(horse);
    } else {
      missing.add(horse);
    }
  }

  final unsaved = <String>[];
  final failedRaces = <String>[];
  for (final id in pastRaceIds) {
    if (savedRaceIds.contains(id)) continue;
    if (failedRaceIds.contains(id)) {
      failedRaces.add(id);
    } else {
      unsaved.add(id);
    }
  }
  final provisional = provisionalRaceIds
      .where((id) => pastRaceIds.contains(id) && savedRaceIds.contains(id))
      .toList();

  return PastRecordsReport(
    fetchedHorses: fetched,
    debutHorses: debut,
    missingHorses: missing,
    failedHorses: failed,
    maskedHorses: masked,
    pastRaceTotal: pastRaceIds.length,
    savedRaceCount: pastRaceIds.where(savedRaceIds.contains).length,
    unsavedRaceIds: unsaved,
    failedRaceIds: failedRaces,
    provisionalRaceIds: provisional,
    isLoggedIn: isLoggedIn,
    performanceState: performanceState,
    performanceUpdatedAt: performanceUpdatedAt,
    pastResultsState: pastResultsState,
  );
}
