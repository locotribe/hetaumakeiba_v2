// lib/db/repositories/race_statistics_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';

class RaceStatisticsRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<int> insertOrUpdateRaceStatistics(RaceStatistics stats) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableRaceStatistics,
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RaceStatistics?> getRaceStatistics(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableRaceStatistics,
      where: 'raceId = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return RaceStatistics.fromMap(maps.first);
    }
    return null;
  }

  Future<void> clearRaceStatistics() async {
    final db = await _dbProvider.database;
    await db.delete(DbConstants.tableRaceStatistics);
  }
}
