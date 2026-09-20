// lib/db/repositories/track_condition_repository.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:csv/csv.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';

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
      debugPrint('DEBUG: CSVインポートエラー: $e');
      rethrow;
    }
  }
  // レースIDの先頭10桁から、当日の最新の馬場状態レコードを取得するメソッド
  Future<TrackConditionRecord?> getLatestTrackConditionByPrefix(String prefix10) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTrackConditions,
      // 先頭10桁が一致、かつ下2桁が00(前日データ)ではないものを抽出
      where: 'CAST(track_condition_id AS TEXT) LIKE ? AND track_condition_id % 100 != 0',
      whereArgs: ['$prefix10%'],
      // 複数ある場合は一番新しい(IDが大きい)ものを取得
      orderBy: 'track_condition_id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TrackConditionRecord.fromJson(maps.first);
    }
    return null;
  }

  // [追加] レースの競馬場コード(raceIdの5〜6桁目)と開催日(date列)で当日の馬場状態レコードを取得する。
  // IDの日次(DD)に依存しないため、DDがずれて保存されたレコードや金曜(前日測定)レコードの誤紐付けが起きない。
  // raceDate は 'YYYY/MM/DD' / 'YYYY年MM月DD日' / 'YYYY年M月D日(曜)' のいずれも可 (v.2026.9.19+26091901)
  Future<TrackConditionRecord?> getTrackConditionForRace({
    required String raceId,
    required String raceDate,
  }) async {
    if (raceId.length < 6) return null;
    final parsed = parseRaceDateForSpeedIndex(raceDate);
    if (parsed == null) return null;

    final venueCode = raceId.substring(4, 6);
    final dateStr = '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';

    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTrackConditions,
      where: 'date = ? AND SUBSTR(CAST(track_condition_id AS TEXT), 5, 2) = ?',
      whereArgs: [dateStr, venueCode],
      orderBy: 'track_condition_id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TrackConditionRecord.fromJson(maps.first);
    }
    return null;
  }

  // [追加] 0-9b-1 指定競馬場コードの直近N件の馬場状態レコードを取得（過去傾向の算出用） (v.2026.7.27+26072704)
  Future<List<TrackConditionRecord>> getRecentTrackConditionsForVenue(
      String venueCode, {int limit = 10}) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTrackConditions,
      where: 'SUBSTR(CAST(track_condition_id AS TEXT), 5, 2) = ? AND track_condition_id % 100 != 0',
      whereArgs: [venueCode],
      orderBy: 'track_condition_id DESC',
      limit: limit,
    );
    return maps.map((e) => TrackConditionRecord.fromJson(e)).toList();
  }

  // [追加] 同一開催(prefix8=YYYYCCKK)の全馬場状態履歴を取得（トレンドグラフ表示用、古い順・前日データ(下2桁00)は除外） (v.2026.7.28+26072809)
  Future<List<TrackConditionRecord>> getTrackConditionsByMeeting(String prefix8) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTrackConditions,
      where: 'CAST(track_condition_id AS TEXT) LIKE ? AND track_condition_id % 100 != 0',
      whereArgs: ['$prefix8%'],
      orderBy: 'date ASC, track_condition_id ASC',
    );
    return maps.map((e) => TrackConditionRecord.fromJson(e)).toList();
  }

  /// 【追加】指定した日付のデータが存在するかチェックするメソッド（分岐Aの判定用）
  Future<bool> hasDataForDate(String date) async {
    final db = await _dbProvider.database;
    final count = Sqflite.firstIntValue(await db.query(
      DbConstants.tableTrackConditions,
      columns: ['COUNT(*)'],
      where: 'date = ?',
      whereArgs: [date],
    ));
    return count != null && count > 0;
  }

  // [追加] サーバーとの件数差で同期要否を判定するため、馬場状態レコードの総数を返す (v.2026.9.21+26092101)
  Future<int> countAll() async {
    final db = await _dbProvider.database;
    final count = Sqflite.firstIntValue(await db.query(
      DbConstants.tableTrackConditions,
      columns: ['COUNT(*)'],
    ));
    return count ?? 0;
  }

  // [追加] サーバーCSVを「同一日付・同一競馬場はサーバーを正」として取り込む。
  // (日付, 競馬場コード)ごとにローカル行を削除してからサーバー行を挿入する。
  // 削除はキーごとに1回だけ行うため、サーバー側に同一キーが複数行あっても互いを消さない。
  // サーバーに無い日付のローカル行は残る (v.2026.9.19+26091902)
  Future<Map<String, int>> replaceTrackConditionsFromCsv(String csvString) async {
    final db = await _dbProvider.database;
    final cleanCsv = csvString.replaceAll('\r\n', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(cleanCsv);
    if (rows.length <= 1) return {'written': 0, 'deleted': 0};

    final List<Map<String, dynamic>> records = [];
    final Set<String> keys = {};
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row[0] == null || row[0].toString().trim().isEmpty) continue;
      final idVal = row[0];
      final int? trackConditionId = idVal is int ? idVal : int.tryParse(idVal.toString());
      if (trackConditionId == null) continue;
      final idStr = trackConditionId.toString();
      final date = row.length > 1 ? row[1]?.toString() ?? '' : '';
      if (idStr.length != 12 || date.isEmpty) continue;

      keys.add('$date|${idStr.substring(4, 6)}');
      records.add({
        'track_condition_id': trackConditionId,
        'date': date,
        'week_day': row.length > 2 ? row[2]?.toString() : null,
        'cushion_value': row.length > 3 ? double.tryParse(row[3]?.toString() ?? '') : null,
        'moisture_turf_goal': row.length > 4 ? double.tryParse(row[4]?.toString() ?? '') : null,
        'moisture_turf_4c': row.length > 5 ? double.tryParse(row[5]?.toString() ?? '') : null,
        'moisture_dirt_goal': row.length > 6 ? double.tryParse(row[6]?.toString() ?? '') : null,
        'moisture_dirt_4c': row.length > 7 ? double.tryParse(row[7]?.toString() ?? '') : null,
      });
    }

    int deleted = 0;
    await db.transaction((txn) async {
      for (final key in keys) {
        final parts = key.split('|');
        deleted += await txn.delete(
          DbConstants.tableTrackConditions,
          where: 'date = ? AND SUBSTR(CAST(track_condition_id AS TEXT), 5, 2) = ?',
          whereArgs: [parts[0], parts[1]],
        );
      }
      final batch = txn.batch();
      for (final r in records) {
        batch.insert(DbConstants.tableTrackConditions, r,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });

    return {'written': records.length, 'deleted': deleted};
  }
}