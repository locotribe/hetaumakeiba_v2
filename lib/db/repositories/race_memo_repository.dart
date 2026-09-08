// lib/db/repositories/race_memo_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_memo_model.dart';

class RaceMemoRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<RaceMemo?> getRaceMemo(String userId, String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableRaceMemos,
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return RaceMemo.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertOrUpdateRaceMemo(RaceMemo memo) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableRaceMemos,
      memo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteRaceMemo(String userId, String raceId) async {
    final db = await _dbProvider.database;
    return await db.delete(
      DbConstants.tableRaceMemos,
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
    );
  }
}
