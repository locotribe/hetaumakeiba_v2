// lib/logic/entry_meaning_snapshot.dart

// [追加] 陣営の本気度指数 実施順6: 出馬表・過去走・プロフィールから「出走の意味」をまとめて出す組み立て関数と、
// 計算結果の保存の形（JSON）・過去走の取り直しの状態・表示用のラベル。DB・画面・通信には触れない (v.2026.10.3+26100306)

import 'dart:convert';

import 'package:hetaumakeiba_v2/logic/camp_signals.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning.dart';
import 'package:hetaumakeiba_v2/logic/horse_circumstance.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
// [追加] 出走の意味 条件と騎手成績 Step2: 過去走のレースの全着順を受け取る (v.2026.10.20+26102002)
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

/// 出馬表（取消を含む）・過去走・プロフィールから、出走の意味をまとめて出す。
///
/// classifyRace → buildRaceCircumstances → buildCampSignals → buildEntryMeanings の順に呼ぶだけ。
/// JRAの平地で開催日が読めないレースは isSupported=false になる。
// [修正] 基本情報整理と本賞金照合 Step3: 重賞の本賞金の表（レースID → [1着, 2着]・万円）を任意で受け取り、事情の組み立てへ渡す (v.2026.10.15+26101506)
RaceEntryMeanings buildEntryMeaningsForRace({
  required PredictionRaceData race,
  required Map<String, List<HorseRaceRecord>> recordsByHorseId,
  Map<String, HorseProfile> profilesByHorseId = const {},
  Map<String, List<int>> basePrizeManByRaceId = const {},
  // [追加] 出走の意味 条件と騎手成績 Step2: 過去走のレースの全着順（レースID → 結果）。3着圏・掲示板圏と内外に使う (v.2026.10.20+26102002)
  Map<String, RaceResult> raceResultsById = const {},
  // [追加] 出走の意味 調教の行 Step2: 馬ID → 調教・近況のデータ (v.2026.10.24+26102402)
  Map<String, HorseTrainingInput> trainingByHorseId = const {},
}) {
  final classification = classifyRace(race);
  final circumstances = buildRaceCircumstances(
    race: classification,
    horses: race.horses,
    recordsByHorseId: recordsByHorseId,
    basePrizeManByRaceId: basePrizeManByRaceId,
  );
  final raceDate = classification.date;
  final List<HorseCampSignals> campSignals;
  if (circumstances.isSupported && raceDate != null) {
    campSignals = buildCampSignals(
      raceDate: raceDate,
      horses: race.horses,
      recordsByHorseId: recordsByHorseId,
      isMaidenOrNewcomerRace:
          classification.classLevel == RaceClassLevel.newcomer ||
              classification.classLevel == RaceClassLevel.maiden,
    );
  } else {
    campSignals = const <HorseCampSignals>[];
  }
  // [修正] 出走の意味 条件と騎手成績 Step2: 条件の行のため、過去走・全着順と今回の芝ダ・距離・内外（courseInOut に「外」）も渡す (v.2026.10.20+26102002)
  final trackType = race.trackType;
  return buildEntryMeanings(
    circumstances: circumstances,
    campSignals: campSignals,
    horses: race.horses,
    profilesByHorseId: profilesByHorseId,
    recordsByHorseId: recordsByHorseId,
    raceResultsById: raceResultsById,
    conditionTrackType:
        (trackType == '芝' || trackType == 'ダ') ? trackType : null,
    conditionDistance: race.distanceValue ?? 0,
    conditionIsOuterCourse: (race.courseInOut ?? '').contains('外'),
    trainingByHorseId: trainingByHorseId,
  );
}

/// 計算したときの過去走の取り直し（レース準備の「出走馬の戦績」ステップ）の状態。
enum EntryMeaningPreparation {
  /// 取り直しが終わっていた（または対象外）
  done,

  /// 取り直しの途中（まだ記録が無いときも含む）
  inProgress,

  /// 取り直しが失敗していた（出馬表ステップの失敗を含む）
  failed,
}

