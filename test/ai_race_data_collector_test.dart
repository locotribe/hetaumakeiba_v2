// test/ai_race_data_collector_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/services/ai_export/ai_race_data_collector.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/db/elevations/tokyo/tokyo_course.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_course_profile.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

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

    test('コース・馬場推移・天気の項目を省略すると空/null', () {
      final bundle = AiRaceDataCollector.composeBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年10月11日',
        horseIds: [],
        performanceByHorse: {},
        extrasByHorse: {},
        sessionsByHorse: {},
        reviewByHorse: {},
        profileByHorse: {},
        speedIndexByHorse: {},
        simParamsByHorse: {},
        trainingTimesByHorse: {},
      );
      expect(bundle.courseProfile, isNull);
      expect(bundle.coursePreset, isNull);
      expect(bundle.meetingTrackHistory, isEmpty);
      expect(bundle.latestVenueTrackCondition, isNull);
      expect(bundle.weatherSnapshot, isNull);
      expect(bundle.weatherUnavailableReason, isNull);
    });

    test('コース・プリセット・馬場推移・最新測定・天気の理由がそのまま反映される', () {
      final older = TrackConditionRecord(
        trackConditionId: 202605040101,
        date: '2026-10-03',
        weekDay: 'sa',
        cushionValue: 9.7,
      );
      final latest = TrackConditionRecord(
        trackConditionId: 202605040201,
        date: '2026-10-10',
        weekDay: 'sa',
        cushionValue: 9.6,
      );
      final preset = CoursePreset(
        id: '05_shiba_1800',
        venueCode: '05',
        venueName: '東京',
        distance: '芝1800',
        direction: '左回り',
        straightLength: 526,
        courseLayout: 'テストのレイアウト',
        keyPoints: 'テストのポイント',
      );
      final profile = buildAiCourseProfile(TokyoCourse.shiba1800);
      final bundle = AiRaceDataCollector.composeBundle(
        raceId: '202605040211',
        raceName: 'テスト',
        raceDate: '2026年10月11日',
        horseIds: [],
        performanceByHorse: {},
        extrasByHorse: {},
        sessionsByHorse: {},
        reviewByHorse: {},
        profileByHorse: {},
        speedIndexByHorse: {},
        simParamsByHorse: {},
        trainingTimesByHorse: {},
        courseProfile: profile,
        coursePreset: preset,
        meetingTrackHistory: [older, latest],
        latestVenueTrackCondition: latest,
        weatherSnapshot: null,
        weatherUnavailableReason: '未取得（レース情報タブの🔄で取得）',
      );
      expect(bundle.courseProfile, same(profile));
      expect(bundle.coursePreset?.straightLength, 526);
      expect(bundle.meetingTrackHistory.map((r) => r.date).toList(),
          ['2026-10-03', '2026-10-10']);
      expect(bundle.latestVenueTrackCondition?.cushionValue, 9.6);
      expect(bundle.weatherSnapshot, isNull);
      expect(bundle.weatherUnavailableReason, '未取得（レース情報タブの🔄で取得）');
    });
  });
}
