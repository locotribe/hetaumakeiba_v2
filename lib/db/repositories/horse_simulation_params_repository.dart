// lib/db/repositories/horse_simulation_params_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';

/// horse_simulation_params テーブルの CRUD を担当するリポジトリ。
class HorseSimulationParamsRepository {
  Future<Database> get _db async => await DbProvider().database;

  Future<void> upsert(HorseSimulationParams params) async {
    final db = await _db;
    await db.insert(
      DbConstants.tableHorseSimulationParams,
      params.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertBatch(List<HorseSimulationParams> paramsList) async {
    final db = await _db;
    final batch = db.batch();
    for (final params in paramsList) {
      batch.insert(
        DbConstants.tableHorseSimulationParams,
        params.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<HorseSimulationParams?> getByHorseId(String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorseSimulationParams,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HorseSimulationParams.fromMap(maps.first);
  }

  Future<Map<String, HorseSimulationParams>> getByHorseIds(
    List<String> horseIds,
  ) async {
    if (horseIds.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(horseIds.length, '?').join(',');
    final maps = await db.query(
      DbConstants.tableHorseSimulationParams,
      where: 'horse_id IN ($placeholders)',
      whereArgs: horseIds,
    );
    return {
      for (final m in maps)
        (m['horse_id'] as String): HorseSimulationParams.fromMap(m),
    };
  }

  Future<void> deleteByHorseId(String horseId) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableHorseSimulationParams,
      where: 'horse_id = ?',
      whereArgs: [horseId],
    );
  }
}