/// レース準備の記録から、過去走の取り直しの状態を決める。
///
/// 出走馬の戦績が完了・対象外 → done。出走馬の戦績か出馬表が失敗 → failed。それ以外 → inProgress。
EntryMeaningPreparation entryMeaningPreparationOf({
  RacePreparationStatus? shutubaStatus,
  RacePreparationStatus? horsePerformanceStatus,
}) {
  final hpState = horsePerformanceStatus?.state;
  if (hpState == PreparationState.done || hpState == PreparationState.skipped) {
    return EntryMeaningPreparation.done;
  }
  if (hpState == PreparationState.failed ||
      shutubaStatus?.state == PreparationState.failed) {
    return EntryMeaningPreparation.failed;
  }
  return EntryMeaningPreparation.inProgress;
}

/// 行の左端に出すラベル（クラス／遠征／間隔／騎手／同陣営／レース全体）。判定できない行は空。
String entryMeaningGroupLabel(EntryMeaningKind kind) {
  switch (kind) {
    case EntryMeaningKind.unjudged:
      return '';
    case EntryMeaningKind.classPromotionFirstStart:
    case EntryMeaningKind.classStay:
    case EntryMeaningKind.classChallenge:
    case EntryMeaningKind.gradedSecondPromotion:
    case EntryMeaningKind.prizeRank:
    case EntryMeaningKind.classNeedsCheck:
    case EntryMeaningKind.maidenDeadline:
    case EntryMeaningKind.maidenStartCount:
      return 'クラス';
    case EntryMeaningKind.expedition:
      return '遠征';
    case EntryMeaningKind.longLayoff:
    case EntryMeaningKind.longishLayoff:
    case EntryMeaningKind.layoff:
    case EntryMeaningKind.startsAfterLayoff:
    case EntryMeaningKind.tightInterval:
      return '間隔';
    // [追加] 出走の意味 条件と騎手成績 Step2: 条件の行 (v.2026.10.20+26102002)
    case EntryMeaningKind.previousRaceComparison:
    case EntryMeaningKind.distanceRecord:
    case EntryMeaningKind.courseRecord:
      return '条件';
    // [追加] 出走の意味 調教の行 Step2: 調教・近況の行 (v.2026.10.24+26102402)
    case EntryMeaningKind.trainingCount:
    case EntryMeaningKind.trainingGap:
    case EntryMeaningKind.trainingEvaluation:
    case EntryMeaningKind.netkeibaTraining:
    case EntryMeaningKind.trainingScope:
      return '調教';
    case EntryMeaningKind.conditionPost:
      return '近況';
    case EntryMeaningKind.previousJockeyOnOtherHorse:
    case EntryMeaningKind.jockeyChange:
    case EntryMeaningKind.mainJockey:
    case EntryMeaningKind.firstBlinker:
      return '騎手';
    case EntryMeaningKind.sameOwner:
    case EntryMeaningKind.sameStable:
      return '同陣営';
    case EntryMeaningKind.raceClassChallengeCount:
    case EntryMeaningKind.raceUnjudgedCount:
      return 'レース全体';
  }
}

// [追加] 馬詳細タブ 表示項目変更 Step4: 馬名の下に出すバッジ1つ。group は色分けに使う左端のラベル（entryMeaningGroupLabel） (v.2026.10.15+26101503)
class EntryMeaningBadge {
  final String label;
  final String group;

  const EntryMeaningBadge({required this.label, required this.group});
}

