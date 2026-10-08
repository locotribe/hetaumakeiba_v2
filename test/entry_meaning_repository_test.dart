// test/entry_meaning_repository_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/entry_meaning_repository.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning_snapshot.dart';

/// EntryMeaningRepository は DbProvider() シングルトン経由の固定パスでDBへアクセスするため、
/// race_preparation_repository_test と同じく databaseFactory を ffi 実装へ差し替えて、
/// 本番と同じ DbProvider._onCreate / _onUpgrade をそのまま検証する。
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

EntryMeaningSnapshot _snapshot(
  String raceId, {
  String fact = '休み明け（2ヶ月・84日ぶり）',
  EntryMeaningPreparation preparation = EntryMeaningPreparation.done,
}) {
  return EntryMeaningSnapshot(
    raceId: raceId,
    meanings: RaceEntryMeanings(
      isSupported: true,
      raceNotes: const [],
      horses: [
        HorseEntryMeaning(
          horseId: '2022100001',
          horseNumber: 1,
          horseName: '馬1',
          isScratched: false,
          lines: [
            EntryMeaningLine(
              kind: EntryMeaningKind.layoff,
              fact: fact,
              interpretation: null,
              basis: EntryMeaningBasis.fact,
            ),
          ],
        ),
      ],
    ),
    preparation: preparation,
    computedAt: DateTime(2026, 10, 3, 21, 15),
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと DB ファイルを共有しないよう、ファイル固有の一時ディレクトリへ隔離する
    final tempDir =
        await Directory.systemTemp.createTemp('entry_meaning_repo_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  group('EntryMeaningRepository', () {
    setUp(() async {
      await _resetDb();
    });

    tearDown(() async {
      await _resetDb();
    });

    test('保存 → 読み出しで同じ内容に戻る', () async {
      final repo = EntryMeaningRepository();
      await repo.save(_snapshot('R1', preparation: EntryMeaningPreparation.inProgress));

      final result = await repo.getForRace('R1');
      expect(result, isNotNull);
      expect(result!.raceId, 'R1');
      expect(result.preparation, EntryMeaningPreparation.inProgress);
      expect(result.computedAt, DateTime(2026, 10, 3, 21, 15));
      expect(result.meanings.isSupported, true);
      expect(result.horseOf('2022100001')!.lines.single.fact,
          '休み明け（2ヶ月・84日ぶり）');
    });

    test('同じレースに2回保存すると上書きされる', () async {
      final repo = EntryMeaningRepository();
      await repo.save(_snapshot('R2', fact: '古い行'));
      await repo.save(_snapshot('R2', fact: '新しい行'));

      final result = await repo.getForRace('R2');
      expect(result!.horseOf('2022100001')!.lines.single.fact, '新しい行');

      final db = await DbProvider().database;
      final rows = await db.query(DbConstants.tableEntryMeaningCache,
          where: 'race_id = ?', whereArgs: ['R2']);
      expect(rows.length, 1);
    });

    test('保存の無いレースは null', () async {
      final repo = EntryMeaningRepository();
      expect(await repo.getForRace('NONE'), isNull);
    });
  });

  group('マイグレーション(v20 -> v21)', () {
    setUp(() async {
      await _resetDb();
    });

    tearDown(() async {
      await _resetDb();
    });

    test('旧バージョン(20)のDBを開くと entry_meaning_cache が新設され、保存できる', () async {
      final path = await _dbFilePath();
      final oldDb = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 20),
      );
      await oldDb.close();

      final db = await DbProvider().database;
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', DbConstants.tableEntryMeaningCache],
      );
      expect(tables, isNotEmpty);

      final repo = EntryMeaningRepository();
      await repo.save(_snapshot('M1'));
      expect(await repo.getForRace('M1'), isNotNull);
    });
  });
}
