// test/horse_circumstance_test.dart

// [追加] 陣営の本気度指数 実施順5 Step2: 出走馬ごとの事情（horse_circumstance.dart）の単体テスト (v.2026.10.3+26100302)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/horse_circumstance.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/logic/trainer_affiliation.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

HorseRaceRecord _r(
  String horseId,
  String date,
  String raceName,
  String rank, {
  String venue = '5東京8',
  String raceId = '202605050811',
  String prize = '',
  String distance = '芝1600',
}) {
  return HorseRaceRecord(
    horseId: horseId,
    raceId: raceId,
    date: date,
    venue: venue,
    weather: '',
    raceNumber: '',
    raceName: raceName,
    numberOfHorses: '',
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: '',
    rank: rank,
    jockey: '',
    jockeyId: '',
    carriedWeight: '',
    distance: distance,
    trackCondition: '',
    time: '',
    margin: '',
    cornerPassage: '',
    pace: '',
    agari: '',
    horseWeight: '',
    winnerOrSecondHorse: '',
    prizeMoney: prize,
  );
}

PredictionHorseDetail _h(
  String horseId,
  int horseNumber, {
  String affiliation = '',
  String trainerName = '',
  bool isScratched = false,
}) {
  return PredictionHorseDetail(
    horseId: horseId,
    horseNumber: horseNumber,
    gateNumber: 1,
    horseName: '馬$horseNumber',
    sexAndAge: '牡4',
    jockey: '',
    jockeyId: '',
    carriedWeight: 57.0,
    trainerName: trainerName,
    trainerAffiliation: affiliation,
    isScratched: isScratched,
  );
}

