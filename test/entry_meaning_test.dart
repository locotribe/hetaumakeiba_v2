// test/entry_meaning_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/camp_signals.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning.dart';
import 'package:hetaumakeiba_v2/logic/horse_circumstance.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/logic/trainer_affiliation.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

final DateTime _raceDay = DateTime(2026, 10, 4);

RaceClassification _race(
  String raceCategory, {
  String raceGrade = '',
  String raceId = '202605040811',
  String raceDate = '2026年10月4日',
}) {
  return classifyRaceFromParts(
    raceId: raceId,
    raceDate: raceDate,
    raceCategory: raceCategory,
    raceGrade: raceGrade,
    trackType: '芝',
  );
}

EarnedPrizeResult _prize({List<EarnedPrizeEntry> entries = const []}) {
  return EarnedPrizeResult(
    asOf: _raceDay,
    ageGroupAtAsOf: EarnedPrizeAgeGroup.threeUp,
    entries: entries,
    decisionPeriod1Start: DateTime(2025, 10, 6),
    decisionPeriod2Start: DateTime(2024, 10, 7),
  );
}

HorseCircumstance _c(
  String horseId,
  int horseNumber, {
  bool isScratched = false,
  bool canJudge = true,
  EarnedPrizeResult? prize,
  EarnedPrizeClass? horseClass = EarnedPrizeClass.win2,
  int? classGap = 0,
  DateTime? classReachedDate,
  int? startsSinceClassReached = 2,
  bool promotedByGradedSecond = false,
  int? rankingPrizeInThousandYen = 9000,
  int? prizeRank,
  TrainerAffiliation affiliation = TrainerAffiliation.miho,
  ExpeditionStatus expedition = ExpeditionStatus.home,
  bool isMaidenDeadline = false,
}) {
  return HorseCircumstance(
    horseId: horseId,
    horseNumber: horseNumber,
    horseName: '馬$horseNumber',
    isScratched: isScratched,
    canJudge: canJudge,
    prize: canJudge ? (prize ?? _prize()) : null,
    horseClass: canJudge ? horseClass : null,
    classGap: canJudge ? classGap : null,
    isClassChallenge: classGap != null && classGap > 0,
    needsCheck: classGap != null && classGap < 0,
    classReachedDate: classReachedDate,
    startsSinceClassReached: canJudge ? startsSinceClassReached : null,
    promotedByGradedSecond: promotedByGradedSecond,
    rankingPrizeInThousandYen: canJudge ? rankingPrizeInThousandYen : null,
    prizeRank: prizeRank,
    affiliation: affiliation,
    expedition: expedition,
    isMaidenDeadline: isMaidenDeadline,
  );
}

RaceCircumstances _rc(
  RaceClassification race,
  List<HorseCircumstance> horses, {
  int rankedCount = 0,
}) {
  return RaceCircumstances(
    race: race,
    isSupported: true,
    horses: horses,
    rankedCount: rankedCount,
    unjudgedCount: horses.where((h) => !h.isScratched && !h.canJudge).length,
    classChallengeCount:
        horses.where((h) => !h.isScratched && h.isClassChallenge).length,
  );
}

HorseCampSignals _s(
  String horseId,
  int horseNumber, {
  DateTime? lastStartDate,
  RestCategory? restCategory,
  int startNumberSinceLayoff = 2,
  bool isCountedFromLayoff = true,
  bool isFirstBlinker = false,
  String? previousJockeyName,
  bool? isJockeyChanged = false,
  int ridesOnThisHorse = 1,
  bool isMainJockey = false,
  // [修正] 馬番ではなく馬ID (v.2026.10.6+26100601)
  String? previousJockeyRidingHorseId,
}) {
  final days = lastStartDate == null ? null : daysBetween(_raceDay, lastStartDate);
  return HorseCampSignals(
    horseId: horseId,
    horseNumber: horseNumber,
    canJudge: true,
    lastStartDate: lastStartDate,
    daysSinceLastStart: days,
    restCategory: restCategory ?? restCategoryOf(days),
    startNumberSinceLayoff: startNumberSinceLayoff,
    isCountedFromLayoff: isCountedFromLayoff,
    isOverworked: false,
    isFirstBlinker: isFirstBlinker,
    bodyWeightChange: null,
    previousJockeyId: null,
    previousJockeyName: previousJockeyName,
    isJockeyChanged: isJockeyChanged,
    ridesOnThisHorse: ridesOnThisHorse,
    isMainJockey: isMainJockey,
    previousJockeyRidingHorseId: previousJockeyRidingHorseId,
  );
}

