// test/speed_index_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// テストに不要なフィールドは固定値で埋めた HorseRaceRecord を生成するヘルパー。
HorseRaceRecord _record({
  String date = '2023/01/05',
  String venue = '1東京3',
  required String distance,
  String trackCondition = '良',
  required String time,
}) {
  return HorseRaceRecord(
    horseId: 'T1',
    raceId: '202501010101',
    date: date,
    venue: venue,
    weather: '晴',
    raceNumber: '1',
    raceName: 'テストレース',
    numberOfHorses: '10',
    frameNumber: '1',
    horseNumber: '1',
    odds: '5.0',
    popularity: '1',
    rank: '1',
    jockey: 'テスト騎手',
    jockeyId: '00000',
    carriedWeight: '56',
    distance: distance,
    trackCondition: trackCondition,
    time: time,
    margin: '0.0',
    cornerPassage: '1-1-1-1',
    pace: '35.0-35.0',
    agari: '34.0',
    horseWeight: '480(0)',
    winnerOrSecondHorse: 'テスト馬',
    prizeMoney: '1000',
  );
}

void main() {
  group('SpeedIndexCalculator.calculate', () {
    test('基準タイムちょうどの走は指数≒80になる', () {
      // 芝1800m・東京(補正0.0)・良(補正0.0)・2023年(トレンド0)なので
      // 基準タイム=turfConst=106.539秒。走破タイムを同値にすると
      // (基準タイム-走破タイム)=0 となり、指数はkBaseIndex=80ちょうどになる。
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539'),
      ]);
      expect(result.bestIndex, closeTo(80.0, 0.01));
      expect(result.recentAvgIndex, closeTo(80.0, 0.01));
      expect(result.sampleCount, 1);
    });

    test('同条件では走破タイムが速いほど指数が大きい(単調性)', () {
      final slower = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539'),
      ]);
      final faster = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '104.539'), // 2秒速い
      ]);
      expect(faster.bestIndex, greaterThan(slower.bestIndex));
    });

    test('馬場略記("稍")は全形("稍重")と同じ補正になる', () {
      final abbreviated = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', trackCondition: '稍'),
      ]);
      final full = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', trackCondition: '稍重'),
      ]);
      expect(abbreviated.bestIndex, closeTo(full.bestIndex, 0.001));

      // 稍重は良に対して補正+0.933(芝)が乗るため、同一タイムなら指数は高くなる
      final good = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', trackCondition: '良'),
      ]);
      expect(abbreviated.bestIndex, greaterThan(good.bestIndex));
    });

    test('競馬場補正が符号どおり効く(阪神は東京よりオフセットが高い)', () {
      final tokyo = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', venue: '1東京3'),
      ]);
      final hanshin = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', venue: '1阪神3'),
      ]);
      expect(hanshin.bestIndex, greaterThan(tokyo.bestIndex));
    });

    test('未知競馬場(VenueOffsetマップに無い名称)の走はスキップされる', () {
      // 船橋(地方競馬)はJRAのVenueOffsetマップに存在しないため、
      // 東京基準(0.0)を代用せず無効走としてスキップされることを確認する。
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', venue: '1船橋3'),
      ]);
      expect(result.sampleCount, 0);
      expect(result.confidence, 0.0);
      expect(result.bestIndex, 0.0);

      // JRA開催(東京)の走と混在する場合も、未知競馬場の走のみが除外される
      final mixed = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', venue: '1船橋3'),
        _record(distance: '芝1800', time: '106.539', venue: '1東京3'),
      ]);
      expect(mixed.sampleCount, 1);
      expect(mixed.bestIndex, closeTo(80.0, 0.01));
    });

    test('年トレンドが符号どおり効く(turfYearTrendは負=年が進むほど基準が速くなる)', () {
      final year2023 = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', date: '2023/01/05'),
      ]);
      final year2024 = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: '106.539', date: '2024/01/05'),
      ]);
      expect(year2024.bestIndex, lessThan(year2023.bestIndex));
    });

    test('障害レースは除外される(有効走0件でsampleCount=0・confidence=0)', () {
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '障3380', time: '230.9'),
      ]);
      expect(result.sampleCount, 0);
      expect(result.confidence, 0.0);
      expect(result.bestIndex, 0.0);
      expect(result.recentAvgIndex, 0.0);
      expect(result.trend, 0.0);
    });

    test('タイム欠測の走は除外される', () {
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '芝1800', time: ''),
        _record(distance: '芝1800', time: '計不'),
      ]);
      expect(result.sampleCount, 0);
    });

    test('無効な走と有効な走が混在する場合、有効な走のみ集計される', () {
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '障3380', time: '230.9'),
        _record(distance: '芝1800', time: '106.539'),
      ]);
      expect(result.sampleCount, 1);
      expect(result.bestIndex, closeTo(80.0, 0.01));
    });

    test('recentAvgIndexは新しい走ほど重い加重平均になる', () {
      // date は "YYYY/MM/DD" なので月が大きいほど新しい走になる点に注意。
      // 直近(新しい)ほど速いタイム=高指数となるレコードを用意し、
      // 単純平均より高い値(新しいレースの重みが大きい)になることを確認する。
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/01/01', distance: '芝1800', time: '108.539'), // 最も古い・遅い
        _record(date: '2023/02/01', distance: '芝1800', time: '107.539'),
        _record(date: '2023/03/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/04/01', distance: '芝1800', time: '105.539'),
        _record(date: '2023/05/01', distance: '芝1800', time: '104.539'), // 最新・最速
      ]);
      // 単純平均に相当する基準点(3番目=中央値のレコード、指数80)より
      // 加重平均の方が高くなる(新しい高指数レースの重みが大きいため)
      expect(result.recentAvgIndex, greaterThan(80.0));
    });

    test('trendは直近3走平均とそれ以前の平均の差になる(4走以上で計算)', () {
      // date は "YYYY/MM/DD" なので月が大きいほど新しい走になる点に注意。
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/02/01', distance: '芝1800', time: '110.539'), // 古い・遅い
        _record(date: '2023/03/01', distance: '芝1800', time: '110.539'), // 古い・遅い
        _record(date: '2023/04/01', distance: '芝1800', time: '104.539'), // 直近3走(速い)
        _record(date: '2023/05/01', distance: '芝1800', time: '104.539'), // 直近3走(速い)
        _record(date: '2023/06/01', distance: '芝1800', time: '104.539'), // 直近3走(速い)
      ]);
      expect(result.trend, greaterThan(0.0));
    });

    test('走数が3以下の場合trendは0になる', () {
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/03/01', distance: '芝1800', time: '104.539'),
        _record(date: '2023/02/01', distance: '芝1800', time: '105.539'),
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
      ]);
      expect(result.trend, 0.0);
    });

    test('sampleCountが多いほどconfidenceが上がる(他条件同一)', () {
      final oneRace = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
      ]);
      final threeRaces = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/02/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/03/01', distance: '芝1800', time: '106.539'),
      ]);
      final fiveRaces = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/02/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/03/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/04/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/05/01', distance: '芝1800', time: '106.539'),
      ]);
      expect(threeRaces.confidence, greaterThan(oneRace.confidence));
      expect(fiveRaces.confidence, greaterThan(threeRaces.confidence));
    });

    test('asOfを与えて直近走が久々(400日前)だとconfidenceが下がる', () {
      // 直近走 2023/01/01 に対し、asOfを10日後(新鮮)と400日後(久々)で比較する。
      final records = [
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
      ];
      final fresh = SpeedIndexCalculator.calculate(
        'T1',
        records,
        asOf: DateTime(2023, 1, 11),
      );
      final stale = SpeedIndexCalculator.calculate(
        'T1',
        records,
        asOf: DateTime(2023, 1, 1).add(const Duration(days: 400)),
      );
      expect(stale.confidence, lessThan(fresh.confidence));
    });

    test('1走指数のばらつきが大きい馬はconfidenceが下がる', () {
      // 同一時期・同条件で「タイムが安定している馬」と「タイムが大きく上下する馬」を比較する。
      final consistent = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/02/01', distance: '芝1800', time: '106.639'),
        _record(date: '2023/03/01', distance: '芝1800', time: '106.439'),
      ]);
      final volatile = SpeedIndexCalculator.calculate('T1', [
        _record(date: '2023/01/01', distance: '芝1800', time: '106.539'),
        _record(date: '2023/02/01', distance: '芝1800', time: '86.539'), // 大幅に速い
        _record(date: '2023/03/01', distance: '芝1800', time: '126.539'), // 大幅に遅い
      ]);
      expect(volatile.confidence, lessThan(consistent.confidence));
    });

    test('confidenceは常に0.0〜1.0の範囲に収まる', () {
      // 走数が多い・久々でない・ばらつきが小さい(=confidenceが最大化されやすい)組み合わせでも1.0を超えない
      final records = List.generate(
        10,
        (i) => _record(
          date: '2023/0${(i % 9) + 1}/01',
          distance: '芝1800',
          time: '106.539',
        ),
      );
      final result = SpeedIndexCalculator.calculate(
        'T1',
        records,
        asOf: DateTime(2023, 9, 5),
      );
      expect(result.confidence, inInclusiveRange(0.0, 1.0));

      // 走数最小・大幅久々・大きなばらつきの組み合わせでも0.0を下回らない
      final worst = SpeedIndexCalculator.calculate(
        'T1',
        [_record(date: '2020/01/01', distance: '芝1800', time: '106.539')],
        asOf: DateTime(2023, 1, 1),
      );
      expect(worst.confidence, inInclusiveRange(0.0, 1.0));
    });

    test('有効走0件の場合confidenceは0.0になる', () {
      final result = SpeedIndexCalculator.calculate('T1', [
        _record(distance: '障3380', time: '230.9'),
      ]);
      expect(result.confidence, 0.0);
    });

    test('実データ整合の目安: 1〜3着相当の走は指数が概ね40〜120に収まる', () {
      // 芝2000m・阪神・良・2024年の想定で、標準的な決着タイム帯(118〜122秒)を検証する。
      for (final time in ['118.0', '120.0', '122.0']) {
        final result = SpeedIndexCalculator.calculate('T1', [
          _record(
            date: '2024/01/05',
            venue: '1阪神3',
            distance: '芝2000',
            trackCondition: '良',
            time: time,
          ),
        ]);
        expect(result.bestIndex, inInclusiveRange(40.0, 120.0));
      }
    });
  });
}
