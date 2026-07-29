// lib/db/repositories/horse_speed_index_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';

/// horse_speed_index テーブルの CRUD を担当するリポジトリ。
class HorseSpeedIndexRepository {
  Future<Database> get _db async => await DbProvider().database;

  Future<void> upsert(HorseSpeedIndex speedIndex) async {
    final db = await _db;
    await db.insert(
      DbConstants.tableHorseSpeedIndex,
      speedIndex.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertBatch(List<HorseSpeedIndex> speedIndexList) async {
    final db = await _db;
    final batch = db.batch();
    for (final speedIndex in speedIndexList) {
      batch.insert(
        DbConstants.tableHorseSpeedIndex,
        speedIndex.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<HorseSpeedIndex?> getByHorseId(String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorseSpeedIndex,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HorseSpeedIndex.fromMap(maps.first);
  }

  Future<Map<String, HorseSpeedIndex>> getByHorseIds(
    List<String> horseIds,
  ) async {
    if (horseIds.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(horseIds.length, '?').join(',');
    final maps = await db.query(
      DbConstants.tableHorseSpeedIndex,
      where: 'horse_id IN ($placeholders)',
      whereArgs: horseIds,
    );
    return {
      for (final m in maps)
        (m['horse_id'] as String): HorseSpeedIndex.fromMap(m),
    };
  }

  Future<void> deleteByHorseId(String horseId) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableHorseSpeedIndex,
      where: 'horse_id = ?',
      whereArgs: [horseId],
    );
  }
}
