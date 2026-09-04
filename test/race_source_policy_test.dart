// test/race_source_policy_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/race_timeline.dart';
import 'package:hetaumakeiba_v2/logic/race_source_policy.dart';

void main() {
  group('RaceTimelineResolver.resolve', () {
    test('2026年9月6日 15:45発走の場合、nowに応じてタイムラインが変化する', () {
      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '2026年9月6日',
          startTime: '15:45',
          now: DateTime(2026, 9, 1, 0, 0),
        ),
        RaceTimeline.unpublished,
      );

      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '2026年9月6日',
          startTime: '15:45',
          now: DateTime(2026, 9, 6, 12, 0),
        ),
        RaceTimeline.upcoming,
      );

      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '2026年9月6日',
          startTime: '15:45',
          now: DateTime(2026, 9, 6, 16, 0),
        ),
        RaceTimeline.live,
      );

      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '2026年9月6日',
          startTime: '15:45',
          now: DateTime(2026, 9, 7, 0, 0),
        ),
        RaceTimeline.settled,
      );

      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '2026年9月6日',
          startTime: '15:45',
          now: DateTime(2026, 9, 20, 0, 0),
        ),
        RaceTimeline.archived,
      );
    });

    test('raceDateが空文字や不明な場合はunknownを返す', () {
      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '',
          now: DateTime(2026, 9, 6, 12, 0),
        ),
        RaceTimeline.unknown,
      );

      expect(
        RaceTimelineResolver.resolve(
          raceId: '202609060101',
          raceDate: '不明',
          now: DateTime(2026, 9, 6, 12, 0),
        ),
        RaceTimeline.unknown,
      );
    });

    test('startTimeがnullでもraceDetails1の「HH:mm発走」形式から発走時刻を反映する', () {
      final result = RaceTimelineResolver.resolve(
        raceId: '202609060101',
        raceDate: '2026年9月6日',
        raceDetails1: '芝右 1600m / 15:45発走',
        now: DateTime(2026, 9, 6, 16, 0),
      );
      expect(result, RaceTimeline.live);

      final beforeStart = RaceTimelineResolver.resolve(
        raceId: '202609060101',
        raceDate: '2026年9月6日',
        raceDetails1: '芝右 1600m / 15:45発走',
        now: DateTime(2026, 9, 6, 15, 30),
      );
      expect(beforeStart, RaceTimeline.upcoming);
    });

    test('startTimeがnullでもraceDetails1の「発走 : HH:mm」形式から発走時刻を反映する', () {
      final result = RaceTimelineResolver.resolve(
        raceId: '202609060101',
        raceDate: '2026年9月6日',
        raceDetails1: '芝右 1600m / 発走 : 15:45',
        now: DateTime(2026, 9, 6, 16, 0),
      );
      expect(result, RaceTimeline.live);

      final beforeStart = RaceTimelineResolver.resolve(
        raceId: '202609060101',
        raceDate: '2026年9月6日',
        raceDetails1: '芝右 1600m / 発走 : 15:45',
        now: DateTime(2026, 9, 6, 15, 30),
      );
      expect(beforeStart, RaceTimeline.upcoming);
    });

    test('startTimeもraceDetails1もnullの場合は既定の15:00で判定される', () {
      final beforeDefault = RaceTimelineResolver.resolve(
        raceId: '202609060101',
        raceDate: '2026年9月6日',
        now: DateTime(2026, 9, 6, 14, 30),
      );
      expect(beforeDefault, RaceTimeline.upcoming);

      final afterDefault = RaceTimelineResolver.resolve(
        raceId: '202609060101',
        raceDate: '2026年9月6日',
        now: DateTime(2026, 9, 6, 15, 30),
      );
      expect(afterDefault, RaceTimeline.live);
    });
  });

  group('RaceSourcePolicy.isAvailable', () {
    test('archivedでも全sourceでtrueを返す（10年前のページも参照可能なことを実測で確認済み）', () {
      for (final source in RaceDataSource.values) {
        expect(
          RaceSourcePolicy.isAvailable(source, RaceTimeline.archived),
          isTrue,
        );
      }
    });

    test('unknownの場合は全sourceでtrueを返す', () {
      for (final source in RaceDataSource.values) {
        expect(
          RaceSourcePolicy.isAvailable(source, RaceTimeline.unknown),
          isTrue,
        );
      }
    });

    test('全timeline × 全sourceでtrueを返す（現時点では時系列による制限をかけない）', () {
      for (final timeline in RaceTimeline.values) {
        for (final source in RaceDataSource.values) {
          expect(
            RaceSourcePolicy.isAvailable(source, timeline),
            isTrue,
          );
        }
      }
    });
  });
}
