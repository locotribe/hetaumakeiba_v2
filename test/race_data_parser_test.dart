// test/race_data_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

HorseResult _horse(String horseId, String agari) => HorseResult(
      rank: '1',
      frameNumber: '1',
      horseNumber: '1',
      horseName: 'テスト',
      horseId: horseId,
      sexAndAge: '牡3',
      weightCarried: '57',
      jockeyName: '騎手',
      jockeyId: '',
      time: '',
      margin: '',
      cornerRanking: '',
      agari: agari,
      odds: '',
      popularity: '',
      horseWeight: '',
      trainerName: '',
      trainerAffiliation: '',
      ownerName: '',
      prizeMoney: '',
    );

RaceResult _result({
  List<String> lapTimes = const [],
  List<HorseResult> horses = const [],
}) =>
    RaceResult(
      raceId: '202405021211',
      raceTitle: '第91回東京優駿(GI)',
      raceInfo: '芝左2400m / 天候 : 晴 / 芝 : 良',
      raceDate: '2024年5月26日',
      raceGrade: '',
      horseResults: horses,
      refunds: const [],
      cornerPassages: const [],
      lapTimes: lapTimes,
    );

void main() {
  // 2024年 東京優駿の実データ（db.netkeiba.com で確認済みの形式）
  const derbyLaps = [
    'ラップ: 12.5 - 11.4 - 12.4 - 13.1 - 12.8 - 12.6 - 12.7 - 11.7 - 11.3 - 11.1 - 11.2 - 11.5',
    'ペース: 12.5 - 23.9 - 36.3 - 49.4 - 62.2 - 74.8 - 87.5 - 99.2 - 110.5 - 121.6 - 132.8 - 144.3 (36.3-33.8)',
  ];

  test('calculatePaceFromRaceResult は「ラップ:」行のみで判定する', () {
    // 前半6本=74.8 / 後半6本=69.5 → 差 -5.3 → スロー
    expect(RaceDataParser.calculatePaceFromRaceResult(_result(lapTimes: derbyLaps)), 'スロー');
  });

  test('extractRaceFirstLast3F は「ペース:」行の括弧から前後半3Fを取り出す', () {
    final v = RaceDataParser.extractRaceFirstLast3F(_result(lapTimes: derbyLaps));
    expect(v, isNotNull);
    expect(v!.first3f, 36.3);
    expect(v.last3f, 33.8);
  });

  test('extractRaceFirstLast3F はラップが無ければ null', () {
    expect(RaceDataParser.extractRaceFirstLast3F(_result()), isNull);
  });

  test('parseRecordPace は平地の値のみ分解し、障害の値は null', () {
    final v = RaceDataParser.parseRecordPace('35.0-34.5');
    expect(v!.first3f, 35.0);
    expect(v.last3f, 34.5);
    expect(RaceDataParser.parseRecordPace('108.0-40.2'), isNull);
    expect(RaceDataParser.parseRecordPace(''), isNull);
  });

  test('paceMarkFromFirstLast3F', () {
    expect(RaceDataParser.paceMarkFromFirstLast3F(36.3, 33.8), 'S');
    expect(RaceDataParser.paceMarkFromFirstLast3F(33.8, 36.3), 'H');
    expect(RaceDataParser.paceMarkFromFirstLast3F(35.0, 35.5), 'M');
  });

  test('computeAgariRank', () {
    final r = _result(horses: [
      _horse('a', '33.9'),
      _horse('b', '35.0'),
      _horse('c', '33.5'),
      _horse('d', ''),
    ]);
    expect(RaceDataParser.computeAgariRank(r, 'c'), 1);
    expect(RaceDataParser.computeAgariRank(r, 'a'), 2);
    expect(RaceDataParser.computeAgariRank(r, 'b'), 3);
    expect(RaceDataParser.computeAgariRank(r, 'd'), isNull);
    expect(RaceDataParser.computeAgariRank(r, 'zzz'), isNull);
  });
}