// [追加] 馬詳細タブ 表示項目変更 Step4: 出走の意味の1行からバッジの文字を決める。バッジにしない種類は null。
// 文ではなく種類で決めるので、保存分（レース結果後）にも付く。数字は保存した文から取り出し、取れなければ数字なしの文字にする (v.2026.10.15+26101503)
String? entryMeaningBadgeLabel(EntryMeaningLine line) {
  switch (line.kind) {
    case EntryMeaningKind.classPromotionFirstStart:
      return '昇級初戦';
    case EntryMeaningKind.classChallenge:
      return '格上挑戦';
    case EntryMeaningKind.maidenDeadline:
      return '未勝利期限';
    case EntryMeaningKind.expedition:
      return '遠征';
    case EntryMeaningKind.longLayoff:
      return '長休明け';
    case EntryMeaningKind.longishLayoff:
    case EntryMeaningKind.layoff:
      return '休み明け';
    case EntryMeaningKind.startsAfterLayoff:
      {
        final count = RegExp(r'休み明けから(\d+)戦目').firstMatch(line.fact);
        return count == null ? '叩き' : '叩き${count.group(1)}戦目';
      }
    case EntryMeaningKind.tightInterval:
      {
        final interval = RegExp(r'（([^・）]+)').firstMatch(line.fact);
        final text = interval?.group(1)?.trim() ?? '';
        return (text.isEmpty || text == '--') ? '間隔詰め' : text;
      }
    case EntryMeaningKind.jockeyChange:
      return '乗替';
    // [追加] 出走の意味 条件と騎手成績 Step2: 条件のバッジ（同距離は付けない・実績なしは「距離初」「コース初」） (v.2026.10.20+26102002)
    case EntryMeaningKind.previousRaceComparison:
      {
        final fact = line.fact;
        if (fact.contains('障害から平地')) return '平地替わり';
        if (fact.contains('ダートから芝')) return '芝替わり';
        if (fact.contains('芝からダート')) return 'ダ替わり';
        final change = RegExp(r'(\d+m(?:延長|短縮))').firstMatch(fact);
        return change?.group(1);
      }
    case EntryMeaningKind.distanceRecord:
      return line.fact.endsWith('実績なし') ? '距離初' : null;
    case EntryMeaningKind.courseRecord:
      return line.fact.endsWith('実績なし') ? 'コース初' : null;
    case EntryMeaningKind.sameOwner:
      return '同馬主';
    case EntryMeaningKind.sameStable:
      return '同厩舎';
    case EntryMeaningKind.unjudged:
    case EntryMeaningKind.classStay:
    case EntryMeaningKind.gradedSecondPromotion:
    case EntryMeaningKind.prizeRank:
    case EntryMeaningKind.classNeedsCheck:
    case EntryMeaningKind.maidenStartCount:
    case EntryMeaningKind.previousJockeyOnOtherHorse:
    case EntryMeaningKind.mainJockey:
    case EntryMeaningKind.firstBlinker:
    case EntryMeaningKind.raceClassChallengeCount:
    case EntryMeaningKind.raceUnjudgedCount:
    // [追加] 出走の意味 調教の行 Step2: 調教・近況の行はバッジにしない (v.2026.10.24+26102402)
    case EntryMeaningKind.trainingCount:
    case EntryMeaningKind.trainingGap:
    case EntryMeaningKind.trainingEvaluation:
    case EntryMeaningKind.netkeibaTraining:
    case EntryMeaningKind.trainingScope:
    case EntryMeaningKind.conditionPost:
      return null;
  }
}

// [追加] 馬詳細タブ 表示項目変更 Step4: その馬のバッジの列（行の順。同じ文字は1つにまとめる）。計算前・取消・該当なしは空 (v.2026.10.15+26101503)
List<EntryMeaningBadge> entryMeaningBadgesOf(HorseEntryMeaning? meaning) {
  if (meaning == null || meaning.isScratched) return const <EntryMeaningBadge>[];
  final seen = <String>{};
  final badges = <EntryMeaningBadge>[];
  for (final line in meaning.lines) {
    final label = entryMeaningBadgeLabel(line);
    if (label == null || !seen.add(label)) continue;
    badges.add(EntryMeaningBadge(
        label: label, group: entryMeaningGroupLabel(line.kind)));
  }
  return badges;
}

/// 名前から列挙の値を探す。見つからなければ null。
T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// 1行を保存用の形にする。
Map<String, dynamic> entryMeaningLineToJson(EntryMeaningLine line) {
  return {
    'kind': line.kind.name,
    'fact': line.fact,
    'interpretation': line.interpretation,
    'basis': line.basis.name,
    // [追加] 出走の意味 条件と騎手成績 Step2: 補足は有るときだけ保存する (v.2026.10.20+26102002)
    if (line.detail != null) 'detail': line.detail,
  };
}

/// 保存した1行を読む。種類・根拠の印・事実が読めなければ null（その行は捨てる）。
EntryMeaningLine? entryMeaningLineFromJson(Map<String, dynamic> json) {
  final kind = _enumByName(EntryMeaningKind.values, json['kind']);
  final basis = _enumByName(EntryMeaningBasis.values, json['basis']);
  final fact = json['fact'];
  if (kind == null || basis == null || fact is! String) return null;
  final interpretation = json['interpretation'];
  // [追加] 出走の意味 条件と騎手成績 Step2: 補足（古い保存には無い） (v.2026.10.20+26102002)
  final detail = json['detail'];
  return EntryMeaningLine(
    kind: kind,
    fact: fact,
    interpretation: interpretation is String ? interpretation : null,
    basis: basis,
    detail: detail is String ? detail : null,
  );
}

