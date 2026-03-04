// lib/db/repositories/training_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

class TrainingRepository {
  Future<Database> get _db async => await DbProvider().database;

  /// 調教データを一括でデータベースに保存（上書き）します。
  Future<void> insertTrainingTimes(List<TrainingTimeModel> records) async {
    final db = await _db;
    final batch = db.batch();

    for (final record in records) {
      batch.insert(
        DbConstants.tableTrainingTimes,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 指定した馬IDの調教履歴を日付と時間の降順（新しい順）で取得します。
  Future<List<TrainingTimeModel>> getTrainingTimesForHorse(String horseId) async {
    final db = await _db;
    final maps = await db.query(
      DbConstants.tableTrainingTimes,
      where: '${DbConstants.colHorseId} = ?',
      whereArgs: [horseId],
      orderBy: '${DbConstants.colTrainingDate} DESC, ${DbConstants.colTrainingTime} DESC',
    );

    return List.generate(maps.length, (i) {
      return TrainingTimeModel.fromMap(maps[i]);
    });
  }
}