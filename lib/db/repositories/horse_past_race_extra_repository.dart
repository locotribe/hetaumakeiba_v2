// lib/db/repositories/horse_past_race_extra_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';

/// 過去走ごとの追加情報 (horse_past_race_extras) の読み書きを担当するリポジトリ。
class HorsePastRaceExtraRepository {
  Future<Database> get _db async => await DbProvider().database;

  /// 既存行とマージして保存する。受け取った値が null の項目は既存値を保持する。
  Future<void> upsertMerge(List<HorsePastRaceExtra> extras) async {
    if (extras.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final extra in extras) {
        final rows = await txn.query(
          DbConstants.tableHorsePastRaceExtras,
          where: 'horse_id = ? AND race_id = ?',
          whereArgs: [extra.horseId, extra.raceId],
          limit: 1,
        );
        final base = rows.isEmpty ? null : HorsePastRaceExtra.fromMap(rows.first);
        final merged = extra.mergeOnto(base);
        await txn.insert(
          DbConstants.tableHorsePastRaceExtras,
          merged.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 指定馬の、指定raceId群の追加情報を返す（Key: raceId）。
  Future<Map<String, HorsePastRaceExtra>> getForHorse(
    String horseId,
    List<String> raceIds,
  ) async {
    if (raceIds.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(raceIds.length, '?').join(',');
    final maps = await db.query(
      DbConstants.tableHorsePastRaceExtras,
      where: 'horse_id = ? AND race_id IN ($placeholders)',
      whereArgs: [horseId, ...raceIds],
    );
    final Map<String, HorsePastRaceExtra> result = {};
    for (final map in maps) {
      final extra = HorsePastRaceExtra.fromMap(map);
      result[extra.raceId] = extra;
    }
    return result;
  }
}
