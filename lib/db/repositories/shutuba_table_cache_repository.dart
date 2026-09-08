// lib/db/repositories/shutuba_table_cache_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';

class ShutubaTableCacheRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<ShutubaTableCache?> getShutubaTableCache(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableShutubaTableCache,
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ShutubaTableCache.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertOrUpdateShutubaTableCache(ShutubaTableCache cache) async {
    final db = await _dbProvider.database;
    await db.insert(
      DbConstants.tableShutubaTableCache,
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertShutubaTableCache(ShutubaTableCache cache) async {
    await insertOrUpdateShutubaTableCache(cache);
  }
}
