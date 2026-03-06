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
import 'package:hetaumakeiba_v2/models/race_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart'; // ▼ 新規追加: 出馬表データ復元用

class RaceRepository {
  final DbProvider _dbProvider = DbProvider();

// ▼▼ 新規追加: 新テーブルへの安全なUPSERT（既存データを保持しながら上書き） ▼▼
  Future<void> _upsertIntegratedRace(String raceId, Map<String, dynamic> newData) async {
    final db = await _dbProvider.database;
    // 既存レコードを取得
    final existing = await db.query(
      DbConstants.tableIntegratedRaces,
      where: '${DbConstants.colRaceId} = ?',
      whereArgs: [raceId],
      limit: 1,
    );

    Map<String, dynamic> rowToInsert = {};
    if (existing.isNotEmpty) {
      // 既存レコードがある場合はベースとして引き継ぐ
      rowToInsert.addAll(existing.first);
    } else {
      rowToInsert[DbConstants.colRaceId] = raceId;
    }

    // 今回更新するデータで上書き
    rowToInsert.addAll(newData);

    await db.insert(
      DbConstants.tableIntegratedRaces,
      rowToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // ▲▲ 新規追加 ▲▲

  // ===========================================================================
  // レース結果 (race_results -> integrated_races)
  // ===========================================================================

  Future<RaceResult?> getRaceResult(String raceId) async {
    final db = await _dbProvider.database;

    // ▼ 1. 新テーブルから検索
    final newMaps = await db.query(
      DbConstants.tableIntegratedRaces,
      where: '${DbConstants.colRaceId} = ? AND ${DbConstants.colHasResult} = 1',
      whereArgs: [raceId],
      limit: 1,
    );

    if (newMaps.isNotEmpty) {
      final jsonString = newMaps.first[DbConstants.colResultJson] as String?;
      if (jsonString != null) {
        return raceResultFromJson(jsonString);
      }
    }

    // ▼ 2. なければ旧テーブルから検索
    final oldMaps = await db.query(
      DbConstants.tableRaceResults,
      where: 'race_id = ?',
      whereArgs: [raceId],
    );

    if (oldMaps.isNotEmpty) {
      final result = raceResultFromJson(oldMaps.first['race_result_json'] as String);

      // ▼ 3. 旧テーブルにデータがあれば、新テーブルへ統合保存（クッション移行）
      await insertOrUpdateRaceResult(result);

      return result;
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
    // ▼ 新テーブルへの統合保存に書き換え
    final Map<String, dynamic> newData = {
      DbConstants.colHasResult: 1,
      DbConstants.colResultJson: raceResultToJson(raceResult),
      DbConstants.colResultLastUpdated: DateTime.now().toIso8601String(),
    };

    await _upsertIntegratedRace(raceResult.raceId, newData);
    return 1; // 互換性維持のため
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
  // 出馬表キャッシュ (shutuba_table_cache -> integrated_races)
  // ===========================================================================

  Future<ShutubaTableCache?> getShutubaTableCache(String raceId) async {
    final db = await _dbProvider.database;

    // ▼ 1. 新テーブルから検索
    final newMaps = await db.query(
      DbConstants.tableIntegratedRaces,
      where: '${DbConstants.colRaceId} = ? AND ${DbConstants.colHasShutuba} = 1',
      whereArgs: [raceId],
      limit: 1,
    );

    if (newMaps.isNotEmpty) {
      final map = newMaps.first;
      final jsonString = map[DbConstants.colShutubaJson] as String?;
      final lastUpdatedStr = map[DbConstants.colShutubaLastUpdated] as String?;
      if (jsonString != null && lastUpdatedStr != null) {
        final data = PredictionRaceData.fromJson(jsonDecode(jsonString));
        return ShutubaTableCache(
          raceId: raceId,
          predictionRaceData: data,
          lastUpdatedAt: DateTime.parse(lastUpdatedStr),
        );
      }
    }

    // ▼ 2. なければ旧テーブルから検索
    final oldMaps = await db.query(
      DbConstants.tableShutubaTableCache,
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );

    if (oldMaps.isNotEmpty) {
      final cache = ShutubaTableCache.fromMap(oldMaps.first);

      // ▼ 3. 旧テーブルにデータがあれば、新テーブルへ統合保存（クッション移行）
      // ※ Phase 1の補完ロジックを通った16項目の環境データも抽出して保存される
      await insertOrUpdateShutubaTableCache(cache);

      return cache;
    }
    return null;
  }

  Future<void> insertOrUpdateShutubaTableCache(ShutubaTableCache cache) async {
    final data = cache.predictionRaceData;

    // ▼ 新テーブルへの統合保存に書き換え（16項目の細分化データを抽出してセット）
    final Map<String, dynamic> newData = {
      DbConstants.colTrackType: data.trackType,
      DbConstants.colDistanceValue: data.distanceValue,
      DbConstants.colDirection: data.direction,
      DbConstants.colCourseInOut: data.courseInOut,
      DbConstants.colWeather: data.weather,
      DbConstants.colTrackCondition: data.trackCondition,
      DbConstants.colHoldingTimes: data.holdingTimes,
      DbConstants.colHoldingDays: data.holdingDays,
      DbConstants.colRaceCategory: data.raceCategory,
      DbConstants.colHorseCount: data.horseCount,
      DbConstants.colStartTime: data.startTime,
      DbConstants.colBasePrize1st: data.basePrize1st,
      DbConstants.colBasePrize2nd: data.basePrize2nd,
      DbConstants.colBasePrize3rd: data.basePrize3rd,
      DbConstants.colBasePrize4th: data.basePrize4th,
      DbConstants.colBasePrize5th: data.basePrize5th,
      DbConstants.colHasShutuba: 1,
      DbConstants.colShutubaJson: jsonEncode(data.toJson()),
      DbConstants.colShutubaLastUpdated: cache.lastUpdatedAt.toIso8601String(),
    };

    await _upsertIntegratedRace(cache.raceId, newData);
  }

  Future<void> insertShutubaTableCache(ShutubaTableCache cache) async {
    // 内部実装は insertOrUpdateShutubaTableCache と同一
    await insertOrUpdateShutubaTableCache(cache);
  }


  // ===========================================================================
  // レース総評メモ (race_memos) ▼ 新規追加
  // ===========================================================================

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