PredictionHorseDetail _h(
  String horseId,
  int horseNumber, {
  String jockey = '騎手',
  String? trainerName,
  String trainerAffiliation = '美浦',
  bool isScratched = false,
}) {
  return PredictionHorseDetail(
    horseId: horseId,
    horseNumber: horseNumber,
    gateNumber: 1,
    horseName: '馬$horseNumber',
    sexAndAge: '牡4',
    jockey: jockey,
    jockeyId: '',
    carriedWeight: 57.0,
    trainerName: trainerName ?? '調教師$horseNumber',
    trainerAffiliation: trainerAffiliation,
    isScratched: isScratched,
  );
}

HorseProfile _profile(String horseId, String ownerId, String ownerName) {
  return HorseProfile(
    horseId: horseId,
    horseName: '',
    gender: '',
    birthday: '',
    ownerId: ownerId,
    ownerName: ownerName,
    ownerImageLocalPath: '',
    trainerId: '',
    trainerName: '',
    breederName: '',
    fatherId: '',
    fatherName: '',
    motherId: '',
    motherName: '',
    ffName: '',
    fmName: '',
    mfName: '',
    mmName: '',
    lastUpdated: '',
  );
}

List<String> _facts(HorseEntryMeaning h) => h.lines.map((l) => l.fact).toList();

List<EntryMeaningKind> _kinds(HorseEntryMeaning h) =>
    h.lines.map((l) => l.kind).toList();

