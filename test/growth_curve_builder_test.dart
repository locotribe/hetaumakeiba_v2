// test/growth_curve_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

HorseRaceRecord _record({
  required String date,
  String raceName = 'テストレース',
  String horseWeight = '480(0)',
  String popularity = '1',
  String rank = '1',
  String numberOfHorses = '16',
}) {
  return HorseRaceRecord(
    horseId: 'h1',
    raceId: 'r_$date',
    date: date,
    venue: '',
    weather: '',
    raceNumber: '',
    raceName: raceName,
    numberOfHorses: numberOfHorses,
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: popularity,
    rank: rank,
    jockey: '',
    jockeyId: '',
    carriedWeight: '',
    distance: '',
    trackCondition: '',
    time: '',
    margin: '',
    cornerPassage: '',
    pace: '',
    agari: '',
    horseWeight: horseWeight,
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

GrowthPoint _point(DateTime date, int? weight, {bool isCurrent = false}) {
  return GrowthPoint(
    date: date,
    raceName: 'x',
    weight: weight,
    weightChange: null,
    popularity: null,
    rank: null,
    finishKind: GrowthFinishKind.unknown,
    fieldSize: null,
    isCurrent: isCurrent,
  );
}

void main() {
  group('文字列の読み取り', () {
    test('parseWeightKg: 増減付き・数字のみ・計不・空', () {
      expect(GrowthCurveBuilder.parseWeightKg('478(+6)'), 478);
      expect(GrowthCurveBuilder.parseWeightKg('480'), 480);
      expect(GrowthCurveBuilder.parseWeightKg('計不'), isNull);
      expect(GrowthCurveBuilder.parseWeightKg(''), isNull);
    });

    test('parseWeightChange: プラス・マイナス・0・括弧なし', () {
      expect(GrowthCurveBuilder.parseWeightChange('478(+6)'), 6);
      expect(GrowthCurveBuilder.parseWeightChange('476(-8)'), -8);
      expect(GrowthCurveBuilder.parseWeightChange('472(0)'), 0);
      expect(GrowthCurveBuilder.parseWeightChange('計不'), isNull);
      expect(GrowthCurveBuilder.parseWeightChange('480'), isNull);
    });

    test('finishKindOf / parseRank: 数字・降着・中止・除外・取消・空', () {
      expect(GrowthCurveBuilder.finishKindOf('1'), GrowthFinishKind.numeric);
      expect(GrowthCurveBuilder.parseRank('4(降)'), 4);
      expect(GrowthCurveBuilder.finishKindOf('4(降)'), GrowthFinishKind.numeric);
      expect(GrowthCurveBuilder.finishKindOf('中'), GrowthFinishKind.stopped);
      expect(GrowthCurveBuilder.finishKindOf('除'), GrowthFinishKind.excluded);
      expect(GrowthCurveBuilder.finishKindOf('取'), GrowthFinishKind.scratched);
      expect(GrowthCurveBuilder.finishKindOf(''), GrowthFinishKind.unknown);
      expect(GrowthCurveBuilder.parseRank('中'), isNull);
    });

    test('parsePositiveInt: 空と0は null', () {
      expect(GrowthCurveBuilder.parsePositiveInt('7'), 7);
      expect(GrowthCurveBuilder.parsePositiveInt(''), isNull);
      expect(GrowthCurveBuilder.parsePositiveInt('0'), isNull);
    });

    test('shortRaceName: クラス表記を短くする', () {
      expect(GrowthCurveBuilder.shortRaceName('朝日フューチュリティ(GI)'),
          '朝日フューチュリティG1');
      expect(GrowthCurveBuilder.shortRaceName('函館2歳S(GIII)'), '函館2歳SG3');
      expect(GrowthCurveBuilder.shortRaceName('花園S(3勝クラス)'), '花園S3勝');
      expect(GrowthCurveBuilder.shortRaceName('2歳新馬'), '2歳新馬');
    });
  });

  group('buildPoints', () {
    test('古い順に並べ、デビュー戦の増減は null、人気空は null', () {
      final points = GrowthCurveBuilder.buildPoints(records: [
        _record(date: '2025/12/21', horseWeight: '478(0)', rank: '3'),
        _record(date: '2025/10/18', horseWeight: '472(0)'),
        _record(
            date: '2025/11/15',
            horseWeight: '478(+6)',
            popularity: '',
            rank: '除'),
      ]);
      expect(points.length, 3);
      expect(points[0].date, DateTime(2025, 10, 18));
      expect(points[0].weight, 472);
      expect(points[0].weightChange, isNull);
      expect(points[1].weightChange, 6);
      expect(points[1].popularity, isNull);
      expect(points[1].finishKind, GrowthFinishKind.excluded);
      expect(points[1].rank, isNull);
      expect(points[2].rank, 3);
      expect(points[2].fieldSize, 16);
      expect(points.every((p) => !p.isCurrent), isTrue);
    });

    test('計不は体重 null・日付が読めない行は捨てる', () {
      final points = GrowthCurveBuilder.buildPoints(records: [
        _record(date: '2025/10/18', horseWeight: '計不', rank: '取'),
        _record(date: 'xxxx'),
      ]);
      expect(points.length, 1);
      expect(points[0].weight, isNull);
      expect(points[0].finishKind, GrowthFinishKind.scratched);
    });

    test('raceDate より前だけを使う（当日と未来は除く）', () {
      final points = GrowthCurveBuilder.buildPoints(
        records: [
          _record(date: '2026/03/08'),
          _record(date: '2026/04/19'),
          _record(date: '2026/05/10'),
        ],
        raceDate: DateTime(2026, 4, 19),
      );
      expect(points.length, 1);
      expect(points[0].date, DateTime(2026, 3, 8));
    });

    test('当日体重（括弧付き）があれば最後に今回の点を足す', () {
      final points = GrowthCurveBuilder.buildPoints(
        records: [_record(date: '2026/05/10', horseWeight: '478(-4)')],
        raceDate: DateTime(2026, 10, 4),
        currentHorseWeight: '484(+6)',
      );
      expect(points.length, 2);
      expect(points.last.isCurrent, isTrue);
      expect(points.last.date, DateTime(2026, 10, 4));
      expect(points.last.weight, 484);
      expect(points.last.weightChange, 6);
      expect(points.last.raceName, '今回');
    });

    test('当日体重が括弧なし・raceDate なしなら今回の点は足さない', () {
      final noParen = GrowthCurveBuilder.buildPoints(
        records: [_record(date: '2026/05/10')],
        raceDate: DateTime(2026, 10, 4),
        currentHorseWeight: '478',
      );
      expect(noParen.length, 1);
      final noDate = GrowthCurveBuilder.buildPoints(
        records: [_record(date: '2026/05/10')],
        currentHorseWeight: '484(+6)',
      );
      expect(noDate.length, 1);
    });
  });

  group('期間と基準日', () {
    test('baseDate: 過去レースはレース日、今日以降は今日（時刻なし）', () {
      final today = DateTime(2026, 10, 1, 15, 30);
      expect(
          GrowthCurveBuilder.baseDate(
              raceDate: DateTime(2026, 5, 10), today: today),
          DateTime(2026, 5, 10));
      expect(
          GrowthCurveBuilder.baseDate(
              raceDate: DateTime(2026, 10, 4), today: today),
          DateTime(2026, 10, 1));
      expect(
          GrowthCurveBuilder.baseDate(
              raceDate: DateTime(2026, 10, 1), today: today),
          DateTime(2026, 10, 1));
      expect(GrowthCurveBuilder.baseDate(today: today), DateTime(2026, 10, 1));
    });

    test('pointsInRange: 1年・3年は基準日の同じ日以降、全期間はすべて', () {
      final points = [
        _point(DateTime(2023, 9, 30), 460),
        _point(DateTime(2023, 10, 1), 462),
        _point(DateTime(2025, 9, 30), 470),
        _point(DateTime(2025, 10, 1), 472),
        _point(DateTime(2026, 9, 1), 474),
      ];
      final base = DateTime(2026, 10, 1);
      expect(
          GrowthCurveBuilder.pointsInRange(points, GrowthRange.oneYear, base)
              .map((p) => p.weight)
              .toList(),
          [472, 474]);
      expect(
          GrowthCurveBuilder.pointsInRange(
                  points, GrowthRange.threeYears, base)
              .map((p) => p.weight)
              .toList(),
          [462, 470, 472, 474]);
      expect(
          GrowthCurveBuilder.pointsInRange(points, GrowthRange.all, base)
              .length,
          5);
    });
  });

  group('weightWindow', () {
    final d = DateTime(2026, 1, 1);

    test('幅が60kgに満たなければ中心を保って広げ、10kg単位にそろえる', () {
      final points = [472, 478, 478, 480, 482, 478]
          .map((w) => _point(d, w))
          .toList();
      final w = GrowthCurveBuilder.weightWindow(points);
      expect(w.min, 440);
      expect(w.max, 510);
      expect(w.contains(450), isTrue);
    });

    test('幅が60kg以上ならそのまま。450が窓の外になることもある', () {
      final w = GrowthCurveBuilder.weightWindow(
          [_point(d, 500), _point(d, 540)]);
      expect(w.min, 490);
      expect(w.max, 550);
      expect(w.contains(GrowthCurveBuilder.referenceWeight), isFalse);
    });

    test('体重が無ければ既定の窓・計不は無視', () {
      expect(GrowthCurveBuilder.weightWindow([]).min, 420);
      expect(GrowthCurveBuilder.weightWindow([_point(d, null)]).max, 480);
      final w = GrowthCurveBuilder.weightWindow(
          [_point(d, 450), _point(d, null)]);
      expect(w.min, 420);
      expect(w.max, 480);
    });
  });

  group('summarize と rankVsPopularity', () {
    test('デビュー・最新（今回含む）・最高・最低・走数（今回は数えない）', () {
      final s = GrowthCurveBuilder.summarize([
        _point(DateTime(2025, 10, 18), 472),
        _point(DateTime(2025, 11, 15), null),
        _point(DateTime(2026, 4, 19), 482),
        _point(DateTime(2026, 10, 4), 476, isCurrent: true),
      ]);
      expect(s.debutWeight, 472);
      expect(s.latestWeight, 476);
      expect(s.maxWeight, 482);
      expect(s.minWeight, 472);
      expect(s.runCount, 3);
      expect(s.diffFromDebut, 4);
    });

    test('点が無ければすべて null・0走', () {
      final s = GrowthCurveBuilder.summarize([]);
      expect(s.debutWeight, isNull);
      expect(s.diffFromDebut, isNull);
      expect(s.runCount, 0);
    });

    test('着順が人気より上なら1・下なら-1・同じなら0・不明なら null', () {
      GrowthPoint p(int? pop, int? rank) => GrowthPoint(
            date: DateTime(2026, 1, 1),
            raceName: 'x',
            weight: 480,
            weightChange: null,
            popularity: pop,
            rank: rank,
            finishKind: rank == null
                ? GrowthFinishKind.unknown
                : GrowthFinishKind.numeric,
            fieldSize: 16,
            isCurrent: false,
          );
      expect(p(5, 2).rankVsPopularity, 1);
      expect(p(1, 3).rankVsPopularity, -1);
      expect(p(3, 3).rankVsPopularity, 0);
      expect(p(null, 3).rankVsPopularity, isNull);
      expect(p(3, null).rankVsPopularity, isNull);
    });
  });
}
