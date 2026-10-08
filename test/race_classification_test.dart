// test/race_classification_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

void main() {
  group('出馬表の値から区分を読む', () {
    test('2勝クラス・ハンデ（函館）', () {
      final r = classifyRaceFromParts(
        raceId: '202602010210',
        raceDate: '2026年6月14日',
        raceCategory: 'サラ系３歳以上 ２勝クラス [指] ハンデ',
        raceGrade: '2勝',
        trackType: 'ダ',
        basePrize1st: 1580,
        basePrize2nd: 630,
      );
      expect(r.date, DateTime(2026, 6, 14));
      expect(r.venueCode, '02');
      expect(r.isJra, isTrue);
      expect(r.isJump, isFalse);
      expect(r.classLevel, RaceClassLevel.win2);
      expect(r.classStep, 2);
      expect(r.grade, RaceGradeLevel.none);
      expect(r.isGraded, isFalse);
      expect(r.ageCondition, RaceAgeCondition.threeUp);
      expect(r.weightRule, RaceWeightRule.handicap);
      expect(r.isFillyMareOnly, isFalse);
      expect(r.basePrize1stMan, 1580);
      expect(r.basePrize2ndMan, 630);
      expect(r.isSpringClassic, isFalse);
      expect(r.prizeBasis, PrizeRankingBasis.earned);
    });

    test('日本ダービーは春の3歳GⅠ', () {
      final r = classifyRaceFromParts(
        raceId: '202605021211',
        raceDate: '2026年5月31日',
        raceCategory: 'サラ系３歳 オープン (国際) 牡・牝(指) 馬齢',
        raceGrade: 'G1',
        trackType: '芝',
        basePrize1st: 30000,
        basePrize2nd: 12000,
      );
      expect(r.classLevel, RaceClassLevel.open);
      expect(r.classStep, 4);
      expect(r.grade, RaceGradeLevel.g1);
      expect(r.isGraded, isTrue);
      expect(r.ageCondition, RaceAgeCondition.three);
      expect(r.weightRule, RaceWeightRule.age);
      expect(r.isFillyMareOnly, isFalse);
      expect(r.isSpringClassic, isTrue);
      expect(r.prizeBasis, PrizeRankingBasis.springClassic);
    });

    test('オークスは牝馬限定の春の3歳GⅠ', () {
      final r = classifyRaceFromParts(
        raceId: '202605021011',
        raceDate: '2026年5月24日',
        raceCategory: 'サラ系３歳 オープン (国際) 牝(指) 馬齢',
        raceGrade: 'G1',
        trackType: '芝',
      );
      expect(r.isFillyMareOnly, isTrue);
      expect(r.isSpringClassic, isTrue);
      expect(r.prizeBasis, PrizeRankingBasis.springClassic);
    });

    test('菊花賞（3歳GⅠ・秋）は収得賞金で並べる', () {
      final r = classifyRaceFromParts(
        raceId: '202508030911',
        raceDate: '2025年10月26日',
        raceCategory: 'サラ系３歳 オープン (国際) 牡・牝(指) 馬齢',
        raceGrade: 'G1',
        trackType: '芝',
      );
      expect(r.isSpringClassic, isFalse);
      expect(r.prizeBasis, PrizeRankingBasis.earned);
    });

    test('古馬の重賞・リステッドは出走馬決定賞金で並べる', () {
      final g2 = classifyRaceFromParts(
        raceId: '202605040211',
        raceDate: '2026年10月4日',
        raceCategory: 'サラ系３歳以上 オープン (国際)(指) 別定',
        raceGrade: 'G2',
        trackType: '芝',
      );
      expect(g2.grade, RaceGradeLevel.g2);
      expect(g2.weightRule, RaceWeightRule.allowance);
      expect(g2.prizeBasis, PrizeRankingBasis.decision);

      final vm = classifyRaceFromParts(
        raceId: '202605020811',
        raceDate: '2026年5月17日',
        raceCategory: 'サラ系４歳以上 オープン (国際) 牝(指) 定量',
        raceGrade: 'G1',
        trackType: '芝',
      );
      expect(vm.ageCondition, RaceAgeCondition.fourUp);
      expect(vm.weightRule, RaceWeightRule.fixed);
      expect(vm.isFillyMareOnly, isTrue);
      expect(vm.isSpringClassic, isFalse);
      expect(vm.prizeBasis, PrizeRankingBasis.decision);

      final listed = classifyRaceFromParts(
        raceId: '202605030411',
        raceDate: '2026年6月14日',
        raceCategory: 'サラ系３歳以上 オープン (国際)(特指) ハンデ',
        raceGrade: 'L',
        trackType: '芝',
      );
      expect(listed.grade, RaceGradeLevel.listed);
      expect(listed.prizeBasis, PrizeRankingBasis.decision);
    });

    test('オープン特別と2歳重賞は収得賞金で並べる', () {
      final op = classifyRaceFromParts(
        raceId: '202603020411',
        raceDate: '2026年7月5日',
        raceCategory: 'サラ系３歳以上 オープン (国際)(特指) ハンデ',
        raceGrade: 'OP',
        trackType: 'ダ',
      );
      expect(op.grade, RaceGradeLevel.openSpecial);
      expect(op.prizeBasis, PrizeRankingBasis.earned);

      final twoYearOld = classifyRaceFromParts(
        raceId: '202601020511',
        raceDate: '2026年9月5日',
        raceCategory: 'サラ系２歳 オープン (国際)(特指) 馬齢',
        raceGrade: 'G3',
        trackType: '芝',
      );
      expect(twoYearOld.ageCondition, RaceAgeCondition.two);
      expect(twoYearOld.grade, RaceGradeLevel.g3);
      expect(twoYearOld.prizeBasis, PrizeRankingBasis.earned);
    });

    test('新馬・未勝利・1勝クラス', () {
      final newcomer = classifyRaceFromParts(
        raceId: '202605040205',
        raceDate: '2026年10月4日',
        raceCategory: 'サラ系２歳 新馬 (混)[指] 馬齢',
      );
      expect(newcomer.classLevel, RaceClassLevel.newcomer);
      expect(newcomer.classStep, 0);
      expect(newcomer.grade, RaceGradeLevel.none);

      final maiden = classifyRaceFromParts(
        raceId: '202604020507',
        raceDate: '2026年8月15日',
        raceCategory: 'サラ系３歳 未勝利 [指] 馬齢',
      );
      expect(maiden.classLevel, RaceClassLevel.maiden);
      expect(maiden.classStep, 0);
      expect(maiden.ageCondition, RaceAgeCondition.three);

      final win1 = classifyRaceFromParts(
        raceId: '202605040207',
        raceDate: '2026年10月4日',
        raceCategory: 'サラ系３歳以上 １勝クラス (混)[指] 定量',
        raceGrade: '1勝',
      );
      expect(win1.classLevel, RaceClassLevel.win1);
      expect(win1.classStep, 1);
      expect(win1.weightRule, RaceWeightRule.fixed);
    });

    test('raceCategory が無ければ raceGrade で読む', () {
      final win3 = classifyRaceFromParts(
        raceId: '202605030310',
        raceDate: '2026年6月13日',
        raceGrade: '3勝',
      );
      expect(win3.classLevel, RaceClassLevel.win3);
      expect(win3.ageCondition, RaceAgeCondition.unknown);
      expect(win3.weightRule, RaceWeightRule.unknown);

      final g2 = classifyRaceFromParts(
        raceId: '202605040211',
        raceDate: '2026年10月4日',
        raceGrade: 'G2',
      );
      expect(g2.classLevel, RaceClassLevel.open);
      expect(g2.grade, RaceGradeLevel.g2);
      // 年齢の条件が読めないので出走馬決定賞金にはしない
      expect(g2.prizeBasis, PrizeRankingBasis.earned);

      final unknown = classifyRaceFromParts(
        raceId: '202605040201',
        raceDate: '2026年10月4日',
      );
      expect(unknown.classLevel, RaceClassLevel.unknown);
      expect(unknown.classStep, isNull);
      expect(unknown.grade, RaceGradeLevel.none);
    });

    test('障害・地方・日付なし・本賞金0', () {
      final jump = classifyRaceFromParts(
        raceId: '202605030504',
        raceDate: '2026年6月20日',
        raceCategory: '障害３歳以上 オープン',
        trackType: '障',
      );
      expect(jump.isJump, isTrue);
      expect(jump.isSpringClassic, isFalse);

      final local = classifyRaceFromParts(
        raceId: '202644052111',
        raceDate: '2026/05/21',
      );
      expect(local.venueCode, '44');
      expect(local.isJra, isFalse);
      expect(local.date, DateTime(2026, 5, 21));

      final noDate = classifyRaceFromParts(
        raceId: '202605030509',
        raceDate: '',
        basePrize1st: 0,
        basePrize2nd: 0,
      );
      expect(noDate.date, isNull);
      expect(noDate.basePrize1stMan, isNull);
      expect(noDate.basePrize2ndMan, isNull);
    });
  });

  group('部品', () {
    test('全角数字を半角に', () {
      expect(normalizeRaceDigits('サラ系３歳以上 ２勝クラス'), 'サラ系3歳以上 2勝クラス');
    });

    test('日付の読み取り', () {
      expect(parseRaceDate('2026年10月4日'), DateTime(2026, 10, 4));
      expect(parseRaceDate('2026/10/04'), DateTime(2026, 10, 4));
      expect(parseRaceDate(''), isNull);
    });

    test('年齢の条件', () {
      expect(raceAgeConditionOf('サラ系２歳 新馬'), RaceAgeCondition.two);
      expect(raceAgeConditionOf('サラ系３歳 オープン'), RaceAgeCondition.three);
      expect(raceAgeConditionOf('サラ系３歳以上 オープン'), RaceAgeCondition.threeUp);
      expect(raceAgeConditionOf('サラ系４歳以上 オープン'), RaceAgeCondition.fourUp);
      expect(raceAgeConditionOf(''), RaceAgeCondition.unknown);
    });

    test('牝馬限定', () {
      expect(isFillyMareOnlyOf('サラ系３歳 オープン (国際) 牝(指) 馬齢'), isTrue);
      expect(isFillyMareOnlyOf('サラ系３歳 オープン (国際) 牡・牝(指) 馬齢'), isFalse);
      expect(isFillyMareOnlyOf('サラ系３歳以上 オープン (国際)(指) 別定'), isFalse);
    });
  });

  test('PredictionRaceData から読む（classifyRace）', () {
    final race = PredictionRaceData(
      raceId: '202605040211',
      raceName: '毎日王冠',
      raceDate: '2026年10月4日',
      venue: '東京',
      raceNumber: '11',
      shutubaTableUrl: '',
      raceGrade: 'G2',
      horses: const [],
      trackType: '芝',
      raceCategory: 'サラ系３歳以上 オープン (国際)(指) 別定',
      basePrize1st: 6700,
      basePrize2nd: 2700,
    );
    final r = classifyRace(race);
    expect(r.raceId, '202605040211');
    expect(r.date, DateTime(2026, 10, 4));
    expect(r.venueCode, '05');
    expect(r.classLevel, RaceClassLevel.open);
    expect(r.grade, RaceGradeLevel.g2);
    expect(r.ageCondition, RaceAgeCondition.threeUp);
    expect(r.basePrize1stMan, 6700);
    expect(r.prizeBasis, PrizeRankingBasis.decision);
  });
}
