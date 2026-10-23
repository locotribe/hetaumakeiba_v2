// lib/db/repositories/horse_condition_post_repository.dart

// [追加] 出走の意味 調教の行 Step3: netkeiba の近況の投稿（horse_condition_posts）の保存と読み出し (v.2026.10.24+26102403)

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/models/horse_condition_post_model.dart';

class HorseConditionPostRepository {
  Future<Database> get _db async => await DbProvider().database;

  /// 近況の投稿を保存する。主キー（馬ID・投稿日時・順）が同じ投稿は上書きする。
  Future<void> upsertPosts(List<HorseConditionPost> posts) async {
    if (posts.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final post in posts) {
      batch.insert(
        DbConstants.tableHorseConditionPosts,
        post.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 指定した馬の近況の投稿を、投稿日時の新しい順（同じ日時は上から順）で返す。
  Future<List<HorseConditionPost>> getPostsForHorse(String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableHorseConditionPosts,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'posted_at DESC, seq ASC',
    );
    final posts = <HorseConditionPost>[];
    for (final map in maps) {
      final post = HorseConditionPost.fromMap(map);
      if (post != null) posts.add(post);
    }
    return posts;
  }
}
