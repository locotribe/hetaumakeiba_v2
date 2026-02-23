// lib/db/repositories/race_repository.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';

class RaceRepository {
  final DbProvider _dbProvider = DbProvider();

  // ===========================================================================
  // レース結果 (race_results)
  // ===========================================================================

  Future<RaceResult?> getRaceResult(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableRaceResults,
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    if (maps.isNotEmpty) {
      return raceResultFromJson(maps.first['race_result_json'] as String);
    }
    return null;
  }

  Future<Map<String, RaceResult>> getMultipleRaceResults(List<String> raceIds) async {
    if (raceIds.isEmpty) {
      return {};
    }
    final db = await _dbProvider.database;
    final placeholders = List.filled(raceIds.length, '?').join(',');
    final maps = await db.query(
      DbConstants.tableRaceResults,
      where: 'race_id IN ($placeholders)',
      whereArgs: raceIds,
    );

    final Map<String, RaceResult> results = {};
    for (final map in maps) {
      final result = raceResultFromJson(map['race_result_json'] as String);
      results[result.raceId] = result;
    }
    return results;
  }

  Future<int> insertOrUpdateRaceResult(RaceResult raceResult) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableRaceResults,
      {
        'race_id': raceResult.raceId,
        'race_result_json': raceResultToJson(raceResult),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, RaceResult>> getAllRaceResults() async {
    final db = await _dbProvider.database;
    final maps = await db.query(DbConstants.tableRaceResults);
    final Map<String, RaceResult> results = {};
    for (final map in maps) {
      final result = raceResultFromJson(map['race_result_json'] as String);
      results[result.raceId] = result;
    }
    return results;
  }

  Future<List<RaceResult>> searchRaceResultsByName(String partialName) async {
    final db = await _dbProvider.database;
    final maps = await db.query(DbConstants.tableRaceResults);
    final List<RaceResult> matches = [];

    for (final map in maps) {
      final jsonStr = map['race_result_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final result = raceResultFromJson(jsonStr);
          if (result.raceTitle.contains(partialName)) {
            matches.add(result);
          }
        } catch (e) {
          print('Error parsing race result in searchRaceResultsByName: $e');
        }
      }
    }
    return matches;
  }

  // ===========================================================================
  // 注目レース (featured_races)
  // ===========================================================================

  Future<int> insertOrUpdateFeaturedRace(FeaturedRace featuredRace) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableFeaturedRaces,
      featuredRace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FeaturedRace>> getAllFeaturedRaces() async {
    final db = await _dbProvider.database;
    final maps = await db.query(DbConstants.tableFeaturedRaces, orderBy: 'last_scraped DESC');
    return List.generate(maps.length, (i) {
      return FeaturedRace.fromMap(maps[i]);
    });
  }

  Future<FeaturedRace?> getFeaturedRace(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableFeaturedRaces,
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return FeaturedRace.fromMap(maps.first);
    }
    return null;
  }

  Future<int> deleteAllFeaturedRaces() async {
    final db = await _dbProvider.database;
    return await db.delete(DbConstants.tableFeaturedRaces);
  }

  // ===========================================================================
  // レース統計 (race_statistics)
  // ===========================================================================

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

  // ===========================================================================
  // 開催日程 (race_schedules, week_schedules_cache)
  // ===========================================================================

  Future<int> insertOrUpdateRaceSchedule(RaceSchedule schedule) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableRaceSchedules,
      {
        'date': schedule.date,
        'dayOfWeek': schedule.dayOfWeek,
        'scheduleJson': raceScheduleToJson(schedule),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, RaceSchedule>> getMultipleRaceSchedules(List<String> dates) async {
    if (dates.isEmpty) {
      return {};
    }
    final db = await _dbProvider.database;
    final placeholders = List.filled(dates.length, '?').join(',');
    final maps = await db.query(
      DbConstants.tableRaceSchedules,
      where: 'date IN ($placeholders)',
      whereArgs: dates,
    );

    final Map<String, RaceSchedule> results = {};
    for (final map in maps) {
      final schedule = raceScheduleFromJson(map['scheduleJson'] as String);
      results[schedule.date] = schedule;
    }
    return results;
  }

  Future<RaceSchedule?> getRaceSchedule(String date) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableRaceSchedules,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return raceScheduleFromJson(maps.first['scheduleJson'] as String);
    }
    return null;
  }

  Future<void> insertOrUpdateWeekCache(String weekKey, List<String> availableDates) async {
    final db = await _dbProvider.database;
    await db.insert(
      DbConstants.tableWeekSchedulesCache,
      {
        'week_key': weekKey,
        'available_dates_json': json.encode(availableDates),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>?> getWeekCache(String weekKey) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableWeekSchedulesCache,
      where: 'week_key = ?',
      whereArgs: [weekKey],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final jsonString = maps.first['available_dates_json'] as String;
      return (json.decode(jsonString) as List<dynamic>).cast<String>();
    }
    return null;
  }

  Future<String?> getDateFromScheduleByRaceId(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableRaceSchedules,
      columns: ['date'],
      where: 'scheduleJson LIKE ?',
      whereArgs: ['%$raceId%'],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['date'] as String;
    }
    return null;
  }

  // ===========================================================================
  // 出馬表キャッシュ (shutuba_table_cache)
  // ===========================================================================

  Future<void> insertOrUpdateShutubaTableCache(ShutubaTableCache cache) async {
    final db = await _dbProvider.database;
    await db.insert(
      DbConstants.tableShutubaTableCache,
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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

  Future<void> insertShutubaTableCache(ShutubaTableCache cache) async {
    // 内部実装は insertOrUpdateShutubaTableCache と同一
    await insertOrUpdateShutubaTableCache(cache);
  }

  // ===========================================================================
  // AI予測 (ai_predictions)
  // ===========================================================================

  Future<void> insertOrUpdateAiPredictions(List<AiPrediction> predictions) async {
    final db = await _dbProvider.database;
    final batch = db.batch();
    for (final prediction in predictions) {
      batch.insert(
        DbConstants.tableAiPredictions,
        prediction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AiPrediction>> getAiPredictionsForRace(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableAiPredictions,
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    return List.generate(maps.length, (i) {
      return AiPrediction.fromMap(maps[i]);
    });
  }
}