// lib/db/repositories/entry_meaning_repository.dart

// [追加] 陣営の本気度指数 実施順6: 出走の意味の計算結果（entry_meaning_cache テーブル。レースごとに1件）の保存と読み出し (v.2026.10.3+26100307)

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning_snapshot.dart';

/// entry_meaning_cache テーブルの保存と読み出しを担当するリポジトリ。
class EntryMeaningRepository {
  Future<Database> get _db async => await DbProvider().database;

  /// 保存する（同じレースの保存があれば上書き）。
  Future<void> save(EntryMeaningSnapshot snapshot) async {
    final db = await _db;
    await db.insert(
      DbConstants.tableEntryMeaningCache,
      snapshot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// そのレースの保存を読む。無い・読めなければ null。
  Future<EntryMeaningSnapshot?> getForRace(String raceId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableEntryMeaningCache,
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EntryMeaningSnapshot.fromMap(maps.first);
  }
}
