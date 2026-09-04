// test/horse_record_asof_filter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

HorseRaceRecord _record({
  required String raceId,
  required String date,
}) {
  return HorseRaceRecord(
    horseId: 'h1',
    raceId: raceId,
    date: date,
    venue: '',
    weather: '',
    raceNumber: '',
    raceName: '',
    numberOfHorses: '',
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: '',
    rank: '',
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
    horseWeight: '',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

void main() {
  group('parseHorseRecordDate', () {
    test('YYYY/MM/DD形式をDateTimeへ変換する', () {
      expect(parseHorseRecordDate('2025/07/19'), DateTime(2025, 7, 19));
      expect(parseHorseRecordDate('2025/7/9'), DateTime(2025, 7, 9));
    });

    test('不正な形式は null を返す', () {
      expect(parseHorseRecordDate('2025-07-19'), isNull);
      expect(parseHorseRecordDate(''), isNull);
      expect(parseHorseRecordDate('abc/de/fg'), isNull);
    });
  });

  group('filterRecordsBeforeAsOf', () {
    test('asOfより前のレコードのみが残る', () {
      final records = [
        _record(raceId: 'r1', date: '2025/07/10'),
        _record(raceId: 'r2', date: '2025/07/01'),
      ];
      final result = filterRecordsBeforeAsOf(records, asOf: DateTime(2025, 7, 19));
      expect(result.map((r) => r.raceId), ['r1', 'r2']);
    });

    test('asOfと同日のレコードは除外される', () {
      final records = [
        _record(raceId: 'r1', date: '2025/07/19'),
      ];
      final result = filterRecordsBeforeAsOf(records, asOf: DateTime(2025, 7, 19));
      expect(result, isEmpty);
    });

    test('asOfより後のレコードは除外される', () {
      final records = [
        _record(raceId: 'r1', date: '2025/08/01'),
      ];
      final result = filterRecordsBeforeAsOf(records, asOf: DateTime(2025, 7, 19));
      expect(result, isEmpty);
    });

    test('excludeRaceIdに一致するレコードは、日付がasOfより前でも除外される', () {
      final records = [
        _record(raceId: 'target', date: '2025/07/10'),
        _record(raceId: 'other', date: '2025/07/05'),
      ];
      final result = filterRecordsBeforeAsOf(
        records,
        asOf: DateTime(2025, 7, 19),
        excludeRaceId: 'target',
      );
      expect(result.map((r) => r.raceId), ['other']);
    });

    test('日付がパース不能なレコードは除外される', () {
      final records = [
        _record(raceId: 'r1', date: '2025-07-10'),
        _record(raceId: 'r2', date: '2025/07/05'),
      ];
      final result = filterRecordsBeforeAsOf(records, asOf: DateTime(2025, 7, 19));
      expect(result.map((r) => r.raceId), ['r2']);
    });

    test('入力の並び順(date DESC想定)が保持される', () {
      final records = [
        _record(raceId: 'r1', date: '2025/07/15'),
        _record(raceId: 'r2', date: '2025/07/10'),
        _record(raceId: 'r3', date: '2025/07/05'),
      ];
      final result = filterRecordsBeforeAsOf(records, asOf: DateTime(2025, 7, 19));
      expect(result.map((r) => r.raceId), ['r1', 'r2', 'r3']);
    });

    test('excludeRaceIdを省略した場合はraceIdによる除外が行われない', () {
      final records = [
        _record(raceId: 'r1', date: '2025/07/10'),
      ];
      final result = filterRecordsBeforeAsOf(records, asOf: DateTime(2025, 7, 19));
      expect(result.map((r) => r.raceId), ['r1']);
    });
  });
}
