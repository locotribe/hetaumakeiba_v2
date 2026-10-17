// test/condition_aptitude_analyzer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

HorseRaceRecord rec({
  String raceId = 'r',
  String date = '2025/01/01',
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
  String jockey = 'J',
  String jockeyId = 'jid',
}) {
  return HorseRaceRecord(
    horseId: 'h',
    raceId: raceId,
    date: date,
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
    jockey: jockey,
    jockeyId: jockeyId,
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

int catIndex(ConditionAptitude a, String name) {
  return a.categories.indexWhere((c) => c.name == name);
}

TrackConditionRecord tcRec(int id, {double? cushion, double? dirtGoal}) {
  return TrackConditionRecord(
    trackConditionId: id,
    date: '2025-01-01',
    weekDay: 'sa',
    cushionValue: cushion,
    moistureDirtGoal: dirtGoal,
  );
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

    test('distanceLabelOf skips 障（ヒートマップ用の距離帯は従来どおり）', () {
      expect(ConditionAptitudeAnalyzer.distanceLabelOf(rec(distance: '芝1600')), '芝1400-1600');
      expect(ConditionAptitudeAnalyzer.distanceLabelOf(rec(distance: 'ダ1200')), 'ダ〜1300');
      expect(ConditionAptitudeAnalyzer.distanceLabelOf(rec(distance: '障3380')), isNull);
    });

    test('distanceExactLabelOf: 経験距離のラベル・障と不明は null', () {
      expect(ConditionAptitudeAnalyzer.distanceExactLabelOf(rec(distance: '芝1600')), '芝1600');
      expect(ConditionAptitudeAnalyzer.distanceExactLabelOf(rec(distance: 'ダ1200')), 'ダ1200');
      expect(ConditionAptitudeAnalyzer.distanceExactLabelOf(rec(distance: '障3380')), isNull);
      expect(ConditionAptitudeAnalyzer.distanceExactLabelOf(rec(distance: '1600')), isNull);
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

    // [追加] 好走条件の改良 Step1: 取消・除外・空欄は数えない（中止は着外） (v.2026.10.17+26101711)
    test('rankTallyOf: 取消・除外・空欄は数えない', () {
      final t = ConditionAptitudeAnalyzer.rankTallyOf([
        rec(rank: '1'),
        rec(rank: '取'),
        rec(rank: '除'),
        rec(rank: ''),
        rec(rank: '中'),
      ]);
      expect(t.first, 1);
      expect(t.out, 1);
      expect(t.total, 2);
    });

    test('debutRecordOf: 日付がいちばん古い走・読めない日付は除く・空なら null', () {
      final records = <HorseRaceRecord>[
        rec(raceId: 'b', date: '2025/03/01'),
        rec(raceId: 'a', date: '2024/06/09'),
        rec(raceId: 'x', date: '不明'),
        rec(raceId: 'c', date: '2025/10/01'),
      ];
      expect(ConditionAptitudeAnalyzer.debutRecordOf(records)!.raceId, 'a');
      expect(ConditionAptitudeAnalyzer.debutRecordOf(<HorseRaceRecord>[]), isNull);
      expect(ConditionAptitudeAnalyzer.debutRecordOf([rec(date: '不明')]), isNull);
    });
  });

  group('analyze', () {
    test('distance category: 経験距離ごと・芝→ダの距離順・得意と参考', () {
      final records = <HorseRaceRecord>[
        rec(distance: '芝1600', rank: '1'),
        rec(distance: '芝1600', rank: '1'),
        rec(distance: '芝1600', rank: '3'),
        rec(distance: 'ダ1200', rank: '1'),
        rec(distance: 'ダ1200', rank: '2'),
        rec(distance: '芝2400', rank: '1'),
        rec(distance: '芝1200', rank: '5'),
        rec(distance: '芝1200', rank: '6'),
        rec(distance: '障3380', rank: '1'),
      ];
      final a = ConditionAptitudeAnalyzer.analyze(records);
      final dist = catOf(a, '距離')!;
      expect(dist.values.map((v) => v.label).toList(), ['芝1200', '芝1600', '芝2400', 'ダ1200']);
      // 得意は2走以上で勝率最上位（芝1600 = 2/3）
      expect(dist.values[1].isBest, isTrue);
      expect(dist.values.where((v) => v.isBest).length, 1);
      // 1走だけの芝2400は並びはそのまま・参考
      expect(dist.values[2].isReference, isTrue);
      expect(dist.values[2].isBest, isFalse);
      expect(dist.values[0].isReference, isFalse);
      expect(dist.values[3].tally.total, 2);
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
      final dist = catOf(a, '距離')!;
      for (final v in dist.values) {
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

    // [追加] 好走条件の改良 Step1: 取消・除外の走はどのカテゴリにも入れない (v.2026.10.17+26101711)
    test('analyze: 取消・除外の走はどのカテゴリにも入れない', () {
      final records = <HorseRaceRecord>[
        rec(rank: '1', weather: '晴'),
        rec(rank: '3', weather: '晴'),
        rec(rank: '取', weather: '雨'),
        rec(rank: '除', distance: 'ダ1200', weather: '曇'),
      ];
      final a = ConditionAptitudeAnalyzer.analyze(records);
      expect(a.overall.total, 2);
      expect(catOf(a, '天候')!.values.map((v) => v.label).toList(), ['晴']);
      expect(catOf(a, '芝/ダ')!.values.map((v) => v.label).toList(), ['芝']);
      expect(catOf(a, '含水率(ダ・ゴール前)'), isNull);
    });

    test('empty records → empty categories', () {
      final a = ConditionAptitudeAnalyzer.analyze(<HorseRaceRecord>[]);
      expect(a.overall.total, 0);
      expect(a.categories, isEmpty);
    });
  });

  group('jockey category', () {
    final records = <HorseRaceRecord>[
      rec(date: '2025/01/01', rank: '1', jockeyId: 'A', jockey: '戸崎'),
      rec(date: '2025/03/01', rank: '4', jockeyId: 'A', jockey: '戸崎圭'),
      rec(date: '2024/12/01', rank: '2', jockeyId: 'A', jockey: '戸崎'),
      rec(date: '2025/02/01', rank: '1', jockeyId: 'B', jockey: 'ルメール'),
      rec(date: '2025/02/15', rank: '1', jockeyId: 'B', jockey: 'ルメール'),
      rec(date: '2025/04/01', rank: '3', jockeyId: '', jockey: '武豊'),
    ];

    test('騎乗回数の多い順・表示名は最新の騎乗・得意と参考・脚質の直後', () {
      final a = ConditionAptitudeAnalyzer.analyze(records);
      final j = catOf(a, '騎手')!;
      expect(j.values.map((v) => v.label).toList(), ['戸崎圭', 'ルメール', '武豊']);
      expect(j.values[0].tally.total, 3);
      expect(j.values[1].isBest, isTrue);
      expect(j.values[0].isBest, isFalse);
      expect(j.values[2].isReference, isTrue);
      for (final v in j.values) {
        expect(v.isCurrent, isFalse);
      }
      expect(catIndex(a, '騎手'), catIndex(a, '脚質') + 1);
    });

    test('今回の騎手に今回印（IDで照合、IDが空なら名前で照合）', () {
      final byId = catOf(ConditionAptitudeAnalyzer.analyze(records, currentJockeyId: 'B', currentJockeyName: 'ルメール'), '騎手')!;
      expect(byId.values.where((v) => v.isCurrent).map((v) => v.label).toList(), ['ルメール']);
      final byName = catOf(ConditionAptitudeAnalyzer.analyze(records, currentJockeyId: '', currentJockeyName: '武豊'), '騎手')!;
      expect(byName.values.where((v) => v.isCurrent).map((v) => v.label).toList(), ['武豊']);
    });
  });

  // [追加] 好走条件の改良 Step4: 並べ替え (v.2026.10.18+26101802)
  group('sortedBy', () {
    // 馬場: 良 4走[1-0-0-3]（勝率25%・複勝率25%）、重 2走[0-1-1-0]（勝率0%・複勝率100%）、稍 1走[1-0-0-0]（参考）
    final records = <HorseRaceRecord>[
      rec(trackCondition: '良', rank: '1'),
      rec(trackCondition: '良', rank: '5'),
      rec(trackCondition: '良', rank: '6'),
      rec(trackCondition: '良', rank: '7'),
      rec(trackCondition: '重', rank: '2'),
      rec(trackCondition: '重', rank: '3'),
      rec(trackCondition: '稍', rank: '1'),
    ];

    test('標準は今の並びのまま', () {
      final a = ConditionAptitudeAnalyzer.analyze(records);
      expect(identical(ConditionAptitudeAnalyzer.sortedBy(a, AptitudeSort.standard), a), isTrue);
      expect(catOf(a, '馬場')!.values.map((v) => v.label).toList(), ['良', '重', '稍']);
    });

    test('複勝率順・2走未満は下・得意の印は変わらない', () {
      final a = ConditionAptitudeAnalyzer.sortedBy(
          ConditionAptitudeAnalyzer.analyze(records), AptitudeSort.showRate);
      final baba = catOf(a, '馬場')!;
      expect(baba.values.map((v) => v.label).toList(), ['重', '良', '稍']);
      expect(baba.values.where((v) => v.isBest).map((v) => v.label).toList(), ['良']);
      expect(baba.values[2].isReference, isTrue);
      expect(a.overall.total, 7);
    });

    test('出走数順は距離など独自の並びのカテゴリにも効く', () {
      final a = ConditionAptitudeAnalyzer.sortedBy(
          ConditionAptitudeAnalyzer.analyze(<HorseRaceRecord>[
            rec(distance: '芝1200', rank: '1'),
            rec(distance: '芝1600', rank: '4'),
            rec(distance: '芝1600', rank: '5'),
            rec(distance: '芝1600', rank: '6'),
            rec(distance: 'ダ1200', rank: '2'),
            rec(distance: 'ダ1200', rank: '1'),
          ]),
          AptitudeSort.starts);
      expect(catOf(a, '距離')!.values.map((v) => v.label).toList(), ['芝1600', 'ダ1200', '芝1200']);
    });
  });

  group('track condition categories', () {
    test('cushionBand 6段の境界 / moistureBand', () {
      expect(ConditionAptitudeAnalyzer.cushionBand(10.1), '10以上');
      expect(ConditionAptitudeAnalyzer.cushionBand(10.0), '10以上');
      expect(ConditionAptitudeAnalyzer.cushionBand(9.9), '9.9-9.5');
      expect(ConditionAptitudeAnalyzer.cushionBand(9.5), '9.9-9.5');
      expect(ConditionAptitudeAnalyzer.cushionBand(9.4), '9.4-9');
      expect(ConditionAptitudeAnalyzer.cushionBand(9.0), '9.4-9');
      expect(ConditionAptitudeAnalyzer.cushionBand(8.9), '8.9-8.5');
      expect(ConditionAptitudeAnalyzer.cushionBand(8.5), '8.9-8.5');
      expect(ConditionAptitudeAnalyzer.cushionBand(8.4), '8.4-8');
      expect(ConditionAptitudeAnalyzer.cushionBand(8.0), '8.4-8');
      expect(ConditionAptitudeAnalyzer.cushionBand(7.9), '7.9以下');
      expect(ConditionAptitudeAnalyzer.cushionBand(7.0), '7.9以下');
      expect(ConditionAptitudeAnalyzer.moistureBand(5), '6%以下');
      expect(ConditionAptitudeAnalyzer.moistureBand(6.9), '6%以下');
      expect(ConditionAptitudeAnalyzer.moistureBand(7), '7〜10%');
      expect(ConditionAptitudeAnalyzer.moistureBand(10), '7〜10%');
      expect(ConditionAptitudeAnalyzer.moistureBand(11), '11〜13%');
      expect(ConditionAptitudeAnalyzer.moistureBand(13), '11〜13%');
      expect(ConditionAptitudeAnalyzer.moistureBand(14), '14%以上');
      expect(ConditionAptitudeAnalyzer.moistureBand(20), '14%以上');
    });

    test('芝・ダの出走が無い馬（障害のみ）は馬場データのカテゴリを出さない', () {
      final a = ConditionAptitudeAnalyzer.analyze([rec(distance: '障3380', rank: '1')]);
      expect(catOf(a, 'クッション値(芝)'), isNull);
      expect(catOf(a, '含水率(ダ・ゴール前)'), isNull);
    });

    test('芝の出走があれば馬場データが無くてもクッション値6段を着度数0で出す', () {
      final a = ConditionAptitudeAnalyzer.analyze([rec(distance: '芝1600', rank: '1')]);
      final cat = catOf(a, 'クッション値(芝)')!;
      expect(cat.values.map((v) => v.label).toList(), ConditionAptitudeAnalyzer.cushionBandOrder);
      for (final v in cat.values) {
        expect(v.tally.total, 0);
      }
      expect(catOf(a, '含水率(ダ・ゴール前)'), isNull);
      expect(catIndex(a, 'クッション値(芝)'), catIndex(a, '馬場') + 1);
    });

    test('turf → クッション値6段（固定順・出走の無い段は0・得意/参考なし）', () {
      final records = <HorseRaceRecord>[
        rec(raceId: 'a', distance: '芝1600', rank: '1'),
        rec(raceId: 'b', distance: '芝1600', rank: '3'),
        rec(raceId: 'c', distance: '芝2000', rank: '5'),
        rec(raceId: 'd', distance: '芝2000', rank: '2'),
      ];
      final tc = <String, TrackConditionRecord?>{
        'a': tcRec(1, cushion: 9.8),
        'b': tcRec(2, cushion: 9.0),
        'c': tcRec(3, cushion: 10.1),
        'd': null,
      };
      final a = ConditionAptitudeAnalyzer.analyze(records, trackConditions: tc);
      final cat = catOf(a, 'クッション値(芝)')!;
      expect(cat.values.length, 6);
      expect(cat.values[0].label, '10以上');
      expect(cat.values[0].tally.out, 1);
      expect(cat.values[1].label, '9.9-9.5');
      expect(cat.values[1].tally.first, 1);
      expect(cat.values[2].label, '9.4-9');
      expect(cat.values[2].tally.third, 1);
      expect(cat.values[3].tally.total, 0);
      expect(cat.values[4].tally.total, 0);
      expect(cat.values[5].tally.total, 0);
      for (final v in cat.values) {
        expect(v.isBest, isFalse);
        expect(v.isReference, isFalse);
        expect(v.isCurrent, isFalse);
      }
      expect(catOf(a, '含水率(ダ・ゴール前)'), isNull);
    });

    test('dirt → 含水率4段（出走の無い段も0）', () {
      final records = <HorseRaceRecord>[
        rec(raceId: 'a', distance: 'ダ1200', rank: '1'),
        rec(raceId: 'b', distance: 'ダ1200', rank: '4'),
      ];
      final tc = <String, TrackConditionRecord?>{
        'a': tcRec(1, dirtGoal: 15.0),
        'b': tcRec(2, dirtGoal: 5.0),
      };
      final a = ConditionAptitudeAnalyzer.analyze(records, trackConditions: tc);
      final cat = catOf(a, '含水率(ダ・ゴール前)')!;
      expect(cat.values.map((v) => v.label).toList(), ConditionAptitudeAnalyzer.moistureBandOrder);
      expect(cat.values[0].tally.out, 1);
      expect(cat.values[1].tally.total, 0);
      expect(cat.values[2].tally.total, 0);
      expect(cat.values[3].tally.first, 1);
      expect(catOf(a, 'クッション値(芝)'), isNull);
    });

    test('今回印: 今回が芝ならクッション値の段、ダートなら含水率の段', () {
      final records = <HorseRaceRecord>[
        rec(raceId: 'a', distance: '芝1600', rank: '1'),
        rec(raceId: 'b', distance: 'ダ1400', rank: '2'),
      ];
      final turf = ConditionAptitudeAnalyzer.analyze(records,
          currentSurface: '芝', currentCushionValue: 9.6, currentMoistureDirtGoal: 8.0);
      expect(catOf(turf, 'クッション値(芝)')!.values.where((v) => v.isCurrent).map((v) => v.label).toList(),
          ['9.9-9.5']);
      expect(catOf(turf, '含水率(ダ・ゴール前)')!.values.where((v) => v.isCurrent), isEmpty);

      final dirt = ConditionAptitudeAnalyzer.analyze(records,
          currentSurface: 'ダ', currentCushionValue: 9.6, currentMoistureDirtGoal: 8.0);
      expect(catOf(dirt, 'クッション値(芝)')!.values.where((v) => v.isCurrent), isEmpty);
      expect(catOf(dirt, '含水率(ダ・ゴール前)')!.values.where((v) => v.isCurrent).map((v) => v.label).toList(),
          ['7〜10%']);
    });
  });
}