/// レース全体の出走の意味を保存用の形にする。
Map<String, dynamic> entryMeaningsToJson(RaceEntryMeanings meanings) {
  return {
    'isSupported': meanings.isSupported,
    'raceNotes': meanings.raceNotes.map(entryMeaningLineToJson).toList(),
    'horses': meanings.horses
        .map((h) => {
              'horseId': h.horseId,
              'horseNumber': h.horseNumber,
              'horseName': h.horseName,
              'isScratched': h.isScratched,
              'lines': h.lines.map(entryMeaningLineToJson).toList(),
            })
        .toList(),
  };
}

/// 保存したレース全体の出走の意味を読む。読めない項目は空・0・false にする。
RaceEntryMeanings entryMeaningsFromJson(Map<String, dynamic> json) {
  List<EntryMeaningLine> readLines(Object? raw) {
    final result = <EntryMeaningLine>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final line =
              entryMeaningLineFromJson(Map<String, dynamic>.from(item));
          if (line != null) result.add(line);
        }
      }
    }
    return result;
  }

  final horses = <HorseEntryMeaning>[];
  final rawHorses = json['horses'];
  if (rawHorses is List) {
    for (final item in rawHorses) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final horseId = map['horseId'];
      final horseNumber = map['horseNumber'];
      final horseName = map['horseName'];
      horses.add(HorseEntryMeaning(
        horseId: horseId is String ? horseId : '',
        horseNumber: horseNumber is int ? horseNumber : 0,
        horseName: horseName is String ? horseName : '',
        isScratched: map['isScratched'] == true,
        lines: readLines(map['lines']),
      ));
    }
  }

  return RaceEntryMeanings(
    isSupported: json['isSupported'] == true,
    raceNotes: readLines(json['raceNotes']),
    horses: horses,
  );
}

/// 保存する計算結果（レースごとに1件）。
class EntryMeaningSnapshot {
  final String raceId;
  final RaceEntryMeanings meanings;

  /// 計算したときの過去走の取り直しの状態
  final EntryMeaningPreparation preparation;

  /// 計算した日時
  final DateTime computedAt;

  // [追加] 出走の意味 調教の行 Step2: 計算したときの調教・近況の指紋（trainingFingerprintOf を馬の順につないだ文字列）。古い保存には無い (v.2026.10.24+26102402)
  final String? trainingFingerprint;

  const EntryMeaningSnapshot({
    required this.raceId,
    required this.meanings,
    required this.preparation,
    required this.computedAt,
    this.trainingFingerprint,
  });

  /// その馬の出走の意味。無ければ null。
  HorseEntryMeaning? horseOf(String horseId) {
    for (final horse in meanings.horses) {
      if (horse.horseId == horseId) return horse;
    }
    return null;
  }

  /// entry_meaning_cache テーブルの1行にする。
  Map<String, Object?> toMap() {
    return {
      'race_id': raceId,
      // [修正] 出走の意味 調教の行 Step2: 指紋は同じ JSON の一番上の項目に入れる（表の列は足さない） (v.2026.10.24+26102402)
      'meanings_json': jsonEncode({
        ...entryMeaningsToJson(meanings),
        if (trainingFingerprint != null)
          'trainingFingerprint': trainingFingerprint,
      }),
      'preparation_state': preparation.name,
      'computed_at': computedAt.toIso8601String(),
    };
  }

  /// entry_meaning_cache テーブルの1行を読む。読めなければ null。
  static EntryMeaningSnapshot? fromMap(Map<String, Object?> map) {
    final raceId = map['race_id'];
    final meaningsJson = map['meanings_json'];
    final computedAtText = map['computed_at'];
    if (raceId is! String || meaningsJson is! String || computedAtText is! String) {
      return null;
    }
    final computedAt = DateTime.tryParse(computedAtText);
    if (computedAt == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(meaningsJson);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map) return null;
    // [追加] 出走の意味 調教の行 Step2: 古い保存には指紋が無い (v.2026.10.24+26102402)
    final fingerprint = decoded['trainingFingerprint'];
    return EntryMeaningSnapshot(
      raceId: raceId,
      meanings: entryMeaningsFromJson(Map<String, dynamic>.from(decoded)),
      trainingFingerprint: fingerprint is String ? fingerprint : null,
      preparation: _enumByName(
              EntryMeaningPreparation.values, map['preparation_state']) ??
          EntryMeaningPreparation.inProgress,
      computedAt: computedAt,
    );
  }
}
