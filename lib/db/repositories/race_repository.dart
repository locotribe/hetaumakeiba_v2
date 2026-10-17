// lib/db/repositories/race_repository.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

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

  // [修正] 好走条件の改良 Step3追補: 全件を1回の検索で読むと、件数が増えて応答が大きくなり（全体で40MB前後）、Android 側（sqflite）がメモリ不足で落ちた。
  // 500件ずつに分けて読む（読む中身は今までと同じ） (v.2026.10.18+26101801)
  Future<Map<String, RaceResult>> getAllRaceResults() async {
    final Map<String, RaceResult> results = {};
    await _forEachRaceResultRow((map) {
      final result = raceResultFromJson(map['race_result_json'] as String);
      results[result.raceId] = result;
    });
    return results;
  }

  // [追加] 好走条件の改良 Step3追補: レース結果の表を1回に読む件数 (v.2026.10.18+26101801)
  static const int _rowsPerQuery = 500;

  // [追加] 好走条件の改良 Step3追補: レース結果の表を rowid の順（今までの全件読み込みと同じ順）に _rowsPerQuery 件ずつ読み、1行ずつ渡す。
  // 続きは「前に読んだ最後の rowid より後」から読む (v.2026.10.18+26101801)
  Future<void> _forEachRaceResultRow(void Function(Map<String, Object?> row) onRow) async {
    final db = await _dbProvider.database;
    int lastRowId = 0;
    while (true) {
      final maps = await db.query(
        DbConstants.tableRaceResults,
        columns: ['rowid', 'race_id', 'race_result_json'],
        where: 'rowid > ?',
        whereArgs: [lastRowId],
        orderBy: 'rowid',
        limit: _rowsPerQuery,
      );
      if (maps.isEmpty) break;
      for (final map in maps) {
        onRow(map);
      }
      lastRowId = maps.last['rowid'] as int;
      if (maps.length < _rowsPerQuery) break;
    }
  }

  // [修正] 好走条件の改良 Step3追補: 全件を1回の検索で読まず、500件ずつ読む（getAllRaceResults と同じ理由）。
  // 読んでいる途中で上書き保存されたレースが2回出ないようにする (v.2026.10.18+26101801)
  Future<List<RaceResult>> searchRaceResultsByName(String partialName) async {
    final List<RaceResult> matches = [];
    final Set<String> seenRaceIds = {};

    await _forEachRaceResultRow((map) {
      final jsonStr = map['race_result_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final result = raceResultFromJson(jsonStr);
          if (result.raceTitle.contains(partialName) && seenRaceIds.add(result.raceId)) {
            matches.add(result);
          }
        } catch (e) {
          debugPrint('Error parsing race result in searchRaceResultsByName: $e');
        }
      }
    });
    return matches;
  }

}