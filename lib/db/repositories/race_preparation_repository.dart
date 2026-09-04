// lib/db/repositories/race_preparation_repository.dart

// [追加] Phase 4-A: race_preparation_status テーブルのCRUDを担当するリポジトリ。
// この時点ではどこからも呼ばれない（DB層のみの新設） (v.2026.9.5+26090501)

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';

/// race_preparation_status テーブルの CRUD を担当するリポジトリ。
class RacePreparationRepository {
  Future<Database> get _db async => await DbProvider().database;

  Future<void> upsert(RacePreparationStatus status) async {
    final db = await _db;
    await db.insert(
      DbConstants.tableRacePreparationStatus,
      status.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<PreparationStep, RacePreparationStatus>> getForRace(
    String raceId,
  ) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableRacePreparationStatus,
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    final result = <PreparationStep, RacePreparationStatus>{};
    for (final m in maps) {
      final status = RacePreparationStatus.fromMap(m);
      result[status.step] = status;
    }
    return result;
  }

  Future<RacePreparationStatus?> getStep(
    String raceId,
    PreparationStep step,
  ) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableRacePreparationStatus,
      where: 'race_id = ? AND step = ?',
      whereArgs: [raceId, step.name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RacePreparationStatus.fromMap(maps.first);
  }

  Future<void> markState(
    String raceId,
    PreparationStep step,
    PreparationState state, {
    int itemCount = 0,
    String? error,
  }) async {
    await upsert(RacePreparationStatus(
      raceId: raceId,
      step: step,
      state: state,
      itemCount: itemCount,
      updatedAt: DateTime.now(),
      error: error,
    ));
  }

  Future<void> deleteForRace(String raceId) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableRacePreparationStatus,
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
  }
}
