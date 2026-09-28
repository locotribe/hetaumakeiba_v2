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

  // [追加] レースメモ用途分離: レース総評(memo列)だけを更新し、aiPredictionMemo列は保持する (v.2026.9.28+26092801)
  Future<int> upsertRaceReviewMemo({
    required String userId,
    required String raceId,
    required String memo,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      DbConstants.tableRaceMemos,
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
      limit: 1,
    );
    if (existing.isEmpty) {
      return await db.insert(
        DbConstants.tableRaceMemos,
        {
          'userId': userId,
          'raceId': raceId,
          'memo': memo,
          'aiPredictionMemo': null,
          'timestamp': now,
        },
      );
    }
    return await db.update(
      DbConstants.tableRaceMemos,
      {'memo': memo, 'timestamp': now},
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
    );
  }

  // [追加] レースメモ用途分離: AI予想・買い目(aiPredictionMemo列)だけを更新し、memo列は保持する (v.2026.9.28+26092801)
  Future<int> upsertAiPredictionMemo({
    required String userId,
    required String raceId,
    required String aiPredictionMemo,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      DbConstants.tableRaceMemos,
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
      limit: 1,
    );
    if (existing.isEmpty) {
      return await db.insert(
        DbConstants.tableRaceMemos,
        {
          'userId': userId,
          'raceId': raceId,
          'memo': null,
          'aiPredictionMemo': aiPredictionMemo,
          'timestamp': now,
        },
      );
    }
    return await db.update(
      DbConstants.tableRaceMemos,
      {'aiPredictionMemo': aiPredictionMemo, 'timestamp': now},
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
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
