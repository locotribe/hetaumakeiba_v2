// lib/db/repositories/horse_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_cache_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';

class HorseRepository {
  Future<Database> get _db async => await DbProvider().database;

  // ===========================================================================
  // 競走馬成績 (horse_performance) 関連
  // ===========================================================================

  Future<int> insertOrUpdateHorsePerformance(HorseRaceRecord record) async {
    final db = await _db;
    return await db.insert(
      DbConstants.tableHorsePerformance,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HorseRaceRecord>> getHorsePerformanceRecords(String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorsePerformance,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return HorseRaceRecord.fromMap(maps[i]);
    });
  }

  Future<HorseRaceRecord?> getLatestHorsePerformanceRecord(String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorsePerformance,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return HorseRaceRecord.fromMap(maps.first);
    }
    return null;
  }

  Future<int> deleteHorsePerformance(String horseId) async {
    final db = await _db;
    return await db.delete(
      DbConstants.tableHorsePerformance,
      where: 'horse_id = ?',
      whereArgs: [horseId],
    );
  }

  Future<List<HorseRaceRecord>> getHorseRaceRecords(String horseId) async {
    return getHorsePerformanceRecords(horseId);
  }

  Future<void> insertHorseRaceRecords(List<HorseRaceRecord> records) async {
    final db = await _db;
    final batch = db.batch();

    for (var record in records) {
      batch.insert(
        DbConstants.tableHorsePerformance,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ===========================================================================
  // 競走馬メモ (horse_memos) 関連
  // ===========================================================================

  Future<int> insertOrUpdateHorseMemo(HorseMemo memo) async {
    final db = await _db;
    return await db.insert(
      DbConstants.tableHorseMemos,
      memo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateMultipleMemos(List<HorseMemo> memos) async {
    final db = await _db;
    final batch = db.batch();
    for (final memo in memos) {
      batch.insert(
        DbConstants.tableHorseMemos,
        memo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<HorseMemo>> getMemosForRace(String userId, String raceId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorseMemos,
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
    );
    return List.generate(maps.length, (i) {
      return HorseMemo.fromMap(maps[i]);
    });
  }

  // ===========================================================================
  // 馬統計キャッシュ (horse_stats_cache) 関連
  // ===========================================================================

  Future<int> insertOrUpdateHorseStatsCache(HorseStatsCache cache) async {
    final db = await _db;
    return await db.insert(
      DbConstants.tableHorseStatsCache,
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<HorseStatsCache?> getHorseStatsCache(String raceId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorseStatsCache,
      where: 'raceId = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return HorseStatsCache.fromMap(maps.first);
    }
    return null;
  }

  // ===========================================================================
  // 競走馬プロフィール (horse_profiles) 関連
  // ===========================================================================

  Future<int> insertOrUpdateHorseProfile(HorseProfile profile) async {
    final db = await _db;
    try {
      return await db.insert(
        DbConstants.tableHorseProfiles,
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('DEBUG: [ERROR] DB insertOrUpdateHorseProfile failed: $e');
      return -1;
    }
  }

  Future<HorseProfile?> getHorseProfile(String horseId) async {
    final db = await _db;
    try {
      final maps = await db.query(
        DbConstants.tableHorseProfiles,
        where: 'horseId = ?',
        whereArgs: [horseId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return HorseProfile.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('DEBUG: [ERROR] getHorseProfile failed: $e');
      return null;
    }
  }
}