void main() {
  group('2勝クラス（東京）', () {
    final race = classifyRaceFromParts(
      raceId: '202605030509',
      raceDate: '2026年6月20日',
      raceCategory: 'サラ系３歳以上 ２勝クラス (混)[指] ハンデ',
      raceGrade: '2勝',
      trackType: '芝',
      basePrize1st: 1580,
      basePrize2nd: 630,
    );
    final records = {
      '2021100001': [
        _r('2021100001', '2023/10/01', '2歳新馬', '1'),
        _r('2021100001', '2024/05/01', '3歳1勝クラス', '1'),
        _r('2021100001', '2024/08/01', '3歳以上2勝クラス', '5'),
        _r('2021100001', '2025/01/01', '4歳以上2勝クラス', '3'),
        _r('2021100001', '2025/03/01', '4歳以上2勝クラス', '取'),
        _r('2021100001', '2026/05/01', '4歳以上2勝クラス', '2'),
      ],
      '2022100002': [
        _r('2022100002', '2025/02/01', '3歳未勝利', '1'),
        _r('2022100002', '2025/06/01', '3歳1勝クラス', '4'),
      ],
      '2020100003': [
        _r('2020100003', '2022/10/01', '2歳新馬', '1'),
        _r('2020100003', '2024/02/01', '京都牝馬S(GIII)', '2',
            venue: '1京都6', prize: '1,000.0', distance: '芝1400'),
        _r('2020100003', '2024/06/01', '4歳以上2勝クラス', '6',
            distance: 'ダ1400'),
      ],
      '2022100004': [
        _r('2022100004', '2024/10/01', '2歳新馬', '1'),
      ],
    };
    final horses = [
      _h('2021100001', 1, affiliation: '栗東'),
      _h('2022100002', 2, affiliation: '美浦'),
      _h('2020100003', 3, affiliation: '美浦'),
      _h('2022100004', 4, affiliation: '栗東', isScratched: true),
      _h('2022100005', 5, trainerName: '地方榎屋充'),
    ];
    final result = buildRaceCircumstances(
      race: race,
      horses: horses,
      recordsByHorseId: records,
    );

    test('レース全体の頭数', () {
      expect(result.isSupported, isTrue);
      expect(result.horses.length, 5);
      expect(result.rankedCount, 3);
      expect(result.unjudgedCount, 1);
      expect(result.classChallengeCount, 1);
    });

    test('同クラスの馬（遠征・滞在走数・取消は数えない）', () {
      final h = result.horses[0];
      expect(h.canJudge, isTrue);
      expect(h.prize!.totalInThousandYen, 9000);
      expect(h.horseClass, EarnedPrizeClass.win2);
      expect(h.classGap, 0);
      expect(h.isClassChallenge, isFalse);
      expect(h.needsCheck, isFalse);
      expect(h.classReachedDate, DateTime(2024, 5, 1));
      expect(h.startsSinceClassReached, 3);
      expect(h.promotedByGradedSecond, isFalse);
      expect(h.rankingPrizeInThousandYen, 9000);
      expect(h.prizeRank, 1);
      expect(h.affiliation, TrainerAffiliation.ritto);
      expect(h.expedition, ExpeditionStatus.expedition);
      expect(h.isMaidenDeadline, isFalse);
    });

    test('格上挑戦の馬', () {
      final h = result.horses[1];
      expect(h.horseClass, EarnedPrizeClass.win1);
      expect(h.classGap, 1);
      expect(h.isClassChallenge, isTrue);
      expect(h.classReachedDate, DateTime(2025, 2, 1));
      expect(h.startsSinceClassReached, 1);
      expect(h.prizeRank, 3);
      expect(h.expedition, ExpeditionStatus.home);
    });

    test('重賞2着で昇級した馬（同額は同順位）', () {
      final h = result.horses[2];
      expect(h.prize!.totalInThousandYen, 9000);
      expect(h.horseClass, EarnedPrizeClass.win2);
      expect(h.classReachedDate, DateTime(2024, 2, 1));
      expect(h.promotedByGradedSecond, isTrue);
      expect(h.startsSinceClassReached, 1);
      expect(h.prizeRank, 1);
    });

    test('取消の馬は順位を付けず、格上挑戦の頭数にも入れない', () {
      final h = result.horses[3];
      expect(h.isScratched, isTrue);
      expect(h.canJudge, isTrue);
      expect(h.isClassChallenge, isTrue);
      expect(h.prizeRank, isNull);
    });

    test('過去走が無い馬は判定しない（未勝利と誤判定しない）', () {
      final h = result.horses[4];
      expect(h.canJudge, isFalse);
      expect(h.prize, isNull);
      expect(h.horseClass, isNull);
      expect(h.classGap, isNull);
      expect(h.isClassChallenge, isFalse);
      expect(h.startsSinceClassReached, isNull);
      expect(h.prizeRank, isNull);
      expect(h.affiliation, TrainerAffiliation.local);
      expect(h.expedition, ExpeditionStatus.notApplicable);
    });
  });

  test('古馬の重賞は出走馬決定賞金で並べる', () {
    final race = classifyRaceFromParts(
      raceId: '202605040211',
      raceDate: '2026年10月4日',
      raceCategory: 'サラ系３歳以上 オープン (国際)(指) 別定',
      raceGrade: 'G2',
      trackType: '芝',
    );
    final result = buildRaceCircumstances(
      race: race,
      horses: [
        _h('2021100006', 1, affiliation: '美浦'),
        _h('2021100007', 2, affiliation: '栗東'),
      ],
      recordsByHorseId: {
        '2021100006': [
          _r('2021100006', '2023/08/01', '2歳新馬', '1'),
          _r('2021100006', '2026/03/01', '東風S(L)', '1', venue: '2中山1'),
        ],
        '2021100007': [
          _r('2021100007', '2023/08/01', '2歳新馬', '1'),
          _r('2021100007', '2023/12/01', '2歳1勝クラス', '1'),
          _r('2021100007', '2024/06/15', '3歳以上2勝クラス', '1'),
          _r('2021100007', '2024/12/01', '3歳以上3勝クラス', '1'),
        ],
      },
    );
    final a = result.horses[0];
    final b = result.horses[1];
    expect(a.prize!.totalInThousandYen, 18000);
    expect(a.rankingPrizeInThousandYen, 32000);
    expect(a.prizeRank, 1);
    expect(a.horseClass, EarnedPrizeClass.open);
    expect(a.classGap, 0);
    expect(a.expedition, ExpeditionStatus.home);
    expect(b.prize!.totalInThousandYen, 24000);
    expect(b.rankingPrizeInThousandYen, 24000);
    expect(b.prizeRank, 2);
    expect(b.expedition, ExpeditionStatus.expedition);
  });

  test('春の3歳GⅠは芝の賞金で並べる', () {
    final race = classifyRaceFromParts(
      raceId: '202605021211',
      raceDate: '2026年5月31日',
      raceCategory: 'サラ系３歳 オープン (国際) 牡・牝(指) 馬齢',
      raceGrade: 'G1',
      trackType: '芝',
    );
    final result = buildRaceCircumstances(
      race: race,
      horses: [
        _h('2023100007', 1, affiliation: '栗東'),
        _h('2023100008', 2, affiliation: '栗東'),
        _h('2023100009', 3, affiliation: '美浦'),
      ],
      recordsByHorseId: {
        '2023100007': [
          _r('2023100007', '2025/09/01', '2歳未勝利', '1'),
          _r('2023100007', '2026/01/10', '3歳1勝クラス', '1',
              distance: 'ダ1800'),
        ],
        '2023100008': [
          _r('2023100008', '2025/08/01', '2歳新馬', '1'),
          _r('2023100008', '2025/12/01', '京王杯2歳S(GIII)', '1'),
        ],
        '2023100009': [
          _r('2023100009', '2025/08/01', '2歳新馬', '1'),
          _r('2023100009', '2026/02/01', '3歳1勝クラス', '1'),
        ],
      },
    );
    expect(result.horses.map((h) => h.rankingPrizeInThousandYen).toList(),
        [0, 16000, 5000]);
    expect(result.horses.map((h) => h.prizeRank).toList(), [3, 1, 2]);
    // 3歳の6月1日までは500万円を超えればオープン
    expect(result.horses.map((h) => h.horseClass).toList(), [
      EarnedPrizeClass.open,
      EarnedPrizeClass.open,
      EarnedPrizeClass.open,
    ]);
    expect(result.classChallengeCount, 0);
  });

  group('3歳未勝利の期限', () {
    RaceCircumstances build(String raceDate) {
      final race = classifyRaceFromParts(
        raceId: '202604020507',
        raceDate: raceDate,
        raceCategory: 'サラ系３歳 未勝利 [指] 馬齢',
        trackType: 'ダ',
      );
      return buildRaceCircumstances(
        race: race,
        horses: [
          _h('2023100010', 1, affiliation: '美浦'),
          _h('2023100011', 2, affiliation: '栗東'),
        ],
        recordsByHorseId: {
          '2023100010': [
            _r('2023100010', '2026/07/01', '3歳未勝利', '5', venue: '2福島1'),
          ],
        },
      );
    }

    test('8月の3歳未勝利は期限が近い（未勝利戦は過去走が無くても判定する）', () {
      final result = build('2026年8月15日');
      final a = result.horses[0];
      final b = result.horses[1];
      expect(a.canJudge, isTrue);
      expect(a.horseClass, EarnedPrizeClass.maiden);
      expect(a.startsSinceClassReached, 1);
      expect(a.isMaidenDeadline, isTrue);
      expect(a.expedition, ExpeditionStatus.localVenue);
      expect(b.canJudge, isTrue);
      expect(b.startsSinceClassReached, 0);
      expect(b.isMaidenDeadline, isTrue);
      expect(result.unjudgedCount, 0);
      expect(a.prizeRank, 1);
      expect(b.prizeRank, 1);
    });

    test('6月はまだ期限ではない', () {
      final result = build('2026年6月20日');
      expect(result.horses[0].isMaidenDeadline, isFalse);
      expect(result.horses[1].isMaidenDeadline, isFalse);
      expect(result.horses[0].startsSinceClassReached, 0);
    });
  });

  test('障害・地方・日付なしは事情を出さない', () {
    for (final race in [
      classifyRaceFromParts(
        raceId: '202605030504',
        raceDate: '2026年6月20日',
        raceCategory: '障害３歳以上 オープン',
        trackType: '障',
      ),
      classifyRaceFromParts(raceId: '202644052111', raceDate: '2026/05/21'),
      classifyRaceFromParts(
        raceId: '202605030509',
        raceDate: '',
        raceCategory: 'サラ系３歳以上 ２勝クラス',
      ),
    ]) {
      final result = buildRaceCircumstances(
        race: race,
        horses: [_h('2021100001', 1, affiliation: '栗東')],
        recordsByHorseId: const {},
      );
      expect(result.isSupported, isFalse, reason: race.raceId);
      expect(result.horses, isEmpty);
    }
  });

  group('部品', () {
    test('遠征の判定', () {
      const ritto = TrainerAffiliation.ritto;
      const miho = TrainerAffiliation.miho;
      expect(expeditionStatusOf(ritto, '05'), ExpeditionStatus.expedition);
      expect(expeditionStatusOf(ritto, '06'), ExpeditionStatus.expedition);
      expect(expeditionStatusOf(miho, '08'), ExpeditionStatus.expedition);
      expect(expeditionStatusOf(miho, '09'), ExpeditionStatus.expedition);
      expect(expeditionStatusOf(miho, '05'), ExpeditionStatus.home);
      expect(expeditionStatusOf(ritto, '09'), ExpeditionStatus.home);
      for (final code in ['01', '02', '03', '04', '07', '10']) {
        expect(expeditionStatusOf(ritto, code), ExpeditionStatus.localVenue,
            reason: code);
        expect(expeditionStatusOf(miho, code), ExpeditionStatus.localVenue,
            reason: code);
      }
      expect(expeditionStatusOf(TrainerAffiliation.local, '05'),
          ExpeditionStatus.notApplicable);
      expect(expeditionStatusOf(TrainerAffiliation.overseas, '08'),
          ExpeditionStatus.notApplicable);
      expect(expeditionStatusOf(TrainerAffiliation.unknown, '05'),
          ExpeditionStatus.notApplicable);
      expect(expeditionStatusOf(ritto, '44'), ExpeditionStatus.notApplicable);
    });

    test('所属が空なら調教師名で読む', () {
      expect(affiliationOfHorse(_h('1', 1, trainerName: '海外イプ')),
          TrainerAffiliation.overseas);
      expect(affiliationOfHorse(_h('1', 1, affiliation: '美浦', trainerName: '木村哲也')),
          TrainerAffiliation.miho);
      expect(affiliationOfHorse(_h('1', 1, trainerName: '木村哲也')),
          TrainerAffiliation.unknown);
    });

    test('出走の判定', () {
      expect(isRaceStart(_r('1', '2026/01/01', 'x', '12')), isTrue);
      expect(isRaceStart(_r('1', '2026/01/01', 'x', '中')), isTrue);
      expect(isRaceStart(_r('1', '2026/01/01', 'x', '取')), isFalse);
      expect(isRaceStart(_r('1', '2026/01/01', 'x', '除')), isFalse);
      expect(isRaceStart(_r('1', '2026/01/01', 'x', '')), isFalse);
      expect(isFlatRecord(_r('1', '2026/01/01', 'x', '1', distance: '障3380')),
          isFalse);
    });

    test('生まれ年', () {
      expect(birthYearOfHorseId('2022100001'), 2022);
      expect(birthYearOfHorseId('ab'), isNull);
    });
  });
}
