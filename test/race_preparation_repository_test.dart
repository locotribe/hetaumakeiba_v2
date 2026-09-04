// test/race_preparation_repository_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_preparation_repository.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';

/// RacePreparationRepository は HorseSpeedIndexRepository と同様に
/// DbProvider() シングルトン経由の固定パスでDBへアクセスするため、
/// テストでは sqflite の databaseFactory 自体を ffi 実装へ差し替えることで、
/// 本番と同じ DbProvider._onCreate / _onUpgrade の実装をそのまま検証する。
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

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 実DBパスを他のテストファイルと共有するとflutter testの並列実行時に
    // ファイル競合でflakyになるため、ファイル固有の一時ディレクトリへ隔離する
    final tempDir = await Directory.systemTemp
        .createTemp('race_preparation_repo_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  group('RacePreparationRepository CRUD', () {
    setUp(() async {
      await _resetDb();
    });

    tearDown(() async {
      await _resetDb();
    });

    test('upsert -> getStep のラウンドトリップ', () async {
      final repo = RacePreparationRepository();
      final updatedAt = DateTime.parse('2026-09-05T10:00:00.000');
      final status = RacePreparationStatus(
        raceId: 'R1',
        step: PreparationStep.training,
        state: PreparationState.failed,
        itemCount: 3,
        updatedAt: updatedAt,
        error: 'timeout',
      );
      await repo.upsert(status);

      final result = await repo.getStep('R1', PreparationStep.training);
      expect(result, isNotNull);
      expect(result!.raceId, 'R1');
      expect(result.step, PreparationStep.training);
      expect(result.state, PreparationState.failed);
      expect(result.itemCount, 3);
      expect(result.updatedAt, updatedAt);
      expect(result.error, 'timeout');
    });

    test('同じ(raceId, step)に2回upsertすると上書きされ、行が増えない', () async {
      final repo = RacePreparationRepository();
      await repo.upsert(RacePreparationStatus(
        raceId: 'R2',
        step: PreparationStep.shutuba,
        state: PreparationState.pending,
        updatedAt: DateTime.parse('2026-09-01T00:00:00.000'),
      ));
      await repo.upsert(RacePreparationStatus(
        raceId: 'R2',
        step: PreparationStep.shutuba,
        state: PreparationState.done,
        itemCount: 18,
        updatedAt: DateTime.parse('2026-09-05T00:00:00.000'),
      ));

      final result = await repo.getStep('R2', PreparationStep.shutuba);
      expect(result, isNotNull);
      expect(result!.state, PreparationState.done);
      expect(result.itemCount, 18);

      final all = await repo.getForRace('R2');
      expect(all.length, 1);
    });

    test('getForRaceは複数ステップをstepキーのMapで返す', () async {
      final repo = RacePreparationRepository();
      await repo.upsert(RacePreparationStatus(
        raceId: 'R3',
        step: PreparationStep.shutuba,
        state: PreparationState.done,
        itemCount: 18,
        updatedAt: DateTime.parse('2026-09-05T00:00:00.000'),
      ));
      await repo.upsert(RacePreparationStatus(
        raceId: 'R3',
        step: PreparationStep.horseProfile,
        state: PreparationState.running,
        updatedAt: DateTime.parse('2026-09-05T00:01:00.000'),
      ));

      final all = await repo.getForRace('R3');
      expect(all.length, 2);
      expect(all[PreparationStep.shutuba]?.state, PreparationState.done);
      expect(all[PreparationStep.horseProfile]?.state, PreparationState.running);
    });

    test('存在しないraceIdに対してgetForRaceは空Map、getStepはnullを返す', () async {
      final repo = RacePreparationRepository();
      final all = await repo.getForRace('NO_SUCH_RACE');
      expect(all, isEmpty);

      final step = await repo.getStep('NO_SUCH_RACE', PreparationStep.shutuba);
      expect(step, isNull);
    });

    test('markStateでdone/itemCount0を記録でき、pending(未取得)と区別できる', () async {
      final repo = RacePreparationRepository();
      await repo.markState(
        'R4',
        PreparationStep.training,
        PreparationState.done,
        itemCount: 0,
      );

      final result = await repo.getStep('R4', PreparationStep.training);
      expect(result, isNotNull);
      expect(result!.state, PreparationState.done);
      expect(result.itemCount, 0);

      // 未取得(該当レコードが無い)場合はnullであり、
      // done/itemCount:0(取得したが0件)とは区別される
      final untouched =
          await repo.getStep('R4', PreparationStep.raceStatistics);
      expect(untouched, isNull);
    });

    test('deleteForRace後にgetForRaceが空Mapを返す', () async {
      final repo = RacePreparationRepository();
      await repo.upsert(RacePreparationStatus(
        raceId: 'R5',
        step: PreparationStep.shutuba,
        state: PreparationState.done,
        updatedAt: DateTime.parse('2026-09-05T00:00:00.000'),
      ));
      await repo.upsert(RacePreparationStatus(
        raceId: 'R5',
        step: PreparationStep.training,
        state: PreparationState.pending,
        updatedAt: DateTime.parse('2026-09-05T00:00:00.000'),
      ));

      await repo.deleteForRace('R5');

      final all = await repo.getForRace('R5');
      expect(all, isEmpty);
    });
  });

  group('マイグレーション(v13 -> v16)', () {
    setUp(() async {
      await _resetDb();
    });

    tearDown(() async {
      await _resetDb();
    });

    test('旧バージョン(13)のDBを開くとrace_preparation_statusが例外なく新設される', () async {
      final path = await _dbFilePath();
      final oldDb = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 13),
      );
      await oldDb.close();

      final db = await DbProvider().database;
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', DbConstants.tableRacePreparationStatus],
      );
      expect(tables, isNotEmpty);

      // アップグレード後、実際にCRUDが機能することも確認する
      final repo = RacePreparationRepository();
      await repo.upsert(RacePreparationStatus(
        raceId: 'M1',
        step: PreparationStep.shutuba,
        state: PreparationState.done,
        itemCount: 18,
        updatedAt: DateTime.parse('2026-09-05T00:00:00.000'),
      ));
      final result = await repo.getStep('M1', PreparationStep.shutuba);
      expect(result, isNotNull);
      expect(result!.itemCount, 18);
    });
  });
}
