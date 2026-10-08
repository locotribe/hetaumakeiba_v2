// test/ai_race_data_collector_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/services/ai_export/ai_race_data_collector.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

void main() {
  group('AiRaceDataCollector.composeBundle', () {
    test('horseIds の順で出走馬を並べ、データが無い馬は空/nullで穴埋めする', () {
      final bundle = AiRaceDataCollector.composeBundle(
        raceId: 'r1',
        raceName: 'テストレース',
        raceDate: '2026年9月27日',
        horseIds: ['a', 'b', 'c'],
        performanceByHorse: {},
        extrasByHorse: {},
        sessionsByHorse: {},
        reviewByHorse: {},
        profileByHorse: {},
        speedIndexByHorse: {},
        simParamsByHorse: {},
        trainingTimesByHorse: {},
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
      );

      expect(bundle.horses.length, 3);
      expect(bundle.horses.map((h) => h.horseId).toList(), ['a', 'b', 'c']);
      final a = bundle.horses.first;
      expect(a.performance, isEmpty);
      expect(a.extrasByRaceId, isEmpty);
      expect(a.trainingSessions, isEmpty);
      expect(a.trainingTimes, isEmpty);
      expect(a.trainingReview, isNull);
      expect(a.profile, isNull);
      expect(a.speedIndex, isNull);
      expect(a.simulationParams, isNull);
    });

    test('レース単位フィールドがそのまま反映される', () {
      final bundle = AiRaceDataCollector.composeBundle(
        raceId: 'r1',
        raceName: 'テストレース',
        raceDate: '2026年9月27日',
        horseIds: [],
        performanceByHorse: {},
        extrasByHorse: {},
        sessionsByHorse: {},
        reviewByHorse: {},
        profileByHorse: {},
        speedIndexByHorse: {},
        simParamsByHorse: {},
        trainingTimesByHorse: {},
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: '重い馬場想定',
      );

      expect(bundle.raceId, 'r1');
      expect(bundle.raceName, 'テストレース');
      expect(bundle.horses, isEmpty);
      expect(bundle.raceMemoText, '重い馬場想定');
      expect(bundle.raceStatistics, isNull);
      expect(bundle.trackCondition, isNull);
    });

    test('horseIds に無い馬のデータは出力に含めない', () {
      final bundle = AiRaceDataCollector.composeBundle(
        raceId: 'r1',
        raceName: 'テストレース',
        raceDate: '2026年9月27日',
        horseIds: ['a'],
        performanceByHorse: {'x': []},
        extrasByHorse: {},
        sessionsByHorse: {},
        reviewByHorse: {},
        profileByHorse: {},
        speedIndexByHorse: {},
        simParamsByHorse: {},
        trainingTimesByHorse: {},
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
      );

      expect(bundle.horses.length, 1);
      expect(bundle.horses.single.horseId, 'a');
    });

    test('過去走ごとの馬場が pastTrackByRaceId に反映される', () {
      final tc = TrackConditionRecord(
        trackConditionId: 1,
        date: '2026-06-01',
        weekDay: 'sa',
        cushionValue: 9.2,
      );
      final bundle = AiRaceDataCollector.composeBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horseIds: ['a'],
        performanceByHorse: {},
        extrasByHorse: {},
        sessionsByHorse: {},
        reviewByHorse: {},
        profileByHorse: {},
        speedIndexByHorse: {},
        simParamsByHorse: {},
        trainingTimesByHorse: {},
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
        pastTrackByHorse: {
          'a': {'pr1': tc}
        },
      );
      expect(bundle.horses.single.pastTrackByRaceId['pr1']?.cushionValue, 9.2);
    });
  });
}
