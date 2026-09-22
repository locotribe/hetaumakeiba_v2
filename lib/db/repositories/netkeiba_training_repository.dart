// lib/db/repositories/netkeiba_training_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';

// [追加] 調教タブ改修Step2: netkeiba 調教2テーブルの読み書き (v.2026.9.22+26092211)

/// netkeiba 調教（netkeiba_training_reviews / netkeiba_training_sessions）の読み書きを担当するリポジトリ。
class NetkeibaTrainingRepository {
  Future<Database> get _db async => await DbProvider().database;

  /// 評価を既存行とマージして保存する（null の項目は既存値を保持）。
  Future<void> upsertReviewsMerge(List<NetkeibaTrainingReview> reviews) async {
    if (reviews.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final review in reviews) {
        final rows = await txn.query(
          DbConstants.tableNetkeibaTrainingReviews,
          where: 'race_id = ? AND horse_id = ?',
          whereArgs: [review.raceId, review.horseId],
          limit: 1,
        );
        final base =
            rows.isEmpty ? null : NetkeibaTrainingReview.fromMap(rows.first);
        await txn.insert(
          DbConstants.tableNetkeibaTrainingReviews,
          review.mergeOnto(base).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 調教1本ごとの行を既存行とマージして保存する（null の項目は既存値を保持）。
  Future<void> upsertSessionsMerge(
      List<NetkeibaTrainingSession> sessions) async {
    if (sessions.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final session in sessions) {
        final rows = await txn.query(
          DbConstants.tableNetkeibaTrainingSessions,
          where:
              'horse_id = ? AND training_date = ? AND course_raw = ? AND seq = ?',
          whereArgs: [
            session.horseId,
            session.trainingDate,
            session.courseRaw,
            session.seq,
          ],
          limit: 1,
        );
        final base =
            rows.isEmpty ? null : NetkeibaTrainingSession.fromMap(rows.first);
        await txn.insert(
          DbConstants.tableNetkeibaTrainingSessions,
          session.mergeOnto(base).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 指定レースの評価を返す（Key: horseId）。
  Future<Map<String, NetkeibaTrainingReview>> getReviewsForRace(
      String raceId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableNetkeibaTrainingReviews,
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    return {
      for (final map in maps)
        map['horse_id'] as String: NetkeibaTrainingReview.fromMap(map)
    };
  }

  /// 指定馬の評価をすべて返す（race_id の新しい順）。
  Future<List<NetkeibaTrainingReview>> getReviewsForHorse(
      String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableNetkeibaTrainingReviews,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'race_id DESC',
    );
    return maps.map(NetkeibaTrainingReview.fromMap).toList();
  }

  /// 指定馬の調教をすべて返す（日付・時刻の新しい順）。
  Future<List<NetkeibaTrainingSession>> getSessionsForHorse(
      String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableNetkeibaTrainingSessions,
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'training_date DESC, training_time DESC, seq ASC',
    );
    return maps.map(NetkeibaTrainingSession.fromMap).toList();
  }
}
