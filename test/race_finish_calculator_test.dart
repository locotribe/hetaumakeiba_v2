// test/race_finish_calculator_test.dart

// [追加] 展開シミュ一般論見直しStep1: RaceFinishCalculator の単体テスト (v.2026.9.29+26092905)
// [修正] 展開シミュ一般論見直しStep4: 定数表に距離帯の次元が入ったため期待値を更新し、
// 距離帯のテストを追加した (v.2026.9.29+26092907)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_finish_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

HorseRaceRecord rec({
  String distance = '芝1600',
  String cornerPassage = '5-5',
  String numberOfHorses = '10',
  String pace = '34.5-34.8',
  String agari = '34.0',
}) {
  return HorseRaceRecord(
    horseId: 'h',
    raceId: 'r',
    date: '2025/01/01',
    venue: '5東京8',
    weather: '晴',
    raceNumber: '11',
    raceName: 'テストS(GIII)',
    numberOfHorses: numberOfHorses,
    frameNumber: '1',
    horseNumber: '1',
    odds: '5.0',
    popularity: '4',
    rank: '3',
    jockey: 'J',
    jockeyId: 'jid',
    carriedWeight: '55',
    distance: distance,
    trackCondition: '良',
    time: '1:34.0',
    margin: '0.2',
    cornerPassage: cornerPassage,
    pace: pace,
    agari: agari,
    horseWeight: '470(0)',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

void main() {
  group('距離帯', () {
    test('境界の振り分け', () {
      expect(RaceFinishCalculator.bandOfMeters(1200), SimDistanceBand.sprint);
      expect(RaceFinishCalculator.bandOfMeters(1400), SimDistanceBand.sprint);
      expect(RaceFinishCalculator.bandOfMeters(1600), SimDistanceBand.mile);
      expect(RaceFinishCalculator.bandOfMeters(1800), SimDistanceBand.mile);
      expect(RaceFinishCalculator.bandOfMeters(2000), SimDistanceBand.middle);
      expect(RaceFinishCalculator.bandOfMeters(2200), SimDistanceBand.middle);
      expect(RaceFinishCalculator.bandOfMeters(2400), SimDistanceBand.long);
      expect(RaceFinishCalculator.bandOfMeters(3200), SimDistanceBand.long);
    });

    test('距離文字列からの距離', () {
      expect(RaceFinishCalculator.distanceMetersOfText('芝1600'), 1600);
      expect(RaceFinishCalculator.distanceMetersOfText('ダ1200'), 1200);
      expect(RaceFinishCalculator.distanceMetersOfText(''), isNull);
    });
  });

  group('定数表', () {
    test('芝・中距離・ミドルの値', () {
      final c = RaceFinishCalculator.constantsFor(
          SimSurface.turf, SimDistanceBand.mile, SimPace.middle);
      expect(c.carryOver, 0.22);
      expect(c.midSpreadMeters, 25.0);
      expect(c.goalSpreadMeters, 40.0);
      expect(c.kickSlopeSeconds, 0.85);
    });

    test('ハイペースほど残る割合が小さく、ダートは芝より大きい', () {
      double turf(SimPace p) => RaceFinishCalculator
          .constantsFor(SimSurface.turf, SimDistanceBand.mile, p)
          .carryOver;
      expect(turf(SimPace.slow) > turf(SimPace.middle), isTrue);
      expect(turf(SimPace.middle) > turf(SimPace.high), isTrue);
      expect(
        RaceFinishCalculator.constantsFor(
                    SimSurface.dirt, SimDistanceBand.mile, SimPace.high)
                .carryOver >
            turf(SimPace.high),
        isTrue,
      );
    });

    test('割引きの傾きは短距離ほど大きい(芝・ハイ)', () {
      double slope(SimDistanceBand b) => RaceFinishCalculator
          .constantsFor(SimSurface.turf, b, SimPace.high)
          .kickSlopeSeconds;
      expect(slope(SimDistanceBand.sprint), 1.11);
      expect(slope(SimDistanceBand.middle), 0.28);
      expect(slope(SimDistanceBand.sprint) > slope(SimDistanceBand.mile), isTrue);
      expect(slope(SimDistanceBand.mile) > slope(SimDistanceBand.middle), isTrue);
    });

    test('ダートの中距離以上では傾きが負になる', () {
      expect(
        RaceFinishCalculator.constantsFor(
                SimSurface.dirt, SimDistanceBand.mile, SimPace.high)
            .kickSlopeSeconds,
        lessThan(0.0),
      );
    });

    test('全24通りが引ける', () {
      for (final s in SimSurface.values) {
        for (final b in SimDistanceBand.values) {
          for (final p in SimPace.values) {
            final c = RaceFinishCalculator.constantsFor(s, b, p);
            expect(c.midSpreadMeters, greaterThan(0.0));
            expect(c.goalSpreadMeters, greaterThan(0.0));
            expect(c.carryOver, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });
  });

  group('読み取りヘルパー', () {
    test('後半3Fの取り出し', () {
      expect(RaceFinishCalculator.raceLast3F('34.3-33.4'), 33.4);
      expect(RaceFinishCalculator.raceLast3F(''), isNull);
      expect(RaceFinishCalculator.raceLast3F('34.3'), isNull);
    });

    test('最終コーナーの通過順位率', () {
      expect(RaceFinishCalculator.lastCornerRate('5-9-7-12', '18'),
          closeTo(12 / 18, 1e-9));
      expect(RaceFinishCalculator.lastCornerRate('2-2', '10'), closeTo(0.2, 1e-9));
      expect(RaceFinishCalculator.lastCornerRate('', '10'), isNull);
      expect(RaceFinishCalculator.lastCornerRate('5-5', '0'), isNull);
    });

    test('距離文字列からの馬場種別', () {
      expect(RaceFinishCalculator.surfaceOfDistanceText('芝1600'),
          SimSurface.turf);
      expect(RaceFinishCalculator.surfaceOfDistanceText('ダ1200'),
          SimSurface.dirt);
      expect(RaceFinishCalculator.surfaceOfDistanceText('障3380'), isNull);
    });
  });

  group('末脚', () {
    test('中団の馬は割引きが0で、生の末脚がそのまま出る', () {
      final k = RaceFinishCalculator.calculateKick([rec()]);
      expect(k.sampleCount, 1);
      expect(k.rawKickSeconds, closeTo(0.8, 1e-6));
      expect(k.confidence, closeTo(1 / 3, 1e-9));
      expect(k.kickSeconds, closeTo(0.8 * 0.5 * (1 / 3), 1e-6));
    });

    test('最後方だった走は、その走の距離帯の傾きで割り引かれる', () {
      // 芝1600(中距離)・ミドルの傾き0.85 × (1.0 - 0.5) = 0.425 を引く
      final k = RaceFinishCalculator.calculateKick(
          [rec(cornerPassage: '10-10', numberOfHorses: '10')]);
      expect(k.rawKickSeconds, closeTo(0.8 - 0.425, 1e-6));
    });

    test('同じ内容でも短距離の走はより強く割り引かれる', () {
      // 芝1200(短距離)・ミドルの傾き0.81。ミドルでは中距離(0.85)よりわずかに小さい
      final sprint = RaceFinishCalculator.calculateKick(
          [rec(distance: '芝1200', cornerPassage: '10-10', numberOfHorses: '10')]);
      expect(sprint.rawKickSeconds, closeTo(0.8 - 0.81 * 0.5, 1e-6));

      // 芝2000(中長距離)・ミドルの傾き0.42。割引きが小さくなる
      final middle = RaceFinishCalculator.calculateKick(
          [rec(distance: '芝2000', cornerPassage: '10-10', numberOfHorses: '10')]);
      expect(middle.rawKickSeconds, closeTo(0.8 - 0.42 * 0.5, 1e-6));
      expect(middle.rawKickSeconds > sprint.rawKickSeconds, isTrue);
    });

    test('3走あれば信頼度は1.0になる', () {
      final k = RaceFinishCalculator.calculateKick([rec(), rec(), rec()]);
      expect(k.sampleCount, 3);
      expect(k.confidence, 1.0);
      expect(k.kickSeconds, closeTo(0.8 * 0.5, 1e-6));
    });

    test('必要な値が欠けている走は数えない', () {
      expect(RaceFinishCalculator.calculateKick([rec(agari: '')]).sampleCount, 0);
      expect(RaceFinishCalculator.calculateKick([rec(pace: '')]).sampleCount, 0);
      expect(
          RaceFinishCalculator.calculateKick([rec(distance: '障3380')])
              .sampleCount,
          0);
      expect(RaceFinishCalculator.calculateKick(const []).sampleCount, 0);
    });
  });

  group('ペースの自動判定', () {
    Map<String, double> nige() =>
        {'逃げ': 0.6, '先行': 0.2, '差し': 0.1, '追込': 0.1};
    Map<String, double> senko() =>
        {'逃げ': 0.1, '先行': 0.7, '差し': 0.1, '追込': 0.1};
    Map<String, double> sashi() =>
        {'逃げ': 0.0, '先行': 0.1, '差し': 0.6, '追込': 0.3};

    test('逃げたい馬がいなければスロー', () {
      final field = List.generate(10, (_) => sashi());
      expect(
        RaceFinishCalculator.predictPace(
            styleDistributions: field,
            distanceMeters: 2000,
            surface: SimSurface.turf),
        SimPace.slow,
      );
    });

    test('逃げたい馬が3頭の短距離はハイ', () {
      final field = [nige(), nige(), nige(), ...List.generate(7, (_) => sashi())];
      expect(
        RaceFinishCalculator.predictPace(
            styleDistributions: field,
            distanceMeters: 1200,
            surface: SimSurface.turf),
        SimPace.high,
      );
    });

    test('先行馬が多いとペースが上がる', () {
      final field = [nige(), ...List.generate(4, (_) => senko()),
        ...List.generate(7, (_) => sashi())];
      expect(
        RaceFinishCalculator.predictPace(
            styleDistributions: field,
            distanceMeters: 1600,
            surface: SimSurface.turf),
        SimPace.middle,
      );
    });

    test('ダートは同じ面子でも芝より速くなる', () {
      final field = [nige(), ...List.generate(9, (_) => sashi())];
      expect(
        RaceFinishCalculator.predictPace(
            styleDistributions: field,
            distanceMeters: 1800,
            surface: SimSurface.turf),
        SimPace.slow,
      );
      expect(
        RaceFinishCalculator.predictPace(
            styleDistributions: field,
            distanceMeters: 1800,
            surface: SimSurface.dirt),
        SimPace.middle,
      );
    });

    test('出走馬がいなければミドル', () {
      expect(
        RaceFinishCalculator.predictPace(
            styleDistributions: const [],
            distanceMeters: 1600,
            surface: SimSurface.turf),
        SimPace.middle,
      );
    });
  });

  group('ゴールの組み立て', () {
    test('位置・末脚・能力が足し合わされ、能力は上限で頭打ちになる', () {
      final v = RaceFinishCalculator.goalScore(
        frontScoreAt4c: 1.0,
        carryOver: 0.30,
        kickSeconds: 0.2,
        meanKickSeconds: 0.0,
        abilityScore: 1.0, // 0.75 に丸められる
      );
      expect(v, closeTo(0.30 + (0.0 - 0.2) * 16.7 / 16.0 + 0.75, 1e-9));
    });

    test('残る割合が小さいほど前の貯金が消える', () {
      double at(double carry) => RaceFinishCalculator.goalScore(
            frontScoreAt4c: 2.0,
            carryOver: carry,
            kickSeconds: 0.0,
            meanKickSeconds: 0.0,
            abilityScore: 0.0,
          );
      expect(at(0.60), closeTo(1.2, 1e-9));
      expect(at(0.16), closeTo(0.32, 1e-9));
    });
  });

  group('広がりの倍率', () {
    test('目標に合わせた倍率を返す', () {
      expect(
        RaceFinishCalculator.spreadScale(
            maxFrontScore: 2.0, targetSpreadMeters: 25.0),
        closeTo(25.0 / 32.0, 1e-9),
      );
    });

    test('上限・下限で頭打ちになる', () {
      expect(
        RaceFinishCalculator.spreadScale(
            maxFrontScore: 0.5, targetSpreadMeters: 25.0),
        RaceFinishCalculator.spreadScaleMax,
      );
      expect(
        RaceFinishCalculator.spreadScale(
            maxFrontScore: 10.0, targetSpreadMeters: 25.0),
        RaceFinishCalculator.spreadScaleMin,
      );
    });

    test('広がりが0なら倍率1.0', () {
      expect(
        RaceFinishCalculator.spreadScale(
            maxFrontScore: 0.0, targetSpreadMeters: 25.0),
        1.0,
      );
    });
  });
}
