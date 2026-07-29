// test/horse_speed_index_repository_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_speed_index_repository.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';

/// HorseSpeedIndexRepository は HorseSimulationParamsRepository と同様に
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HorseSpeedIndexRepository CRUD', () {
    setUp(() async {
      await _resetDb();
    });

    tearDown(() async {
      await _resetDb();
    });

    test('upsert -> getByHorseId のラウンドトリップ', () async {
      final repo = HorseSpeedIndexRepository();
      final data = HorseSpeedIndex(
        horseId: '2020101779',
        bestIndex: 82.5,
        recentAvgIndex: 78.3,
        trend: 1.2,
        confidence: 0.75,
        sampleCount: 8,
        calculatedAt: '2026-07-29T00:00:00.000',
      );
      await repo.upsert(data);

      final result = await repo.getByHorseId('2020101779');
      expect(result, isNotNull);
      expect(result!.horseId, '2020101779');
      expect(result.bestIndex, 82.5);
      expect(result.recentAvgIndex, 78.3);
      expect(result.trend, 1.2);
      expect(result.confidence, 0.75);
      expect(result.sampleCount, 8);
      expect(result.calculatedAt, '2026-07-29T00:00:00.000');
    });

    test('upsert は同一horse_idのレコードを上書きする', () async {
      final repo = HorseSpeedIndexRepository();
      await repo.upsert(HorseSpeedIndex(
        horseId: 'H1',
        bestIndex: 70.0,
        recentAvgIndex: 65.0,
        trend: 0.0,
        confidence: 0.5,
        sampleCount: 3,
        calculatedAt: '2026-07-01T00:00:00.000',
      ));
      await repo.upsert(HorseSpeedIndex(
        horseId: 'H1',
        bestIndex: 90.0,
        recentAvgIndex: 85.0,
        trend: 2.0,
        confidence: 0.9,
        sampleCount: 5,
        calculatedAt: '2026-07-29T00:00:00.000',
      ));

      final result = await repo.getByHorseId('H1');
      expect(result, isNotNull);
      expect(result!.bestIndex, 90.0);
      expect(result.sampleCount, 5);
    });

    test('upsertBatch -> getByHorseIds でMap化して取得できる', () async {
      final repo = HorseSpeedIndexRepository();
      await repo.upsertBatch([
        HorseSpeedIndex(
          horseId: 'A1',
          bestIndex: 80.0,
          recentAvgIndex: 75.0,
          trend: 0.5,
          confidence: 0.6,
          sampleCount: 4,
          calculatedAt: '2026-07-29T00:00:00.000',
        ),
        HorseSpeedIndex(
          horseId: 'A2',
          bestIndex: 88.0,
          recentAvgIndex: 84.0,
          trend: -0.3,
          confidence: 0.8,
          sampleCount: 6,
          calculatedAt: '2026-07-29T00:00:00.000',
        ),
      ]);

      final map = await repo.getByHorseIds(['A1', 'A2', 'A3']);
      expect(map.length, 2);
      expect(map['A1']?.bestIndex, 80.0);
      expect(map['A2']?.bestIndex, 88.0);
      expect(map.containsKey('A3'), isFalse);
    });

    test('getByHorseIds は空リストを渡すと空Mapを返す', () async {
      final repo = HorseSpeedIndexRepository();
      final map = await repo.getByHorseIds([]);
      expect(map, isEmpty);
    });

    test('deleteByHorseId で該当レコードを削除できる', () async {
      final repo = HorseSpeedIndexRepository();
      await repo.upsert(HorseSpeedIndex(
        horseId: 'D1',
        bestIndex: 60.0,
        recentAvgIndex: 55.0,
        trend: 0.0,
        confidence: 0.4,
        sampleCount: 2,
        calculatedAt: '2026-07-29T00:00:00.000',
      ));
      await repo.deleteByHorseId('D1');

      final result = await repo.getByHorseId('D1');
      expect(result, isNull);
    });
  });

  group('マイグレーション(v13 -> v15)', () {
    setUp(() async {
      await _resetDb();
    });

    tearDown(() async {
      await _resetDb();
    });

    test('旧バージョン(13)のDBを開くとhorse_speed_indexが例外なく新設される', () async {
      // DbProviderが実際に使うのと同一パスへ、テーブルを一切持たないv13相当の
      // 空DBファイルを直接作成し、DbProvider().database経由で開いたときに
      // 本番の _onUpgrade が例外を握り潰さず正常完了することを検証する。
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
        whereArgs: ['table', DbConstants.tableHorseSpeedIndex],
      );
      expect(tables, isNotEmpty);

      // アップグレード後、実際にCRUDが機能することも確認する
      final repo = HorseSpeedIndexRepository();
      await repo.upsert(HorseSpeedIndex(
        horseId: 'M1',
        bestIndex: 77.0,
        recentAvgIndex: 70.0,
        trend: 0.1,
        confidence: 0.55,
        sampleCount: 3,
        calculatedAt: '2026-07-29T00:00:00.000',
      ));
      final result = await repo.getByHorseId('M1');
      expect(result, isNotNull);
      expect(result!.bestIndex, 77.0);
    });
  });
}
