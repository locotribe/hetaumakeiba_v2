import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/race_result_model.dart';
import '../models/qr_data_model.dart';
import '../models/ai_prediction_race_data.dart';
import '../models/shutuba_table_cache_model.dart';
// ★追加: 馬の戦績モデルをインポート
import '../models/horse_performance_model.dart';

/// データの保存を一元管理するリポジトリ
/// 既存データと新規データを比較し、より詳細なデータのみを保存する役割を持つ
class RaceDataRepository {
  final dbHelper = DatabaseHelper();

  /// レース結果を保存する
  /// 既にDBに「詳細(確定)」データがある場合、
  /// 「簡易(速報)」データでの上書きを防止する
  Future<void> saveRaceResult(RaceResult newResult) async {
    final db = await dbHelper.database;

    // 1. 既存データのチェック
    final List<Map<String, dynamic>> maps = await db.query(
      'race_results',
      where: 'race_id = ?',
      whereArgs: [newResult.raceId],
    );

    if (maps.isNotEmpty) {
      try {
        final existingResult = raceResultFromJson(maps.first['race_result_json'] as String);

        // 2. 既存データが「詳細」で、新しいデータが「簡易」なら
        // データの劣化を防ぐために保存せず終了する
        if (existingResult.isDetailed && !newResult.isDetailed) {
          return;
        }
      } catch (e) {
        // パースエラー時は上書きを試みる
      }
    }

    // 3. 保存実行
    await dbHelper.insertOrUpdateRaceResult(newResult);
  }

  /// QRコードデータを保存する
  Future<void> saveQrData(QrData qrData) async {
    await dbHelper.insertQrData(qrData);
  }

  /// 出馬表データ（AI予測用データ含む）を保存する
  Future<void> saveShutubaData(PredictionRaceData data) async {
    final cache = ShutubaTableCache(
      raceId: data.raceId,
      predictionRaceData: data, // JSON化せずオブジェクトをそのまま渡す
      lastUpdatedAt: DateTime.now(), // パラメータ名を lastUpdatedAt に修正
    );

    await dbHelper.insertOrUpdateShutubaTableCache(cache);
  }

  /// 馬の過去戦績リストを保存する
  /// スクレイピングされた複数の戦績をまとめてDBに登録・更新します
  Future<void> saveHorsePerformanceList(List<HorseRaceRecord> records) async {
    if (records.isEmpty) return;

    // 現状は単純な上書き（ON CONFLICT REPLACE）ですが、
    // 将来的に「新しいデータのみ追加」などのロジックが必要になった場合、
    // ここを一箇所修正するだけで済みます。
    for (final record in records) {
      await dbHelper.insertOrUpdateHorsePerformance(record);
    }
  }
}