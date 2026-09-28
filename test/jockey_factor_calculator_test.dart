// test/jockey_factor_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/jockey_factor_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 展開シミュ騎手要素Step1: 騎手要素の計算ロジックの検証 (v.2026.9.29+26092901)

PredictionHorseDetail _horse({
  required String horseId,
  required int horseNumber,
  required String jockeyId,
  String? previousJockeyId,
}) {
  return PredictionHorseDetail(
    horseId: horseId,
    horseNumber: horseNumber,
    gateNumber: horseNumber,
    horseName: 'テスト馬$horseNumber',
    sexAndAge: '牡4',
    jockey: 'テスト騎手$jockeyId',
    jockeyId: jockeyId,
    carriedWeight: 57.0,
    trainerName: 'テスト調教師',
    trainerAffiliation: '美浦',
    isScratched: false,
    previousJockeyId: previousJockeyId,
  );
}

HorseRaceRecord _record({
  required String horseId,
  required String raceId,
  required String jockeyId,
  required String rank,
}) {
  return HorseRaceRecord(
    horseId: horseId,
    raceId: raceId,
    date: '2026/01/01',
    venue: '1東京1',
    weather: '晴',
    raceNumber: '11',
    raceName: 'テスト',
    numberOfHorses: '16',
    frameNumber: '1',
    horseNumber: '1',
    odds: '5.0',
    popularity: '3',
    rank: rank,
    jockey: 'テスト',
    jockeyId: jockeyId,
    carriedWeight: '57',
    distance: '芝1600',
    trackCondition: '良',
    time: '1:34.0',
    margin: '0.1',
    cornerPassage: '3-3',
    pace: '35.0-34.0',
    agari: '34.0',
    horseWeight: '480(0)',
    winnerOrSecondHorse: 'テスト',
    prizeMoney: '0',
  );
}

List<HorseRaceRecord> _records(
    String horseId, String jockeyId, List<String> ranks) {
  final list = <HorseRaceRecord>[];
  for (var i = 0; i < ranks.length; i++) {
    list.add(_record(
      horseId: horseId,
      raceId: '${horseId}_$i',
      jockeyId: jockeyId,
      rank: ranks[i],
    ));
  }
  return list;
}

JockeyStats _stats(String id, {required int races, required int wins}) {
  final overall = FactorStats()
    ..raceCount = races
    ..winCount = wins
    ..placeCount = wins
    ..showCount = wins;
  return JockeyStats(
    jockeyName: 'テスト騎手$id',
    jockeyId: id,
    overallStats: overall,
    popularHorseStats: FactorStats(),
    unpopularHorseStats: FactorStats(),
  );
}

