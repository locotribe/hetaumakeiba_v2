// lib/db/repositories/race_repository.dart

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/shutuba_table_cache_repository.dart';

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
      limit: 1,
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
          debugPrint('Error parsing race result in searchRaceResultsByName: $e');
        }
      }
    }
    return matches;
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

  /// スクレイピングで取得した新しいスケジュールで既存データを更新する。
  /// 既存データに保存されている isConfirmed の状態を引き継ぐ。
  Future<int> mergeRaceSchedule(RaceSchedule newSchedule) async {
    final db = await _dbProvider.database;

    // 既存のスケジュールを取得して isConfirmed の状態を引き継ぐ
    final existing = await getRaceSchedule(newSchedule.date);

    if (existing != null) {
      // 既存データの isConfirmed を raceId をキーにしてマップ化
      final Map<String, bool> confirmedMap = {};
      for (final venue in existing.venues) {
        for (final race in venue.races) {
          confirmedMap[race.raceId] = race.isConfirmed;
        }
      }

      // 新しいスケジュールの各レースに既存の isConfirmed を引き継ぐ
      for (final venue in newSchedule.venues) {
        for (final race in venue.races) {
          if (confirmedMap.containsKey(race.raceId)) {
            race.isConfirmed = confirmedMap[race.raceId]!;
          }
        }
      }
    }

    return await db.insert(
      DbConstants.tableRaceSchedules,
      {
        'date': newSchedule.date,
        'dayOfWeek': newSchedule.dayOfWeek,
        'scheduleJson': raceScheduleToJson(newSchedule),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===========================================================================
  // 出馬表キャッシュ (shutuba_table_cache)
  // ===========================================================================

  final ShutubaTableCacheRepository _shutubaTableCacheRepository = ShutubaTableCacheRepository();

  // [一時] Phase 3 移行用の委譲ブリッジ。Phase 3-D で削除する
  @Deprecated('ShutubaTableCacheRepository を直接使用してください')
  Future<ShutubaTableCache?> getShutubaTableCache(String raceId) =>
      _shutubaTableCacheRepository.getShutubaTableCache(raceId);

  // [一時] Phase 3 移行用の委譲ブリッジ。Phase 3-D で削除する
  @Deprecated('ShutubaTableCacheRepository を直接使用してください')
  Future<void> insertOrUpdateShutubaTableCache(ShutubaTableCache cache) =>
      _shutubaTableCacheRepository.insertOrUpdateShutubaTableCache(cache);

  // [一時] Phase 3 移行用の委譲ブリッジ。Phase 3-D で削除する
  @Deprecated('ShutubaTableCacheRepository を直接使用してください')
  Future<void> insertShutubaTableCache(ShutubaTableCache cache) =>
      _shutubaTableCacheRepository.insertShutubaTableCache(cache);
}