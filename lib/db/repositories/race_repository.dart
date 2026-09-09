// lib/db/repositories/race_repository.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_schedule_repository.dart';

class RaceRepository {
  final DbProvider _dbProvider = DbProvider();
  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  final RaceScheduleRepository _raceScheduleRepository = RaceScheduleRepository();

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

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<int> insertOrUpdateRaceSchedule(RaceSchedule schedule) =>
      _raceScheduleRepository.insertOrUpdateRaceSchedule(schedule);

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<Map<String, RaceSchedule>> getMultipleRaceSchedules(List<String> dates) =>
      _raceScheduleRepository.getMultipleRaceSchedules(dates);

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<RaceSchedule?> getRaceSchedule(String date) =>
      _raceScheduleRepository.getRaceSchedule(date);

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<void> insertOrUpdateWeekCache(String weekKey, List<String> availableDates) =>
      _raceScheduleRepository.insertOrUpdateWeekCache(weekKey, availableDates);

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<List<String>?> getWeekCache(String weekKey) =>
      _raceScheduleRepository.getWeekCache(weekKey);

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<String?> getDateFromScheduleByRaceId(String raceId) =>
      _raceScheduleRepository.getDateFromScheduleByRaceId(raceId);

  // [一時] Phase 4 移行用の委譲ブリッジ。Phase 4-C で削除する
  @Deprecated('RaceScheduleRepository を直接使用してください')
  Future<int> mergeRaceSchedule(RaceSchedule newSchedule) =>
      _raceScheduleRepository.mergeRaceSchedule(newSchedule);

}