// test/race_preparation_service_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_preparation_repository.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/services/race_preparation_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';

/// RacePreparationService は RacePreparationRepository 経由でDbProvider()の
/// 固定パスDBへアクセスするため、test/race_preparation_repository_test.dart と
/// 同じ初期化方法(sqflite_common_ffi)を踏襲する。実処理(スクレイピング)は
/// stepExecutors ですべて差し替え、ネットワークアクセスは一切行わない。
Future<String> _dbFilePath() async {
  final dir = await databaseFactory.getDatabasesPath();
  return join(dir, DbConstants.dbName);
}

Future<void> _resetDb() async {
  await DbProvider().closeDb();
  final file = File(await _dbFilePath());
  if (await file.exists()) {
    await file.delete();
  }
}

/// テストごとに固定戻り値を返す実処理の差し替え一式を作る。
/// 全ステップを差し替えることで、テストが意図せず本物のスクレイパーへ
/// フォールバックしないようにする。
Map<PreparationStep, PreparationStepExecutor> _fakeExecutors({
  int Function()? shutuba,
  int Function()? horseProfile,
  int Function()? horsePerformance,
  int Function()? pastRaceResults,
  int Function()? training,
}) {
  Future<int> wrap(int Function()? fn) async => fn == null ? 0 : fn();
  return {
    PreparationStep.shutuba: ({
      required raceId,
      required raceDate,
      required horseIds,
      required force,
    }) =>
        wrap(shutuba),
    PreparationStep.horseProfile: ({
      required raceId,
      required raceDate,
      required horseIds,
      required force,
    }) =>
        wrap(horseProfile),
    PreparationStep.horsePerformance: ({
      required raceId,
      required raceDate,
      required horseIds,
      required force,
    }) =>
        wrap(horsePerformance),
    PreparationStep.pastRaceResults: ({
      required raceId,
      required raceDate,
      required horseIds,
      required force,
    }) =>
        wrap(pastRaceResults),
    PreparationStep.training: ({
      required raceId,
      required raceDate,
      required horseIds,
      required force,
    }) =>
        wrap(training),
  };
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir =
        await Directory.systemTemp.createTemp('race_preparation_service_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    await _resetDb();
    ScrapingManager().clearQueue();
  });

  tearDown(() async {
    await _resetDb();
    ScrapingManager().clearQueue();
  });

  group('RacePreparationService.enqueuePreparation', () {
    test('正常終了した実処理のあと、該当ステップがdoneでitemCountに戻り値が記録される', () async {
      final repository = RacePreparationRepository();
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(shutuba: () => 18),
      );

      await service.enqueuePreparation(
        raceId: 'S1',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        only: {PreparationStep.shutuba},
      );
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      final result = await repository.getStep('S1', PreparationStep.shutuba);
      expect(result, isNotNull);
      expect(result!.state, PreparationState.done);
      expect(result.itemCount, 18);
    });

    test('実処理が0を返した場合もdoneかつitemCount:0になる', () async {
      final repository = RacePreparationRepository();
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(shutuba: () => 0),
      );

      await service.enqueuePreparation(
        raceId: 'S2',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        only: {PreparationStep.shutuba},
      );
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      final result = await repository.getStep('S2', PreparationStep.shutuba);
      expect(result, isNotNull);
      expect(result!.state, PreparationState.done);
      expect(result.itemCount, 0);
    });

    test('実処理が例外を投げた場合、failedとerrorが記録され例外は伝播しない', () async {
      final repository = RacePreparationRepository();
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(
          shutuba: () => throw Exception('boom'),
        ),
      );

      await service.enqueuePreparation(
        raceId: 'S3',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        only: {PreparationStep.shutuba},
      );
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      final result = await repository.getStep('S3', PreparationStep.shutuba);
      expect(result, isNotNull);
      expect(result!.state, PreparationState.failed);
      expect(result.error, contains('boom'));
    });

    test('force:falseで既にdoneのステップは再投入されない', () async {
      final repository = RacePreparationRepository();
      int calls = 0;
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(shutuba: () {
          calls++;
          return 5;
        }),
      );
      await repository.markState('S4', PreparationStep.shutuba, PreparationState.done,
          itemCount: 5);

      await service.enqueuePreparation(
        raceId: 'S4',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        only: {PreparationStep.shutuba},
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(calls, 0);
    });

    test('force:trueならdoneでも再投入される', () async {
      final repository = RacePreparationRepository();
      int calls = 0;
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(shutuba: () {
          calls++;
          return 7;
        }),
      );
      await repository.markState('S5', PreparationStep.shutuba, PreparationState.done,
          itemCount: 5);

      await service.enqueuePreparation(
        raceId: 'S5',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        force: true,
        only: {PreparationStep.shutuba},
      );
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      expect(calls, 1);
      final result = await repository.getStep('S5', PreparationStep.shutuba);
      expect(result!.state, PreparationState.done);
      expect(result.itemCount, 7);
    });

    test('依存元がdoneでないステップは投入されない(shutubaがpendingのときpastRaceResultsは投入されない)', () async {
      final repository = RacePreparationRepository();
      int calls = 0;
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(pastRaceResults: () {
          calls++;
          return 1;
        }),
      );

      await service.enqueuePreparation(
        raceId: 'S6',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        only: {PreparationStep.pastRaceResults},
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(calls, 0);
      final result =
          await repository.getStep('S6', PreparationStep.pastRaceResults);
      expect(result, isNull);
    });

    test('raceStatisticsは投入されずskippedが記録される', () async {
      final repository = RacePreparationRepository();
      final service = RacePreparationService(
        repository: repository,
        stepExecutors: _fakeExecutors(),
      );

      await service.enqueuePreparation(
        raceId: 'S7',
        raceDate: '2026年9月6日',
        horseIds: const ['h1'],
        raceName: 'テストステークス',
        only: {PreparationStep.raceStatistics},
      );

      final result =
          await repository.getStep('S7', PreparationStep.raceStatistics);
      expect(result, isNotNull);
      expect(result!.state, PreparationState.skipped);
    });
  });

  group('RacePreparationService.reset', () {
    test('reset()後に全ステップが未記録に戻る', () async {
      final repository = RacePreparationRepository();
      final service = RacePreparationService(repository: repository);

      await repository.markState(
          'S8', PreparationStep.shutuba, PreparationState.done, itemCount: 1);
      await repository.markState(
          'S8', PreparationStep.training, PreparationState.failed, error: 'x');

      await service.reset('S8');

      final all = await repository.getForRace('S8');
      expect(all, isEmpty);
    });
  });
}
