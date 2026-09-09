// lib/db/repositories/race_schedule_repository.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';

class RaceScheduleRepository {
  final DbProvider _dbProvider = DbProvider();

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
}
