// lib/db/repositories/jyusyo_race_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';

class JyusyoRaceRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<void> mergeJyusyoRaces(List<dynamic> races) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      for (var race in races) {
        final raceMap = (race as dynamic).toMap();
        final List<Map<String, dynamic>> existing = await txn.query(
          DbConstants.tableJyusyoRaces,
          columns: ['id', 'race_id'],
          where: 'year = ? AND date = ? AND race_name = ?',
          whereArgs: [raceMap['year'], raceMap['date'], raceMap['race_name']],
        );

        if (existing.isNotEmpty) {
          final currentId = existing.first['id'];
          final currentRaceId = existing.first['race_id'] as String?;
          final newRaceId = raceMap['race_id'] as String?;

          Map<String, dynamic> updateValues = {
            'grade': raceMap['grade'],
            'venue': raceMap['venue'],
            'distance': raceMap['distance'],
            'conditions': raceMap['conditions'],
            'weight': raceMap['weight'],
            'source_url': raceMap['source_url'],
          };

          if (currentRaceId == null && newRaceId != null) {
            updateValues['race_id'] = newRaceId;
          }

          await txn.update(
            DbConstants.tableJyusyoRaces,
            updateValues,
            where: 'id = ?',
            whereArgs: [currentId],
          );
        } else {
          await txn.insert(DbConstants.tableJyusyoRaces, raceMap);
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getJyusyoRacesByYear(int year) async {
    final db = await _dbProvider.database;
    return await db.query(
      DbConstants.tableJyusyoRaces,
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'id ASC',
    );
  }

  Future<void> updateJyusyoRaceId(int id, String newRaceId) async {
    final db = await _dbProvider.database;
    await db.update(
      DbConstants.tableJyusyoRaces,
      {'race_id': newRaceId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateJyusyoRaceIdByNameAndYear(String raceName, int year, String newRaceId) async {
    final db = await _dbProvider.database;
    await db.update(
      DbConstants.tableJyusyoRaces,
      {'race_id': newRaceId},
      where: 'race_name = ? AND year = ? AND (race_id IS NULL OR race_id = "")',
      whereArgs: [raceName, year],
    );
  }
}