// test/training_date_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';

TrainingTimeModel _t(String date) => TrainingTimeModel(
      horseId: 'h1',
      trainingDate: date,
      trainingTime: '0600',
      trackType: '坂路',
      location: '栗東',
    );

void main() {
  group('toYyyymmdd', () {
    test('和暦表記・スラッシュ・ハイフン・8桁を変換する', () {
      expect(toYyyymmdd('2026年9月27日'), '20260927');
      expect(toYyyymmdd('2026/09/27'), '20260927');
      expect(toYyyymmdd('2026-9-7'), '20260907');
      expect(toYyyymmdd('20260927'), '20260927');
    });
    test('変換できないものは null', () {
      expect(toYyyymmdd(''), isNull);
      expect(toYyyymmdd('不明'), isNull);
    });
  });

  group('filterTrainingBeforeRace', () {
    final records = [
      _t('20260928'),
      _t('20260927'),
      _t('20260924'),
      _t('20260920'),
    ];
    test('レース当日以降を除き、並び順を保つ', () {
      final result = filterTrainingBeforeRace(records, '2026年9月27日');
      expect(result.map((r) => r.trainingDate).toList(),
          ['20260924', '20260920']);
    });
    test('レース日が不明なら絞らない', () {
      expect(filterTrainingBeforeRace(records, '').length, 4);
    });
    test('調教日が8桁でない行は残す', () {
      final result =
          filterTrainingBeforeRace([_t('2026092'), _t('20260930')], '20260927');
      expect(result.map((r) => r.trainingDate).toList(), ['2026092']);
    });
    test('Map版は馬ごとに絞る', () {
      final result = filterTrainingMapBeforeRace(
          {'h1': records, 'h2': [_t('20260927')]}, '20260927');
      expect(result['h1']!.length, 2);
      expect(result['h2']!, isEmpty);
    });
  });

  group('calcTrainingLaps', () {
    test('坂路4F: 各列の1Fラップと最後の1F', () {
      expect(calcTrainingLaps([64.0, 46.1, 30.4, 15.4]),
          [17.9, 15.7, 15.0, 15.4]);
    });
    test('1本だけならそのまま', () {
      expect(calcTrainingLaps([13.4]), [13.4]);
    });
    test('空なら空', () {
      expect(calcTrainingLaps([]), isEmpty);
    });
  });
}
