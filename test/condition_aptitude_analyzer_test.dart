// test/condition_aptitude_analyzer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';

HorseRaceRecord rec({
  String rank = '5',
  String distance = '芝1600',
  String venue = '5東京8',
  String trackCondition = '良',
  String raceName = '3歳未勝利',
  String popularity = '4',
  String weather = '晴',
  String horseWeight = '470(0)',
  String cornerPassage = '5-5',
  String numberOfHorses = '16',
  String agari = '34.0',
}) {
  return HorseRaceRecord(
    horseId: 'h',
    raceId: 'r',
    date: '2025/01/01',
    venue: venue,
    weather: weather,
    raceNumber: '11',
    raceName: raceName,
    numberOfHorses: numberOfHorses,
    frameNumber: '1',
    horseNumber: '1',
    odds: '5.0',
    popularity: popularity,
    rank: rank,
    jockey: 'J',
    jockeyId: 'jid',
    carriedWeight: '55',
    distance: distance,
    trackCondition: trackCondition,
    time: '1:34.0',
    margin: '0.2',
    cornerPassage: cornerPassage,
    pace: '',
    agari: agari,
    horseWeight: horseWeight,
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

AptitudeCategory? catOf(ConditionAptitude a, String name) {
  for (final c in a.categories) {
    if (c.name == name) return c;
  }
  return null;
}

void main() {
  group('helpers', () {
    test('surfaceOf', () {
      expect(ConditionAptitudeAnalyzer.surfaceOf('芝1600'), '芝');
      expect(ConditionAptitudeAnalyzer.surfaceOf('ダ1200'), 'ダ');
      expect(ConditionAptitudeAnalyzer.surfaceOf('障3380'), '障');
      expect(ConditionAptitudeAnalyzer.surfaceOf('1600'), isNull);
    });

    test('distanceMetersOf', () {
      expect(ConditionAptitudeAnalyzer.distanceMetersOf('芝1600'), 1600);
      expect(ConditionAptitudeAnalyzer.distanceMetersOf('ダ1200'), 1200);
      expect(ConditionAptitudeAnalyzer.distanceMetersOf('芝'), isNull);
    });

    test('distanceBandLabel boundaries', () {
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(1300), '〜1300');
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(1400), '1400-1600');
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(1600), '1400-1600');
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(1700), '1700-2000');
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(2000), '1700-2000');
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(2400), '2100-2400');
      expect(ConditionAptitudeAnalyzer.distanceBandLabel(2500), '2500〜');
    });

    test('distanceLabelOf skips 障', () {
      expect(ConditionAptitudeAnalyzer.distanceLabelOf(rec(distance: '芝1600')), '芝1400-1600');
      expect(ConditionAptitudeAnalyzer.distanceLabelOf(rec(distance: 'ダ1200')), 'ダ〜1300');
      expect(ConditionAptitudeAnalyzer.distanceLabelOf(rec(distance: '障3380')), isNull);
    });

    test('weightDeltaOf / weightDeltaBand', () {
      expect(ConditionAptitudeAnalyzer.weightDeltaOf('438(-6)'), -6);
      expect(ConditionAptitudeAnalyzer.weightDeltaOf('470(0)'), 0);
      expect(ConditionAptitudeAnalyzer.weightDeltaOf('470(+10)'), 10);
      expect(ConditionAptitudeAnalyzer.weightDeltaOf('470'), isNull);
      expect(ConditionAptitudeAnalyzer.weightDeltaBand('438(-6)'), 'やや減');
      expect(ConditionAptitudeAnalyzer.weightDeltaBand('438(-8)'), '大幅減');
      expect(ConditionAptitudeAnalyzer.weightDeltaBand('470(0)'), '±');
      expect(ConditionAptitudeAnalyzer.weightDeltaBand('470(+5)'), 'やや増');
      expect(ConditionAptitudeAnalyzer.weightDeltaBand('470(+10)'), '大幅増');
      expect(ConditionAptitudeAnalyzer.weightDeltaBand('470'), isNull);
    });

    test('popularityBand', () {
      expect(ConditionAptitudeAnalyzer.popularityBand('1'), '1-3番人気');
      expect(ConditionAptitudeAnalyzer.popularityBand('3'), '1-3番人気');
      expect(ConditionAptitudeAnalyzer.popularityBand('5'), '4-6番人気');
      expect(ConditionAptitudeAnalyzer.popularityBand('9'), '7番人気〜');
      expect(ConditionAptitudeAnalyzer.popularityBand(''), isNull);
    });

    test('directionOf', () {
      expect(ConditionAptitudeAnalyzer.directionOf('5東京8'), '左');
      expect(ConditionAptitudeAnalyzer.directionOf('1中山1'), '右');
      expect(ConditionAptitudeAnalyzer.directionOf('3中京2'), '左');
      expect(ConditionAptitudeAnalyzer.directionOf(''), isNull);
    });

    test('gradeClassOf', () {
      expect(ConditionAptitudeAnalyzer.gradeClassOf('天皇賞(GI)'), 'G1');
      expect(ConditionAptitudeAnalyzer.gradeClassOf('AA(GII)'), 'G2');
      expect(ConditionAptitudeAnalyzer.gradeClassOf('BB(GIII)'), 'G3');
      expect(ConditionAptitudeAnalyzer.gradeClassOf('CCオープン OP'), 'OP');
      expect(ConditionAptitudeAnalyzer.gradeClassOf('3歳未勝利'), '条件');
    });

    test('rankTallyOf counts', () {
      final t = ConditionAptitudeAnalyzer.rankTallyOf([
        rec(rank: '1'),
        rec(rank: '2'),
        rec(rank: '3'),
        rec(rank: '5'),
        rec(rank: '中'),
      ]);
      expect(t.first, 1);
      expect(t.second, 1);
      expect(t.third, 1);
      expect(t.out, 2);
      expect(t.total, 5);
      expect(t.winRate, closeTo(0.2, 1e-9));
      expect(t.showRate, closeTo(0.6, 1e-9));
    });
  });

  group('analyze', () {
    test('distance category: sort by winRate, best flag, reference', () {
      final records = <HorseRaceRecord>[
        rec(distance: '芝1600', rank: '1'),
        rec(distance: '芝1600', rank: '1'),
        rec(distance: '芝1600', rank: '3'),
        rec(distance: 'ダ1200', rank: '1'),
        rec(distance: 'ダ1200', rank: '2'),
        rec(distance: '芝2400', rank: '1'),
      ];
      final a = ConditionAptitudeAnalyzer.analyze(records);
      final dist = catOf(a, '距離')!;
      // main: 芝1400-1600 (win .667) → best, ダ〜1300 (win .5)
      expect(dist.values[0].label, '芝1400-1600');
      expect(dist.values[0].isBest, isTrue);
      expect(dist.values[0].isReference, isFalse);
      expect(dist.values[1].label, 'ダ〜1300');
      expect(dist.values[1].isBest, isFalse);
      // reference last: 芝2100-2400 (1走)
      final last = dist.values.last;
      expect(last.label, '芝2100-2400');
      expect(last.isReference, isTrue);
      expect(last.isBest, isFalse);
    });

    test('best requires a win in the top value', () {
      final records = <HorseRaceRecord>[
        rec(trackCondition: '良', rank: '5'),
        rec(trackCondition: '良', rank: '4'),
        rec(trackCondition: '重', rank: '8'),
        rec(trackCondition: '重', rank: '6'),
      ];
      final a = ConditionAptitudeAnalyzer.analyze(records);
      final baba = catOf(a, '馬場')!;
      for (final v in baba.values) {
        expect(v.isBest, isFalse);
      }
    });

    test('overall tally', () {
      final records = <HorseRaceRecord>[
        rec(rank: '1'),
        rec(rank: '4'),
      ];
      final a = ConditionAptitudeAnalyzer.analyze(records);
      expect(a.overall.total, 2);
      expect(a.overall.first, 1);
      expect(a.overall.winRate, closeTo(0.5, 1e-9));
    });

    test('empty records → empty categories', () {
      final a = ConditionAptitudeAnalyzer.analyze(<HorseRaceRecord>[]);
      expect(a.overall.total, 0);
      expect(a.categories, isEmpty);
    });
  });
}
