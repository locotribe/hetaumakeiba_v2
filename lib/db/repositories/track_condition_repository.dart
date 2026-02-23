// lib/db/repositories/track_condition_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:csv/csv.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

class TrackConditionRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<int> insertOrUpdateTrackCondition(TrackConditionRecord record) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableTrackConditions,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateMultipleTrackConditions(List<TrackConditionRecord> records) async {
    final db = await _dbProvider.database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        DbConstants.tableTrackConditions,
        record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> generateNextTrackConditionId(String prefix8, String dd) async {
    final db = await _dbProvider.database;

    final result = await db.rawQuery('''
      SELECT MAX(track_condition_id) as max_id 
      FROM ${DbConstants.tableTrackConditions} 
      WHERE CAST(track_condition_id AS TEXT) LIKE ?
    ''', ['$prefix8%']);

    if (result.isNotEmpty && result.first['max_id'] != null) {
      final maxId = result.first['max_id'] as int;
      final currentNn = maxId % 100;
      final nextNn = currentNn + 1;
      return int.parse('$prefix8$dd${nextNn.toString().padLeft(2, '0')}');
    } else {
      return int.parse('$prefix8${dd}01');
    }
  }

  Future<List<TrackConditionRecord>> getTrackConditionsByDate(String date) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableTrackConditions,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'track_condition_id DESC',
    );
    return maps.map((e) => TrackConditionRecord.fromJson(e)).toList();
  }

  Future<List<TrackConditionRecord>> getLatestTrackConditionsForEachCourse() async {
    final db = await _dbProvider.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t1.*
      FROM ${DbConstants.tableTrackConditions} t1
      INNER JOIN (
        SELECT SUBSTR(CAST(track_condition_id AS TEXT), 5, 2) as cc, MAX(date) as max_date
        FROM ${DbConstants.tableTrackConditions}
        GROUP BY SUBSTR(CAST(track_condition_id AS TEXT), 5, 2)
      ) t2 ON SUBSTR(CAST(t1.track_condition_id AS TEXT), 5, 2) = t2.cc AND t1.date = t2.max_date
      ORDER BY t1.date DESC, t1.track_condition_id DESC
    ''');

    return maps.map((e) => TrackConditionRecord.fromJson(e)).toList();
  }

  Future<Map<String, int>> importTrackConditionsFromCsv(String csvString) async {
    final db = await _dbProvider.database;
    int totalValidRows = 0;

    try {
      final cleanCsv = csvString.replaceAll('\r\n', '\n');
      final rows = const CsvToListConverter(eol: '\n').convert(cleanCsv);

      if (rows.length <= 1) return {'inserted': 0, 'duplicates': 0};

      final batch = db.batch();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row[0] == null || row[0].toString().trim().isEmpty) continue;

        final idVal = row[0];
        int? trackConditionId = idVal is int ? idVal : int.tryParse(idVal.toString());
        if (trackConditionId == null) continue;

        totalValidRows++;

        final map = {
          'track_condition_id': trackConditionId,
          'date': row[1]?.toString(),
          'week_day': row[2]?.toString(),
          'cushion_value': double.tryParse(row[3]?.toString() ?? ''),
          'moisture_turf_goal': double.tryParse(row[4]?.toString() ?? ''),
          'moisture_turf_4c': double.tryParse(row[5]?.toString() ?? ''),
          'moisture_dirt_goal': double.tryParse(row[6]?.toString() ?? ''),
          'moisture_dirt_4c': double.tryParse(row[7]?.toString() ?? ''),
        };

        batch.insert(DbConstants.tableTrackConditions, map, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final results = await batch.commit(continueOnError: true);

      int insertedCount = results.where((r) => r != null && r != 0).length;
      int duplicatesCount = totalValidRows - insertedCount;

      return {
        'inserted': insertedCount,
        'duplicates': duplicatesCount,
      };
    } catch (e) {
      print('DEBUG: CSVインポートエラー: $e');
      rethrow;
    }
  }
}