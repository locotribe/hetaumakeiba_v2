// test/condition_ranking_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_ranking_builder.dart';

HorseRaceRecord rec({
  String rank = '5',
  String distance = '芝1600',
  String venue = '5東京8',
  String raceName = '3歳未勝利',
}) {
  return HorseRaceRecord(
    horseId: 'h',
    raceId: 'r',
    date: '2025/01/01',
    venue: venue,
    weather: '晴',
    raceNumber: '11',
    raceName: raceName,
    numberOfHorses: '16',
    frameNumber: '1',
    horseNumber: '1',
    odds: '5.0',
    popularity: '4',
    rank: rank,
    jockey: 'J',
    jockeyId: 'jid',
    carriedWeight: '55',
    distance: distance,
    trackCondition: '良',
    time: '1:34.0',
    margin: '0.2',
    cornerPassage: '5-5',
    pace: '',
    agari: '34.0',
    horseWeight: '470(0)',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

PredictionRaceData prd({
  String? trackType,
  int? distanceValue,
  String? direction,
  String venue = '5東京8',
  String raceName = '3歳未勝利',
}) {
  return PredictionRaceData(
    raceId: 'r',
    raceName: raceName,
    raceDate: '2025/01/01',
    venue: venue,
    raceNumber: '11',
    shutubaTableUrl: '',
    raceGrade: '',
    horses: const [],
    trackType: trackType,
    distanceValue: distanceValue,
    direction: direction,
  );
}

HorseConditionCell cell(ConditionRankingTable t, int horseNumber, String key) {
  final row = t.rows.firstWhere((r) => r.horseNumber == horseNumber);
  return row.cells[key]!;
}

void main() {
  group('conditionsOf', () {
    test('芝1600 東京 左 条件', () {
      final c = ConditionRankingBuilder.conditionsOf(
          prd(trackType: '芝', distanceValue: 1600, direction: '左'));
      expect(c.surface, '芝');
      expect(c.distanceLabel, '芝1400-1600');
      expect(c.direction, '左');
      expect(c.venue, '東京');
      expect(c.classLabel, '条件');
    });

    test('direction 未設定なら venue からフォールバック', () {
      final c = ConditionRankingBuilder.conditionsOf(
          prd(trackType: 'ダ', distanceValue: 1200, venue: '8京都3'));
      expect(c.surface, 'ダ');
      expect(c.distanceLabel, 'ダ〜1300');
      expect(c.direction, '右');
      expect(c.venue, '京都');
    });

    test('障は距離帯 null', () {
      final c = ConditionRankingBuilder.conditionsOf(
          prd(trackType: '障', distanceValue: 3000));
      expect(c.surface, '障');
      expect(c.distanceLabel, isNull);
    });
  });

  group('recordsForColumn', () {
    final recs = [
      rec(distance: '芝1600', venue: '5東京8', raceName: '3歳未勝利'),
      rec(distance: 'ダ1200', venue: '8京都3', raceName: '天皇賞(GI)'),
      rec(distance: '芝2000', venue: '5東京8', raceName: '3歳未勝利'),
    ];

    test('芝ダで絞り込み', () {
      expect(
          ConditionRankingBuilder.recordsForColumn(
                  ConditionRankingBuilder.kSurface, '芝', recs)
              .length,
          2);
    });

    test('距離帯で絞り込み', () {
      expect(
          ConditionRankingBuilder.recordsForColumn(
                  ConditionRankingBuilder.kDistance, '芝1400-1600', recs)
              .length,
          1);
    });

    test('開催地で絞り込み', () {
      expect(
          ConditionRankingBuilder.recordsForColumn(
                  ConditionRankingBuilder.kVenue, '東京', recs)
              .length,
          2);
    });

    test('クラスで絞り込み', () {
      expect(
          ConditionRankingBuilder.recordsForColumn(
                  ConditionRankingBuilder.kClass, 'G1', recs)
              .length,
          1);
    });

    test('— や空は空リスト', () {
      expect(
          ConditionRankingBuilder.recordsForColumn(
              ConditionRankingBuilder.kSurface, '—', recs),
          isEmpty);
    });
  });

  group('buildFrom', () {
    // 今回条件: 芝 / 芝1400-1600 / 左 / 東京 / 条件
    const conditions = RaceConditions(
      surface: '芝',
      distanceLabel: '芝1400-1600',
      direction: '左',
      venue: '東京',
      classLabel: '条件',
    );

    // B(1): 芝1600東京 1着・2着 → 複勝率1.0（該当2走）
    // C(2): 芝1600東京 1着 1走のみ → 参考
    // A(3): 芝1600東京 1着・4着 → 複勝率0.5（該当2走）
    // D(4): ダ1200京都 G1 → 今回条件にどの列も非該当（0走）
    // E(5): 芝1600東京 1着・2着 → 複勝率1.0（Bと同率）
    final horses = [
      HorseInput(horseId: 'B', horseName: 'B', horseNumber: 1, records: [
        rec(rank: '1'),
        rec(rank: '2'),
      ]),
      HorseInput(horseId: 'C', horseName: 'C', horseNumber: 2, records: [
        rec(rank: '1'),
      ]),
      HorseInput(horseId: 'A', horseName: 'A', horseNumber: 3, records: [
        rec(rank: '1'),
        rec(rank: '4'),
      ]),
      HorseInput(horseId: 'D', horseName: 'D', horseNumber: 4, records: [
        rec(rank: '1', distance: 'ダ1200', venue: '8京都3', raceName: '天皇賞(GI)'),
        rec(rank: '3', distance: 'ダ1200', venue: '8京都3', raceName: '天皇賞(GI)'),
      ]),
      HorseInput(horseId: 'E', horseName: 'E', horseNumber: 5, records: [
        rec(rank: '1'),
        rec(rank: '2'),
      ]),
    ];

    final table = ConditionRankingBuilder.buildFrom(
        conditions: conditions, horses: horses);

    test('列は5データ列＋総合列', () {
      expect(table.columns.map((c) => c.key).toList(), [
        ConditionRankingBuilder.kSurface,
        ConditionRankingBuilder.kDistance,
        ConditionRankingBuilder.kDirection,
        ConditionRankingBuilder.kVenue,
        ConditionRankingBuilder.kClass,
        ConditionRankingBuilder.kOverall,
      ]);
      final surfaceCol =
          table.columns.firstWhere((c) => c.key == ConditionRankingBuilder.kSurface);
      expect(surfaceCol.todayValue, '芝');
      final distCol =
          table.columns.firstWhere((c) => c.key == ConditionRankingBuilder.kDistance);
      expect(distCol.todayValue, '芝1400-1600');
      final overallCol =
          table.columns.firstWhere((c) => c.key == ConditionRankingBuilder.kOverall);
      expect(overallCol.todayValue, '—');
    });

    test('セルの複勝率・該当走数', () {
      final b = cell(table, 1, ConditionRankingBuilder.kSurface);
      expect(b.matchedCount, 2);
      expect(b.showRate, 1.0);
      expect(b.isReference, isFalse);

      final a = cell(table, 3, ConditionRankingBuilder.kSurface);
      expect(a.matchedCount, 2);
      expect(a.showRate, 0.5);
    });

    test('1走は参考・順位対象外', () {
      final c = cell(table, 2, ConditionRankingBuilder.kSurface);
      expect(c.matchedCount, 1);
      expect(c.isReference, isTrue);
      expect(c.rank, isNull);
    });

    test('0走は空・順位対象外', () {
      final d = cell(table, 4, ConditionRankingBuilder.kSurface);
      expect(d.matchedCount, 0);
      expect(d.showRate, isNull);
      expect(d.rank, isNull);
    });

    test('列内順位（複勝率降順・同率は同順位）', () {
      final b = cell(table, 1, ConditionRankingBuilder.kSurface);
      final e = cell(table, 5, ConditionRankingBuilder.kSurface);
      final a = cell(table, 3, ConditionRankingBuilder.kSurface);
      expect(b.rank, 1);
      expect(e.rank, 1); // Bと同率＝同順位
      expect(a.rank, 2);
      expect(b.rankOutOf, 2); // 異なる複勝率は 1.0 と 0.5 の2種
    });

    test('総合列＝該当2走以上の各列複勝率の平均', () {
      final bRow = table.rows.firstWhere((r) => r.horseNumber == 1);
      expect(bRow.overallShowRate, 1.0);
      final aRow = table.rows.firstWhere((r) => r.horseNumber == 3);
      expect(aRow.overallShowRate, 0.5);
      final cRow = table.rows.firstWhere((r) => r.horseNumber == 2);
      expect(cRow.overallShowRate, isNull); // 参考のみ＝本走列なし
      final dRow = table.rows.firstWhere((r) => r.horseNumber == 4);
      expect(dRow.overallShowRate, isNull);
    });

    test('行は総合降順→馬番昇順', () {
      expect(table.rows.map((r) => r.horseNumber).toList(), [1, 5, 3, 2, 4]);
    });
  });
}
