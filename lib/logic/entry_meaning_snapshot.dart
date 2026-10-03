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

/// 出馬表（取消を含む）・過去走・プロフィールから、出走の意味をまとめて出す。
///
/// classifyRace → buildRaceCircumstances → buildCampSignals → buildEntryMeanings の順に呼ぶだけ。
/// JRAの平地で開催日が読めないレースは isSupported=false になる。
RaceEntryMeanings buildEntryMeaningsForRace({
  required PredictionRaceData race,
  required Map<String, List<HorseRaceRecord>> recordsByHorseId,
  Map<String, HorseProfile> profilesByHorseId = const {},
}) {
  final classification = classifyRace(race);
  final circumstances = buildRaceCircumstances(
    race: classification,
    horses: race.horses,
    recordsByHorseId: recordsByHorseId,
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
  return buildEntryMeanings(
    circumstances: circumstances,
    campSignals: campSignals,
    horses: race.horses,
    profilesByHorseId: profilesByHorseId,
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
  };
}

/// 保存した1行を読む。種類・根拠の印・事実が読めなければ null（その行は捨てる）。
EntryMeaningLine? entryMeaningLineFromJson(Map<String, dynamic> json) {
  final kind = _enumByName(EntryMeaningKind.values, json['kind']);
  final basis = _enumByName(EntryMeaningBasis.values, json['basis']);
  final fact = json['fact'];
  if (kind == null || basis == null || fact is! String) return null;
  final interpretation = json['interpretation'];
  return EntryMeaningLine(
    kind: kind,
    fact: fact,
    interpretation: interpretation is String ? interpretation : null,
    basis: basis,
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

  const EntryMeaningSnapshot({
    required this.raceId,
    required this.meanings,
    required this.preparation,
    required this.computedAt,
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
      'meanings_json': jsonEncode(entryMeaningsToJson(meanings)),
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
    return EntryMeaningSnapshot(
      raceId: raceId,
      meanings: entryMeaningsFromJson(Map<String, dynamic>.from(decoded)),
      preparation: _enumByName(
              EntryMeaningPreparation.values, map['preparation_state']) ??
          EntryMeaningPreparation.inProgress,
      computedAt: computedAt,
    );
  }
}
