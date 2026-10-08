// test/entry_meaning_snapshot_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning_snapshot.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';

HorseRaceRecord _r(String horseId, String date, String rank) {
  return HorseRaceRecord(
    horseId: horseId,
    raceId: '202605030511',
    date: date,
    venue: '3東京5',
    weather: '',
    raceNumber: '',
    raceName: '3歳以上1勝クラス',
    numberOfHorses: '',
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: '',
    rank: rank,
    jockey: '',
    jockeyId: '',
    carriedWeight: '',
    distance: '芝1600',
    trackCondition: '',
    time: '',
    margin: '',
    cornerPassage: '',
    pace: '',
    agari: '',
    horseWeight: '',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

PredictionHorseDetail _h(String horseId, int horseNumber,
    {bool isScratched = false}) {
  return PredictionHorseDetail(
    horseId: horseId,
    horseNumber: horseNumber,
    gateNumber: 1,
    horseName: '馬$horseNumber',
    sexAndAge: '牡4',
    jockey: '騎手',
    jockeyId: '',
    carriedWeight: 57.0,
    trainerName: '調教師$horseNumber',
    trainerAffiliation: '美浦',
    isScratched: isScratched,
  );
}

PredictionRaceData _race(
  List<PredictionHorseDetail> horses, {
  String raceId = '202605040811',
  String raceDate = '2026年10月4日',
}) {
  return PredictionRaceData(
    raceId: raceId,
    raceName: 'テスト特別',
    raceDate: raceDate,
    venue: '東京',
    raceNumber: '11',
    shutubaTableUrl: '',
    raceGrade: '',
    horses: horses,
    trackType: '芝',
    raceCategory: '3歳以上2勝クラス',
  );
}

RacePreparationStatus _status(PreparationStep step, PreparationState state) {
  return RacePreparationStatus(
    raceId: '202605040811',
    step: step,
    state: state,
    updatedAt: DateTime(2026, 10, 3, 12),
  );
}

const _lineA = EntryMeaningLine(
  kind: EntryMeaningKind.longLayoff,
  fact: '長期休養明け（7ヶ月・217日ぶり）',
  interpretation: '叩き台の可能性',
  basis: EntryMeaningBasis.general,
);

const _lineB = EntryMeaningLine(
  kind: EntryMeaningKind.sameStable,
  fact: '同じ厩舎（美浦・矢作）の2番馬2も出走',
  interpretation: null,
  basis: EntryMeaningBasis.fact,
);

const _lineR = EntryMeaningLine(
  kind: EntryMeaningKind.raceClassChallengeCount,
  fact: '格上挑戦が2頭',
  interpretation: null,
  basis: EntryMeaningBasis.rule,
);

void main() {
  test('組み立て: JRAの平地は出し、過去走の有無で行が決まる', () {
    final horses = [
      _h('2022100001', 1),
      _h('2022100002', 2),
      _h('2022100003', 3, isScratched: true),
    ];
    final result = buildEntryMeaningsForRace(
      race: _race(horses),
      recordsByHorseId: {
        '2022100001': [_r('2022100001', '2026/07/12', '5')],
      },
    );

    expect(result.isSupported, true);
    expect(result.horses.map((h) => h.horseId).toList(),
        ['2022100001', '2022100002', '2022100003']);

    // 1番: 前走から84日 → 休み明けの行がある
    final layoffLines = result.horses[0].lines
        .where((l) => l.kind == EntryMeaningKind.layoff)
        .toList();
    expect(layoffLines.length, 1);
    expect(layoffLines.first.fact.startsWith('休み明け（'), true);
    expect(layoffLines.first.fact.contains('84日ぶり'), true);

    // 2番: 過去走なし（未勝利戦ではない）→ 判定できないの1行だけ
    expect(result.horses[1].lines.length, 1);
    expect(result.horses[1].lines.first.kind, EntryMeaningKind.unjudged);

    // 3番: 取消 → 行なし
    expect(result.horses[2].isScratched, true);
    expect(result.horses[2].lines, isEmpty);

    // レース全体: 判定できない馬が1頭
    final unjudgedNotes = result.raceNotes
        .where((l) => l.kind == EntryMeaningKind.raceUnjudgedCount)
        .toList();
    expect(unjudgedNotes.length, 1);
    expect(unjudgedNotes.first.fact, '過去走を取得していないため判定できない馬が1頭');
  });

  test('組み立て: 地方のレース・開催日が読めないレースは出さない', () {
    final horses = [_h('2022100001', 1)];
    final records = {
      '2022100001': [_r('2022100001', '2026/07/12', '5')],
    };

    final local = buildEntryMeaningsForRace(
      race: _race(horses, raceId: '202645100811'),
      recordsByHorseId: records,
    );
    expect(local.isSupported, false);
    expect(local.horses, isEmpty);
    expect(local.raceNotes, isEmpty);

    final noDate = buildEntryMeaningsForRace(
      race: _race(horses, raceDate: ''),
      recordsByHorseId: records,
    );
    expect(noDate.isSupported, false);
  });

  test('過去走の取り直しの状態', () {
    expect(entryMeaningPreparationOf(), EntryMeaningPreparation.inProgress);
    expect(
      entryMeaningPreparationOf(
        horsePerformanceStatus:
            _status(PreparationStep.horsePerformance, PreparationState.running),
      ),
      EntryMeaningPreparation.inProgress,
    );
    expect(
      entryMeaningPreparationOf(
        horsePerformanceStatus:
            _status(PreparationStep.horsePerformance, PreparationState.done),
      ),
      EntryMeaningPreparation.done,
    );
    expect(
      entryMeaningPreparationOf(
        horsePerformanceStatus:
            _status(PreparationStep.horsePerformance, PreparationState.skipped),
      ),
      EntryMeaningPreparation.done,
    );
    expect(
      entryMeaningPreparationOf(
        horsePerformanceStatus:
            _status(PreparationStep.horsePerformance, PreparationState.failed),
      ),
      EntryMeaningPreparation.failed,
    );
    expect(
      entryMeaningPreparationOf(
        shutubaStatus: _status(PreparationStep.shutuba, PreparationState.failed),
        horsePerformanceStatus:
            _status(PreparationStep.horsePerformance, PreparationState.pending),
      ),
      EntryMeaningPreparation.failed,
    );
  });

  test('左端のラベル', () {
    expect(entryMeaningGroupLabel(EntryMeaningKind.unjudged), '');
    expect(entryMeaningGroupLabel(EntryMeaningKind.classPromotionFirstStart),
        'クラス');
    expect(entryMeaningGroupLabel(EntryMeaningKind.maidenStartCount), 'クラス');
    expect(entryMeaningGroupLabel(EntryMeaningKind.expedition), '遠征');
    expect(entryMeaningGroupLabel(EntryMeaningKind.tightInterval), '間隔');
    expect(entryMeaningGroupLabel(EntryMeaningKind.firstBlinker), '騎手');
    expect(entryMeaningGroupLabel(EntryMeaningKind.sameOwner), '同陣営');
    expect(entryMeaningGroupLabel(EntryMeaningKind.raceUnjudgedCount),
        'レース全体');
  });

  test('保存の形: JSON を通しても同じ内容に戻る', () {
    const meanings = RaceEntryMeanings(
      isSupported: true,
      raceNotes: [_lineR],
      horses: [
        HorseEntryMeaning(
          horseId: '2022100001',
          horseNumber: 1,
          horseName: '馬1',
          isScratched: false,
          lines: [_lineA, _lineB],
        ),
        HorseEntryMeaning(
          horseId: '2022100002',
          horseNumber: 2,
          horseName: '馬2',
          isScratched: true,
          lines: [],
        ),
      ],
    );

    final decoded = jsonDecode(jsonEncode(entryMeaningsToJson(meanings)))
        as Map<String, dynamic>;
    final restored = entryMeaningsFromJson(decoded);

    expect(restored.isSupported, true);
    expect(restored.raceNotes.length, 1);
    expect(restored.raceNotes.first.kind, EntryMeaningKind.raceClassChallengeCount);
    expect(restored.raceNotes.first.fact, '格上挑戦が2頭');
    expect(restored.raceNotes.first.interpretation, isNull);
    expect(restored.raceNotes.first.basis, EntryMeaningBasis.rule);

    expect(restored.horses.length, 2);
    final first = restored.horses[0];
    expect(first.horseId, '2022100001');
    expect(first.horseNumber, 1);
    expect(first.horseName, '馬1');
    expect(first.isScratched, false);
    expect(first.lines.map((l) => l.kind).toList(),
        [EntryMeaningKind.longLayoff, EntryMeaningKind.sameStable]);
    expect(first.lines[0].fact, '長期休養明け（7ヶ月・217日ぶり）');
    expect(first.lines[0].interpretation, '叩き台の可能性');
    expect(first.lines[0].basis, EntryMeaningBasis.general);
    expect(first.lines[1].interpretation, isNull);
    expect(first.lines[1].basis, EntryMeaningBasis.fact);

    expect(restored.horses[1].isScratched, true);
    expect(restored.horses[1].lines, isEmpty);
  });

  test('保存の形: 知らない種類の行は捨てる', () {
    final restored = entryMeaningsFromJson({
      'isSupported': true,
      'raceNotes': [
        {'kind': 'unknownKind', 'fact': 'x', 'interpretation': null, 'basis': 'fact'},
        {'kind': 'raceUnjudgedCount', 'fact': 'y', 'interpretation': null, 'basis': 'fact'},
      ],
      'horses': [],
    });
    expect(restored.raceNotes.length, 1);
    expect(restored.raceNotes.first.fact, 'y');
  });

  test('保存の1行: toMap と fromMap で同じ内容に戻る・壊れた行は null', () {
    final snapshot = EntryMeaningSnapshot(
      raceId: '202605040811',
      meanings: const RaceEntryMeanings(
        isSupported: true,
        raceNotes: [],
        horses: [
          HorseEntryMeaning(
            horseId: '2022100001',
            horseNumber: 1,
            horseName: '馬1',
            isScratched: false,
            lines: [_lineA],
          ),
        ],
      ),
      preparation: EntryMeaningPreparation.failed,
      computedAt: DateTime(2026, 10, 3, 21, 15),
    );

    final map = snapshot.toMap();
    expect(map['race_id'], '202605040811');
    expect(map['preparation_state'], 'failed');

    final restored = EntryMeaningSnapshot.fromMap(map);
    expect(restored, isNotNull);
    expect(restored!.raceId, '202605040811');
    expect(restored.preparation, EntryMeaningPreparation.failed);
    expect(restored.computedAt, DateTime(2026, 10, 3, 21, 15));
    expect(restored.horseOf('2022100001')!.lines.first.fact,
        '長期休養明け（7ヶ月・217日ぶり）');
    expect(restored.horseOf('9999999999'), isNull);

    expect(
      EntryMeaningSnapshot.fromMap({
        'race_id': '202605040811',
        'meanings_json': '{壊れた',
        'preparation_state': 'done',
        'computed_at': '2026-10-03T21:15:00.000',
      }),
      isNull,
    );
  });
}