void main() {
  test('賞金の額の書き方', () {
    expect(formatManYen(45500), '4,550万円');
    expect(formatManYen(45505), '4,550.5万円');
    expect(formatManYen(4000), '400万円');
    expect(formatManYen(1234567), '123,456.7万円');
    expect(formatManYen(0), '0万円');
  });

  test('根拠の印の表示名', () {
    expect(entryMeaningBasisLabel(EntryMeaningBasis.rule), '規則');
    expect(entryMeaningBasisLabel(EntryMeaningBasis.general), '一般論');
    expect(entryMeaningBasisLabel(EntryMeaningBasis.fact), '事実');
    expect(entryMeaningBasisLabel(EntryMeaningBasis.ruleLimit), '規則の限界');
  });

  test('対象外のレース（JRAの平地で日付が読めない）は何も出さない', () {
    final race = _race('3歳以上2勝クラス', raceId: '202645040811');
    final result = buildEntryMeanings(
      circumstances: RaceCircumstances(
        race: race,
        isSupported: false,
        horses: const [],
        rankedCount: 0,
        unjudgedCount: 0,
        classChallengeCount: 0,
      ),
      campSignals: const [],
      horses: [_h('2022100001', 1)],
    );
    expect(result.isSupported, isFalse);
    expect(result.raceNotes, isEmpty);
    expect(result.horses, isEmpty);
  });

  test('取消は出さない・判定できない馬は1行だけ・レース全体の注記', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 1, isScratched: true),
        _c('2022100002', 2, canJudge: false),
        _c('2022100003', 3),
      ]),
      campSignals: [
        _s('2022100002', 2, isFirstBlinker: true),
      ],
      horses: [
        _h('2022100001', 1, isScratched: true),
        _h('2022100002', 2),
        _h('2022100003', 3),
      ],
    );
    expect(result.isSupported, isTrue);
    expect(result.horses.map((h) => h.horseNumber).toList(), [1, 2, 3]);
    expect(result.horses[0].isScratched, isTrue);
    expect(result.horses[0].lines, isEmpty);
    expect(_facts(result.horses[1]), ['過去走を取得していないため判定できません']);
    expect(result.horses[1].lines.single.basis, EntryMeaningBasis.fact);
    expect(result.horses[2].lines, isEmpty);
    expect(result.raceNotes.map((l) => l.fact).toList(),
        ['過去走を取得していないため判定できない馬が1頭']);
    expect(result.raceNotes.single.kind, EntryMeaningKind.raceUnjudgedCount);
  });

  test('昇級初戦・重賞2着の加算・同じクラスで7走目（6走未満は出さない）', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 1,
            classReachedDate: DateTime(2026, 8, 16),
            startsSinceClassReached: 0,
            promotedByGradedSecond: true),
        _c('2022100002', 2, startsSinceClassReached: 6),
        _c('2022100003', 3, startsSinceClassReached: 5),
      ]),
      campSignals: const [],
      horses: [
        _h('2022100001', 1),
        _h('2022100002', 2),
        _h('2022100003', 3),
      ],
    );
    final first = result.horses[0];
    expect(_facts(first), [
      '昇級初戦（2勝クラスに上がって初めての出走）',
      '重賞2着の賞金加算でクラスが上がった（2026/8/16）',
    ]);
    expect(first.lines[0].interpretation, '新しいクラスでの力試しの可能性');
    expect(first.lines[0].basis, EntryMeaningBasis.rule);
    expect(_facts(result.horses[1]), ['2勝クラスで今回7走目']);
    expect(result.horses[1].lines.single.interpretation, isNull);
    expect(result.horses[2].lines, isEmpty);
  });

  test('格上挑戦は各馬に出す（2歳戦・3歳限定のオープン以外）', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 1,
            horseClass: EarnedPrizeClass.win1,
            classGap: 1,
            startsSinceClassReached: 0,
            classReachedDate: DateTime(2026, 9, 1)),
        _c('2022100002', 2,
            horseClass: EarnedPrizeClass.win3, classGap: -1),
      ]),
      campSignals: const [],
      horses: [_h('2022100001', 1), _h('2022100002', 2)],
    );
    expect(_facts(result.horses[0]), ['格上挑戦（収得賞金では1勝クラス・今回は2勝クラス）']);
    expect(result.horses[0].lines.single.interpretation,
        '自分のクラスに合う番組が無い・除外を避けた・力試しのどれかの可能性');
    expect(_facts(result.horses[1]), ['収得賞金のクラス（3勝クラス）が今回のレース（2勝クラス）より上']);
    expect(result.horses[1].lines.single.basis, EntryMeaningBasis.ruleLimit);
    expect(result.raceNotes.single.fact, '格上挑戦が1頭');
    expect(result.raceNotes.single.interpretation, isNull);
  });

  test('2歳戦・3歳限定のオープンは格上挑戦をレース全体の注記だけにする', () {
    expect(isClassChallengeCommonRace(_race('2歳1勝クラス')), isTrue);
    expect(isClassChallengeCommonRace(_race('3歳オープン', raceGrade: 'G2')), isTrue);
    expect(isClassChallengeCommonRace(_race('3歳1勝クラス')), isFalse);
    expect(isClassChallengeCommonRace(_race('3歳以上オープン', raceGrade: 'G2')),
        isFalse);

    final race = _race('3歳オープン', raceGrade: 'G2', raceDate: '2026年9月20日');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2023100001', 1,
            horseClass: EarnedPrizeClass.win1, classGap: 3),
        _c('2023100002', 2,
            horseClass: EarnedPrizeClass.win2, classGap: 2),
      ]),
      campSignals: const [],
      horses: [_h('2023100001', 1), _h('2023100002', 2)],
    );
    expect(result.horses[0].lines, isEmpty);
    expect(result.horses[1].lines, isEmpty);
    expect(result.raceNotes.single.fact, '格上挑戦が2頭');
    expect(result.raceNotes.single.interpretation,
        '2歳戦・3歳限定のオープンは多くの馬が格上挑戦になるため、各馬には出していません');
  });

  test('賞金順位は古馬の重賞で出走馬決定賞金の額と一緒に出す（リステッドでは出さない）', () {
    final g2 = _race('3歳以上オープン', raceGrade: 'G2');
    expect(isPrizeRankShownRace(g2), isTrue);
    final result = buildEntryMeanings(
      circumstances: _rc(
        g2,
        [
          _c('2021100001', 1,
              horseClass: EarnedPrizeClass.open,
              rankingPrizeInThousandYen: 45500,
              prizeRank: 3),
        ],
        rankedCount: 16,
      ),
      campSignals: const [],
      horses: [_h('2021100001', 1)],
    );
    expect(_facts(result.horses[0]), ['出走馬決定賞金 4,550万円（16頭中3位）']);
    expect(result.horses[0].lines.single.kind, EntryMeaningKind.prizeRank);

    final listed = _race('3歳以上オープン', raceGrade: 'L');
    expect(listed.prizeBasis, PrizeRankingBasis.decision);
    expect(isPrizeRankShownRace(listed), isFalse);
    expect(isPrizeRankShownRace(_race('3歳以上2勝クラス')), isFalse);
    expect(isPrizeRankShownRace(_race('2歳オープン', raceGrade: 'G1')), isFalse);
  });

  test('春の3歳GⅠは芝の賞金の額と順位（推定・外国の不明を添える）', () {
    final race = _race('3歳オープン',
        raceGrade: 'G1', raceId: '202605021211', raceDate: '2026年5月31日');
    expect(race.prizeBasis, PrizeRankingBasis.springClassic);
    final entries = [
      EarnedPrizeEntry(
        date: DateTime(2026, 4, 12),
        raceId: '202609020611',
        raceName: '阪神GⅢ(GIII)',
        venue: '2阪神6',
        rank: 1,
        source: EarnedPrizeSource.jra,
        raceClass: EarnedPrizeRaceClass.g3,
        ageGroup: EarnedPrizeAgeGroup.threeSpring,
        isTurf: true,
        isGradeOne: false,
        amountInThousandYen: 24000,
        basis: EarnedPrizeBasis.halfOfPrizeEstimated,
      ),
      EarnedPrizeEntry(
        date: DateTime(2026, 3, 28),
        raceId: '',
        raceName: 'UAEダービー(G2)',
        venue: 'メイダン',
        rank: 1,
        source: EarnedPrizeSource.foreign,
        raceClass: EarnedPrizeRaceClass.g2,
        ageGroup: EarnedPrizeAgeGroup.threeSpring,
        isTurf: true,
        isGradeOne: false,
        amountInThousandYen: null,
        basis: EarnedPrizeBasis.unknown,
      ),
    ];
    final prize = EarnedPrizeResult(
      asOf: DateTime(2026, 5, 31),
      ageGroupAtAsOf: EarnedPrizeAgeGroup.threeSpring,
      entries: entries,
      decisionPeriod1Start: DateTime(2025, 6, 2),
      decisionPeriod2Start: DateTime(2024, 6, 3),
    );
    final result = buildEntryMeanings(
      circumstances: _rc(
        race,
        [
          _c('2023100001', 1,
              horseClass: EarnedPrizeClass.open,
              prize: prize,
              rankingPrizeInThousandYen: 24000,
              prizeRank: 10),
        ],
        rankedCount: 18,
      ),
      campSignals: const [],
      horses: [_h('2023100001', 1)],
    );
    expect(_facts(result.horses[0]),
        ['春の3歳GⅠ用の賞金（芝） 2,400万円（18頭中10位・重賞の半額は推定を含む・外国1走は金額不明）']);
  });

  test('3歳未勝利の期限・3歳の未勝利戦で初出走と2戦目', () {
    final race = _race('3歳以上未勝利', raceDate: '2026年8月2日');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2023100001', 1,
            horseClass: EarnedPrizeClass.maiden,
            startsSinceClassReached: 0,
            isMaidenDeadline: true),
        _c('2023100002', 2,
            horseClass: EarnedPrizeClass.maiden,
            startsSinceClassReached: 1,
            isMaidenDeadline: true),
        _c('2023100003', 3,
            horseClass: EarnedPrizeClass.maiden,
            startsSinceClassReached: 2,
            isMaidenDeadline: true),
        _c('2022100004', 4,
            horseClass: EarnedPrizeClass.maiden, startsSinceClassReached: 0),
      ]),
      campSignals: const [],
      horses: [
        _h('2023100001', 1),
        _h('2023100002', 2),
        _h('2023100003', 3),
        _h('2022100004', 4),
      ],
    );
    expect(_facts(result.horses[0]), ['3歳未勝利の期限が近い時期（8月）', '3歳8月の初出走']);
    expect(result.horses[0].lines[0].interpretation, '勝ち上がりを急ぐ局面の可能性');
    expect(result.horses[0].lines[1].interpretation, 'デビューが遅れた事情がある可能性');
    expect(result.horses[0].lines[1].basis, EntryMeaningBasis.general);
    expect(_facts(result.horses[1]), ['3歳未勝利の期限が近い時期（8月）', '3歳の未勝利戦で2戦目']);
    expect(_facts(result.horses[2]), ['3歳未勝利の期限が近い時期（8月）']);
    expect(result.horses[3].lines, isEmpty);
  });

  test('遠征・間隔（120日の区切り）・休み明けから3〜4戦目', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 1,
            affiliation: TrainerAffiliation.ritto,
            expedition: ExpeditionStatus.expedition),
        _c('2022100002', 2),
        _c('2022100003', 3),
        _c('2022100004', 4),
        _c('2022100005', 5),
        _c('2022100006', 6),
        _c('2022100007', 7),
      ]),
      campSignals: [
        _s('2022100001', 1,
            lastStartDate: DateTime(2026, 3, 1), startNumberSinceLayoff: 1),
        _s('2022100002', 2,
            lastStartDate: DateTime(2026, 5, 20), startNumberSinceLayoff: 1),
        _s('2022100003', 3,
            lastStartDate: DateTime(2026, 7, 12), startNumberSinceLayoff: 1),
        _s('2022100004', 4,
            lastStartDate: DateTime(2026, 9, 20), startNumberSinceLayoff: 5),
        _s('2022100005', 5,
            lastStartDate: DateTime(2026, 9, 27),
            startNumberSinceLayoff: 6,
            isCountedFromLayoff: false),
        _s('2022100006', 6,
            lastStartDate: DateTime(2026, 9, 6), startNumberSinceLayoff: 3),
        _s('2022100007', 7,
            lastStartDate: DateTime(2026, 9, 6),
            startNumberSinceLayoff: 4,
            isCountedFromLayoff: false),
      ],
      horses: [
        _h('2022100001', 1, trainerAffiliation: '栗東'),
        _h('2022100002', 2),
        _h('2022100003', 3),
        _h('2022100004', 4),
        _h('2022100005', 5),
        _h('2022100006', 6),
        _h('2022100007', 7),
      ],
    );
    expect(_facts(result.horses[0]), ['栗東から東京へ遠征', '長期休養明け（7ヶ月・217日ぶり）']);
    expect(result.horses[0].lines[0].interpretation, '輸送してまで使う理由がある可能性');
    expect(result.horses[0].lines[1].interpretation, '叩き台の可能性');
    expect(_facts(result.horses[1]), ['長めの休み明け（4ヶ月・137日ぶり）']);
    expect(_kinds(result.horses[1]), [EntryMeaningKind.longishLayoff]);
    expect(_facts(result.horses[2]), ['休み明け（2ヶ月・84日ぶり）']);
    expect(_facts(result.horses[3]), ['間隔が詰まっている（中1週・休み明けから5戦目）']);
    expect(_facts(result.horses[4]), ['間隔が詰まっている（連闘・デビューから6戦目）']);
    expect(_facts(result.horses[5]), ['休み明けから3戦目']);
    expect(result.horses[5].lines.single.interpretation, '調子が上向く頃の可能性');
    expect(result.horses[6].lines, isEmpty);
  });

  test('乗り替わり・前走の騎手の別馬騎乗・主戦の継続・ブリンカー初', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 1),
        _c('2022100002', 2),
        _c('2022100003', 3),
        _c('2022100004', 4),
        _c('2022100005', 5),
      ]),
      campSignals: [
        _s('2022100001', 1,
            previousJockeyName: '武豊',
            isJockeyChanged: true,
            ridesOnThisHorse: 0,
            // [修正] 2番の馬の馬ID (v.2026.10.6+26100601)
            previousJockeyRidingHorseId: '2022100002'),
        _s('2022100002', 2,
            isJockeyChanged: false,
            ridesOnThisHorse: 3,
            isMainJockey: true,
            isFirstBlinker: true),
        _s('2022100003', 3,
            isJockeyChanged: false, ridesOnThisHorse: 1, isMainJockey: true),
        _s('2022100004', 4,
            previousJockeyName: '横山武史',
            isJockeyChanged: true,
            ridesOnThisHorse: 2,
            isMainJockey: true),
        _s('2022100005', 5, isJockeyChanged: null, ridesOnThisHorse: 0),
      ],
      horses: [
        _h('2022100001', 1, jockey: 'ルメール'),
        _h('2022100002', 2, jockey: '武豊'),
        _h('2022100003', 3),
        _h('2022100004', 4, jockey: '戸崎圭太'),
        _h('2022100005', 5),
      ],
    );
    expect(_facts(result.horses[0]), [
      '乗り替わり（前走 武豊 → 今回 ルメール・この馬に初騎乗）',
      '前走の騎手（武豊）は2番馬2に騎乗',
    ]);
    expect(_facts(result.horses[1]), ['主戦騎手の継続騎乗（この馬に4回目）', 'ブリンカー初装着']);
    expect(result.horses[1].lines[1].interpretation, '集中力を引き出す工夫の可能性');
    expect(result.horses[2].lines, isEmpty);
    expect(_facts(result.horses[3]),
        ['乗り替わり（前走 横山武史 → 今回 戸崎圭太・この馬に3回目の騎乗・主戦騎手が戻る）']);
    expect(result.horses[4].lines, isEmpty);
  });

  // [追加] 枠順発表前は全馬が0番。前走の騎手が乗る別馬を馬IDで探し、先に並ぶ別の0番の馬を拾わない (v.2026.10.6+26100601)
  test('枠順発表前（全馬0番）でも前走の騎手が乗る馬を取り違えない', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 0),
        _c('2022100002', 0),
        _c('2022100003', 0),
      ]),
      campSignals: [
        _s('2022100001', 0,
            previousJockeyName: '武豊',
            isJockeyChanged: true,
            ridesOnThisHorse: 0,
            previousJockeyRidingHorseId: '2022100003'),
        _s('2022100002', 0),
        _s('2022100003', 0),
      ],
      horses: [
        _h('2022100001', 0, jockey: 'ルメール', trainerName: '調教師A'),
        _h('2022100002', 0, jockey: '松岡正海', trainerName: '調教師B'),
        _h('2022100003', 0, jockey: '武豊', trainerName: '調教師C'),
      ],
    );
    expect(_facts(result.horses[0]), [
      '乗り替わり（前走 武豊 → 今回 ルメール・この馬に初騎乗）',
      '前走の騎手（武豊）は0番馬0に騎乗',
    ]);
    expect(result.horses[1].lines, isEmpty);
    expect(result.horses[2].lines, isEmpty);
  });

  test('同じ馬主（プロフィールの馬主ID）・同じ厩舎（調教師名＋所属）', () {
    final race = _race('3歳以上2勝クラス');
    final result = buildEntryMeanings(
      circumstances: _rc(race, [
        _c('2022100001', 1),
        _c('2022100002', 2),
        _c('2022100003', 3),
        _c('2022100004', 4, affiliation: TrainerAffiliation.ritto),
        _c('2022100005', 5, isScratched: true),
      ]),
      campSignals: const [],
      horses: [
        _h('2022100001', 1, trainerName: '矢作'),
        _h('2022100002', 2, trainerName: '矢作'),
        _h('2022100003', 3, trainerName: '堀'),
        _h('2022100004', 4, trainerName: '矢作', trainerAffiliation: '栗東'),
        _h('2022100005', 5, trainerName: '矢作', isScratched: true),
      ],
      profilesByHorseId: {
        '2022100001': _profile('2022100001', '226800', 'サンデーレーシング'),
        '2022100003': _profile('2022100003', '226800', 'サンデーレーシング'),
        '2022100004': _profile('2022100004', '', ''),
        '2022100005': _profile('2022100005', '226800', 'サンデーレーシング'),
      },
    );
    expect(_facts(result.horses[0]), [
      '同じ馬主（サンデーレーシング）の3番馬3も出走',
      '同じ厩舎（美浦・矢作）の2番馬2も出走',
    ]);
    expect(_facts(result.horses[1]), ['同じ厩舎（美浦・矢作）の1番馬1も出走']);
    expect(_facts(result.horses[2]), ['同じ馬主（サンデーレーシング）の1番馬1も出走']);
    expect(result.horses[3].lines, isEmpty);
    expect(result.horses[4].lines, isEmpty);
  });
}
