// test/earned_prize_calculator_test.dart

// [追加] 陣営の本気度指数 実施順3: 収得賞金の計算（earned_prize_calculator.dart）の単体テスト (v.2026.10.2+26100207)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

HorseRaceRecord _r({
  required String date,
  required String raceName,
  required String rank,
  String venue = '5東京8',
  String raceId = '202605050811',
  String prize = '',
  String distance = '芝1600',
  String horseId = '2022100001',
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

/// 1走だけで計算した加算額（算入されなければ null）
int? _single(HorseRaceRecord record, {Map<String, List<int>>? base}) {
  final result = calculateEarnedPrize(
    records: [record],
    asOf: DateTime(2030, 1, 1),
    basePrizeManByRaceId: base ?? const {},
  );
  if (result.entries.isEmpty) return null;
  return result.entries.single.amountInThousandYen;
}

void main() {
  group('条件戦の積み上げとクラス', () {
    final records = [
      _r(date: '2026/01/10', raceName: '幕張S(3勝クラス)', rank: '1'),
      _r(date: '2024/10/01', raceName: '2歳新馬', rank: '1'),
      _r(date: '2025/08/01', raceName: '3歳以上2勝クラス', rank: '1'),
      _r(date: '2025/03/01', raceName: '3歳1勝クラス', rank: '1'),
    ];

    test('400・900・1,500・2,400万と積み上がる', () {
      int total(DateTime asOf) =>
          calculateEarnedPrize(records: records, asOf: asOf).totalInThousandYen;
      expect(total(DateTime(2024, 10, 2)), 4000);
      expect(total(DateTime(2025, 3, 2)), 9000);
      expect(total(DateTime(2025, 8, 2)), 15000);
      expect(total(DateTime(2026, 2, 1)), 24000);
    });

    test('内訳は日付の古い順', () {
      final result =
          calculateEarnedPrize(records: records, asOf: DateTime(2026, 2, 1));
      expect(result.entries.map((e) => e.raceName).toList(),
          ['2歳新馬', '3歳1勝クラス', '3歳以上2勝クラス', '幕張S(3勝クラス)']);
    });

    test('3歳の6月1日までは500万超がオープン、6月2日以降は金額どおり', () {
      final spring =
          calculateEarnedPrize(records: records, asOf: DateTime(2025, 6, 1));
      expect(spring.ageGroupAtAsOf, EarnedPrizeAgeGroup.threeSpring);
      expect(spring.amountClass, EarnedPrizeClass.win2);
      expect(spring.classAtAsOf, EarnedPrizeClass.open);

      final summer =
          calculateEarnedPrize(records: records, asOf: DateTime(2025, 6, 2));
      expect(summer.ageGroupAtAsOf, EarnedPrizeAgeGroup.threeUp);
      expect(summer.classAtAsOf, EarnedPrizeClass.win2);

      final autumn =
          calculateEarnedPrize(records: records, asOf: DateTime(2025, 9, 1));
      expect(autumn.classAtAsOf, EarnedPrizeClass.win3);
    });

    test('基準日と同じ日の走は数えない', () {
      final result =
          calculateEarnedPrize(records: records, asOf: DateTime(2026, 1, 10));
      expect(result.totalInThousandYen, 15000);
    });

    test('旧表記の500万下は1勝クラスと同じ500万', () {
      expect(
          _single(_r(date: '2019/03/01', raceName: 'あずさ賞(500万下)', rank: '1', horseId: '2016100001')),
          5000);
    });
  });

  group('earnedPrizeClassOf の境目', () {
    test('0・500・501・1,000・1,001・1,600・1,601万', () {
      expect(earnedPrizeClassOf(0), EarnedPrizeClass.maiden);
      expect(earnedPrizeClassOf(5000), EarnedPrizeClass.win1);
      expect(earnedPrizeClassOf(5010), EarnedPrizeClass.win2);
      expect(earnedPrizeClassOf(10000), EarnedPrizeClass.win2);
      expect(earnedPrizeClassOf(10010), EarnedPrizeClass.win3);
      expect(earnedPrizeClassOf(16000), EarnedPrizeClass.win3);
      expect(earnedPrizeClassOf(16010), EarnedPrizeClass.open);
    });
  });

  group('オープン特別・リステッドの年齢ごとの額', () {
    test('2歳: OP 600万・ひまわり賞 500万・L 800万', () {
      expect(_single(_r(date: '2024/11/01', raceName: 'もみじS(OP)', rank: '1')),
          6000);
      expect(
          _single(_r(date: '2024/08/20', raceName: 'ひまわり賞(OP)', rank: '1')),
          5000);
      expect(_single(_r(date: '2024/11/02', raceName: '萩S(L)', rank: '1')),
          8000);
    });

    test('3歳の6月1日まで: OP 1,000万・L 1,200万（ダービー当日の白百合S）', () {
      expect(
          _single(_r(date: '2025/04/01', raceName: 'スプリングS(OP)', rank: '1')),
          10000);
      expect(_single(_r(date: '2025/06/01', raceName: '白百合S(L)', rank: '1')),
          12000);
    });

    test('3歳の6月2日以降と4歳以上: OP 1,200万・L 1,400万', () {
      expect(_single(_r(date: '2025/06/15', raceName: '米子S(L)', rank: '1')),
          14000);
      expect(_single(_r(date: '2026/02/15', raceName: 'バレンタインS(OP)', rank: '1')),
          12000);
    });

    test('オープン特別・リステッド・条件戦の2着は算入しない', () {
      expect(_single(_r(date: '2026/02/15', raceName: 'バレンタインS(OP)', rank: '2')),
          isNull);
      expect(_single(_r(date: '2026/02/15', raceName: '六甲S(L)', rank: '2')),
          isNull);
      expect(_single(_r(date: '2026/02/15', raceName: '4歳以上3勝クラス', rank: '2')),
          isNull);
    });
  });

  group('重賞', () {
    test('2歳GⅢは1着1,600万・2着600万（固定額）', () {
      final first = calculateEarnedPrize(records: [
        _r(date: '2024/11/20', raceName: '東スポ杯2歳S(GIII)', rank: '1', prize: '3,912.4'),
      ], asOf: DateTime(2025, 1, 1));
      expect(first.totalInThousandYen, 16000);
      expect(first.entries.single.basis, EarnedPrizeBasis.fixed);
      expect(
          _single(_r(date: '2024/11/20', raceName: '東スポ杯2歳S(GIII)', rank: '2', prize: '1,512.4')),
          6000);
    });

    test('3歳以上の重賞は賞金列の半額で推定し、10万円未満を切り捨てる', () {
      final result = calculateEarnedPrize(records: [
        _r(date: '2026/04/26', raceName: 'マイラーズC(GII)', rank: '2', prize: '2,436.4'),
        _r(date: '2026/06/07', raceName: '安田記念(GI)', rank: '1', prize: '18,369.6'),
      ], asOf: DateTime(2026, 7, 1));
      expect(result.entries.map((e) => e.amountInThousandYen).toList(),
          [12100, 91800]);
      expect(result.hasEstimated, isTrue);
      expect(result.entries.first.basis, EarnedPrizeBasis.halfOfPrizeEstimated);
    });

    test('2歳GⅠ・GⅡも半額', () {
      expect(
          _single(_r(date: '2024/12/15', raceName: '朝日杯FS(GI)', rank: '1', prize: '7,000.0')),
          35000);
    });

    test('本賞金を渡すとその半額（推定の印なし）', () {
      final result = calculateEarnedPrize(
        records: [
          _r(date: '2026/04/26', raceName: 'マイラーズC(GII)', rank: '1', raceId: 'R1', prize: '6,027.4'),
          _r(date: '2026/04/26', raceName: 'マイラーズC(GII)', rank: '2', raceId: 'R1', prize: '2,436.4', horseId: '2022100002'),
        ],
        asOf: DateTime(2026, 7, 1),
        basePrizeManByRaceId: const {
          'R1': [5900, 2400],
        },
      );
      final amounts =
          result.entries.map((e) => e.amountInThousandYen!).toList()..sort();
      expect(amounts, [12000, 29500]);
      expect(result.hasEstimated, isFalse);
      expect(
          result.entries.every((e) => e.basis == EarnedPrizeBasis.halfOfBasePrize),
          isTrue);
    });
  });

  group('地方の競走', () {
    test('1着: 1,200万以上は半額・400万以上は400万・未満はそのまま', () {
      expect(
          _single(_r(date: '2025/10/07', raceName: 'レディスプレリュード(JpnII)', rank: '1', venue: '大井', raceId: '202544100711', prize: '4,000.0', distance: 'ダ1800')),
          20000);
      expect(
          _single(_r(date: '2025/06/12', raceName: 'ぎふ清流C(重賞)', rank: '1', venue: '笠松', raceId: '202547061211', prize: '1,000.0', distance: 'ダ1400')),
          4000);
      expect(
          _single(_r(date: '2026/04/30', raceName: 'JRA交流由良川特別', rank: '1', venue: '園田', raceId: '202650043011', prize: '200.0', distance: 'ダ1400')),
          2000);
    });

    test('2着: Jpn重賞は算入（945万→470万）、JRA交流は算入しない', () {
      expect(
          _single(_r(date: '2023/04/19', raceName: '東京スプリント競走(JpnIII)', rank: '2', venue: '大井', raceId: '202344041911', prize: '945.0', distance: 'ダ1200')),
          4700);
      expect(
          _single(_r(date: '2026/04/30', raceName: 'JRA交流由良川特別', rank: '2', venue: '園田', raceId: '202650043011', prize: '60.0', distance: 'ダ1400')),
          isNull);
    });

    test('2着: 地方所属の時期は本賞金100万以上だけ（160万以上は160万）', () {
      expect(
          _single(_r(date: '2022/11/29', raceName: 'フェイスフルブーツ特(B2B3)', rank: '2', venue: '船橋', raceId: '202243112910', prize: '160.0', distance: 'ダ1800')),
          1600);
      expect(
          _single(_r(date: '2021/07/01', raceName: '2歳　72.5', rank: '2', venue: '大井', raceId: '202144070104', prize: '104.0', distance: 'ダ1400')),
          1040);
      expect(
          _single(_r(date: '2025/10/05', raceName: 'C1七組', rank: '2', venue: '水沢', raceId: '202536100507', prize: '17.5', distance: 'ダ1400')),
          isNull);
    });
  });

  group('外国の競走', () {
    test('1着と重賞2着は金額不明として数え、重賞以外の2着は数えない', () {
      final result = calculateEarnedPrize(records: [
        _r(date: '2025/04/05', raceName: 'ドバイシーマクラシッ(GI)', rank: '1', venue: 'メイダン', raceId: '', distance: '芝2410'),
        _r(date: '2025/09/07', raceName: 'フォワ賞(GII)', rank: '2', venue: 'パリロンシャン', raceId: '', distance: '芝2400'),
        _r(date: '2025/09/14', raceName: 'ハンデ戦', rank: '2', venue: 'シャティン', raceId: '', distance: '芝1200'),
      ], asOf: DateTime(2026, 1, 1));
      expect(result.entries.length, 2);
      expect(result.unknownForeignCount, 2);
      expect(result.totalInThousandYen, 0);
      expect(result.entries.first.isGradeOne, isTrue);
      expect(result.entries.first.source, EarnedPrizeSource.foreign);
    });
  });

  group('数えない走', () {
    test('取消・除外・中止・3着以下・障害は数えない', () {
      final result = calculateEarnedPrize(records: [
        _r(date: '2025/05/01', raceName: '4歳以上1勝クラス', rank: '取'),
        _r(date: '2025/05/02', raceName: '4歳以上1勝クラス', rank: '除'),
        _r(date: '2025/05/03', raceName: '4歳以上1勝クラス', rank: '中'),
        _r(date: '2025/05/04', raceName: '4歳以上1勝クラス', rank: '3'),
        _r(date: '2025/05/05', raceName: '障害4歳以上未勝利', rank: '1', distance: '障2880'),
      ], asOf: DateTime(2026, 1, 1));
      expect(result.entries, isEmpty);
      expect(result.amountClass, EarnedPrizeClass.maiden);
    });
  });

  group('春の3歳GⅠ用の賞金', () {
    test('2025年以降: JRAの芝の1勝クラス・OP・L・重賞と芝の外国だけ', () {
      final result = calculateEarnedPrize(records: [
        _r(date: '2025/08/01', raceName: '2歳新馬', rank: '1', horseId: '2023100001'),
        _r(date: '2025/09/01', raceName: '2歳1勝クラス', rank: '1', distance: 'ダ1400', horseId: '2023100001'),
        _r(date: '2025/10/01', raceName: 'ジュニアグランプリ', rank: '1', venue: '盛岡', raceId: '202535100107', prize: '300.0', horseId: '2023100001'),
        _r(date: '2025/11/01', raceName: 'BCJターフ(GI)', rank: '2', venue: 'デルマー', raceId: '', horseId: '2023100001'),
        _r(date: '2025/12/01', raceName: 'ベゴニア賞(OP)', rank: '1', horseId: '2023100001'),
      ], asOf: DateTime(2026, 4, 1));
      expect(result.totalInThousandYen, 4000 + 5000 + 3000 + 6000);
      expect(result.springClassicInThousandYen, 6000);
      expect(result.springClassicUnknownForeignCount, 1);
      final local = result.entries.firstWhere((e) => e.source == EarnedPrizeSource.local);
      expect(local.isTurf, isTrue);
      expect(local.countsForSpringClassic, isFalse);
    });

    test('2024年以前の基準日では収得賞金の合計を返す', () {
      final result = calculateEarnedPrize(records: [
        _r(date: '2023/08/01', raceName: '2歳新馬', rank: '1', distance: 'ダ1400', horseId: '2021100001'),
      ], asOf: DateTime(2024, 4, 1));
      expect(result.springClassicInThousandYen, 4000);
    });
  });

  group('古馬の出走馬決定賞金', () {
    final records = [
      _r(date: '2023/10/01', raceName: '4歳以上3勝クラス', rank: '1', horseId: '2020100001'),
      _r(date: '2024/05/01', raceName: 'テスト(GI)', rank: '1', prize: '20,000.0', horseId: '2020100001'),
      _r(date: '2025/06/10', raceName: '米子S(OP)', rank: '1', horseId: '2020100001'),
      _r(date: '2025/11/03', raceName: 'JBCクラシック(JpnI)', rank: '1', venue: '船橋', raceId: '202543110311', prize: '10,000.0', distance: 'ダ1800', horseId: '2020100001'),
    ];

    test('既定の期間: 1年前・2年前の翌週から', () {
      final result =
          calculateEarnedPrize(records: records, asOf: DateTime(2026, 5, 1));
      expect(result.decisionPeriod1Start, DateTime(2025, 5, 8));
      expect(result.decisionPeriod2Start, DateTime(2024, 5, 8));
      expect(result.totalInThousandYen, 9000 + 100000 + 12000 + 50000);
      // 期間(1)= 12,000+50,000、期間(2)のGⅠ = JpnⅠの 50,000（2024/05/01 のGⅠは期間外）
      expect(result.decisionPrizeInThousandYen, 171000 + 62000 + 50000);
    });

    test('期間の始まりを渡すと上書きできる', () {
      final result = calculateEarnedPrize(
        records: records,
        asOf: DateTime(2026, 5, 1),
        decisionPeriod2Start: DateTime(2024, 5, 1),
      );
      expect(result.decisionPrizeInThousandYen, 171000 + 62000 + 150000);
    });
  });

  group('部品', () {
    test('賞金列の読み取りと半額の切り捨て', () {
      expect(parsePrizeInThousandYen('1,580.1'), 15801);
      expect(parsePrizeInThousandYen(''), isNull);
      expect(halfFloorTenMan(24364), 12100);
    });

    test('主催の判定', () {
      expect(earnedPrizeSourceOf(_r(date: '2026/01/01', raceName: 'x', rank: '1')),
          EarnedPrizeSource.jra);
      expect(
          earnedPrizeSourceOf(_r(date: '2026/01/01', raceName: 'x', rank: '1', venue: '大井', raceId: '202644010101')),
          EarnedPrizeSource.local);
      expect(
          earnedPrizeSourceOf(_r(date: '2026/01/01', raceName: 'x', rank: '1', venue: 'シャティン', raceId: '')),
          EarnedPrizeSource.foreign);
    });
  });
}