void main() {
  group('JockeyFactorCalculator', () {
    test('全馬が同じ条件なら positionBias は全馬0', () {
      final horses = [
        _horse(horseId: 'A', horseNumber: 1, jockeyId: 'J1', previousJockeyId: 'J1'),
        _horse(horseId: 'B', horseNumber: 2, jockeyId: 'J1', previousJockeyId: 'J1'),
      ];
      final records = {
        'A': _records('A', 'J1', ['1', '2', '3']),
        'B': _records('B', 'J1', ['1', '2', '3']),
      };
      final result = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {'J1': _stats('J1', races: 40, wins: 6)},
      );
      expect(result['1']!.positionBias, closeTo(0.0, 1e-9));
      expect(result['2']!.positionBias, closeTo(0.0, 1e-9));
      expect(result['1']!.rideType, JockeyRideType.continued);
    });

    test('継続騎乗で実績のある馬は、初騎乗の馬より有利（positionBiasが小さい）', () {
      final horses = [
        _horse(horseId: 'A', horseNumber: 1, jockeyId: 'J1', previousJockeyId: 'J1'),
        _horse(horseId: 'B', horseNumber: 2, jockeyId: 'J1', previousJockeyId: 'J9'),
        _horse(horseId: 'C', horseNumber: 3, jockeyId: 'J1', previousJockeyId: 'J9'),
      ];
      final records = {
        'A': _records('A', 'J1', ['1', '2', '3', '1', '4']),
        'B': _records('B', 'J9', ['5', '6']),
        'C': _records('C', 'J9', ['5', '6']),
      };
      final result = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {'J1': _stats('J1', races: 40, wins: 6)},
      );
      expect(result['1']!.rideType, JockeyRideType.continued);
      expect(result['2']!.rideType, JockeyRideType.firstRide);
      expect(result['1']!.comboRatio, greaterThan(0.0));
      expect(result['2']!.comboRatio, 0.0);
      expect(result['1']!.positionBias, lessThan(0.0));
      expect(result['2']!.positionBias, greaterThan(0.0));
    });

    test('3つの合計は上限±0.31に収まる', () {
      final horses = [
        _horse(horseId: 'X', horseNumber: 1, jockeyId: 'S', previousJockeyId: 'W'),
        _horse(horseId: 'Y', horseNumber: 2, jockeyId: 'W', previousJockeyId: 'W'),
        _horse(horseId: 'Z', horseNumber: 3, jockeyId: 'W', previousJockeyId: 'W'),
      ];
      final records = {
        'X': [
          ..._records('X', 'W', ['5']),
          ..._records('X', 'S', ['1', '1', '1']),
        ],
        'Y': _records('Y', 'W', ['1', '2', '3']),
        'Z': _records('Z', 'W', ['1', '2', '3']),
      };
      final result = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {
          'S': _stats('S', races: 40, wins: 12),
          'W': _stats('W', races: 40, wins: 1),
        },
      );
      expect(result['1']!.rideType, JockeyRideType.changed);
      expect(result['1']!.positionBias, closeTo(-JockeyFactorCalculator.totalMaxBias, 1e-9));
      for (final f in result.values) {
        expect(f.positionBias.abs(), lessThanOrEqualTo(JockeyFactorCalculator.totalMaxBias + 1e-9));
      }
    });

    test('乗り替わりの方向: 実績の高い騎手へは+1、低い騎手へは-1', () {
      final horses = [
        _horse(horseId: 'X', horseNumber: 1, jockeyId: 'S', previousJockeyId: 'W'),
        _horse(horseId: 'Y', horseNumber: 2, jockeyId: 'W', previousJockeyId: 'S'),
      ];
      final records = {
        'X': _records('X', 'W', ['3']),
        'Y': _records('Y', 'S', ['3']),
      };
      final result = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {
          'S': _stats('S', races: 40, wins: 12),
          'W': _stats('W', races: 40, wins: 1),
        },
      );
      expect(result['1']!.rideType, JockeyRideType.firstRide);
      expect(result['2']!.rideType, JockeyRideType.firstRide);
      expect(result['1']!.changeDirection, closeTo(1.0, 1e-9));
      expect(result['2']!.changeDirection, closeTo(-1.0, 1e-9));
      expect(result['1']!.positionBias, lessThan(result['2']!.positionBias));
    });

    test('過去走が無い馬は相性の評価対象外・乗り替わり方向なし', () {
      final horses = [
        _horse(horseId: 'P', horseNumber: 1, jockeyId: 'J1'),
        _horse(horseId: 'Q', horseNumber: 2, jockeyId: 'J1', previousJockeyId: 'J1'),
      ];
      final records = {
        'P': <HorseRaceRecord>[],
        'Q': _records('Q', 'J1', ['1', '2', '3']),
      };
      final result = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {'J1': _stats('J1', races: 40, wins: 6)},
      );
      expect(result['1']!.hasCombo, isFalse);
      expect(result['1']!.rideType, JockeyRideType.unknown);
      expect(result['1']!.changeDirection, isNull);
      expect(result['1']!.comboRatio, 0.0);
      expect(result['2']!.hasCombo, isTrue);
    });

    test('騎手統計が空でも例外にならず、強さは対象外になる', () {
      final horses = [
        _horse(horseId: 'A', horseNumber: 1, jockeyId: 'J1', previousJockeyId: 'J1'),
      ];
      final result = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: {'A': _records('A', 'J1', ['1', '2'])},
        jockeyStats: const {},
      );
      expect(result['1']!.hasStrength, isFalse);
      expect(result['1']!.strengthRatio, 0.0);
      expect(result['1']!.strengthIsLowSample, isTrue);
    });

    test('騎手統計の件数が少ないと低サンプル、多いと通常', () {
      final horses = [
        _horse(horseId: 'A', horseNumber: 1, jockeyId: 'J1', previousJockeyId: 'J1'),
      ];
      final records = {'A': _records('A', 'J1', ['1', '2', '3'])};
      final few = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {'J1': _stats('J1', races: 3, wins: 1)},
      );
      final many = JockeyFactorCalculator.calculate(
        horses: horses,
        allPastRecords: records,
        jockeyStats: {'J1': _stats('J1', races: 40, wins: 6)},
      );
      expect(few['1']!.strengthIsLowSample, isTrue);
      expect(many['1']!.strengthIsLowSample, isFalse);
    });

    test('出走馬が空なら空のマップ', () {
      final result = JockeyFactorCalculator.calculate(
        horses: const [],
        allPastRecords: const {},
        jockeyStats: const {},
      );
      expect(result, isEmpty);
    });
  });
}
