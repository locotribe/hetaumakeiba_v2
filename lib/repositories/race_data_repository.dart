// lib/repositories/race_data_repository.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/race_result_model.dart';
import '../models/qr_data_model.dart';
import '../models/ai_prediction_race_data.dart';
import '../models/shutuba_table_cache_model.dart';
import '../models/horse_performance_model.dart';
import '../models/horse_profile_model.dart';

/// データの保存を一元管理するリポジトリ
class RaceDataRepository {
  final dbHelper = DatabaseHelper();

  /// レース結果を保存する
  Future<void> saveRaceResult(RaceResult newResult) async {
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'race_results',
      where: 'race_id = ?',
      whereArgs: [newResult.raceId],
    );

    if (maps.isNotEmpty) {
      try {
        final existingResult = raceResultFromJson(maps.first['race_result_json'] as String);
        if (existingResult.isDetailed && !newResult.isDetailed) {
          return;
        }
      } catch (e) {
        // エラー時は無視して上書き
      }
    }
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
      predictionRaceData: data,
      lastUpdatedAt: DateTime.now(),
    );
    await dbHelper.insertShutubaTableCache(cache);
  }

  /// ★追加: 競走馬の戦績リストを一括保存する
  Future<void> saveHorsePerformanceList(List<HorseRaceRecord> records) async {
    await dbHelper.insertHorseRaceRecords(records);
  }

  /// 出馬表データ（AI予測用データ含む）を取得する
  Future<PredictionRaceData?> getShutubaData(String raceId) async {
    final cache = await dbHelper.getShutubaTableCache(raceId);
    if (cache != null) {
      var data = cache.predictionRaceData;

      // プロフィール情報の結合処理
      final List<PredictionHorseDetail> updatedHorses = [];

      for (var horse in data.horses) {
        // DBからプロフィールを取得
        final profile = await dbHelper.getHorseProfile(horse.horseId);

        if (profile != null) {
          // プロフィール情報がある場合、値をセットした新しいインスタンスを作成
          updatedHorses.add(PredictionHorseDetail(
            horseId: horse.horseId,
            horseNumber: horse.horseNumber,
            gateNumber: horse.gateNumber,
            horseName: horse.horseName,
            sexAndAge: horse.sexAndAge,
            jockey: horse.jockey,
            jockeyId: horse.jockeyId,
            carriedWeight: horse.carriedWeight,
            trainerName: horse.trainerName,
            trainerAffiliation: horse.trainerAffiliation,
            odds: horse.odds,
            effectiveOdds: horse.effectiveOdds,
            popularity: horse.popularity,
            horseWeight: horse.horseWeight,
            userMark: horse.userMark,
            userMemo: horse.userMemo,
            isScratched: horse.isScratched,
            predictionScore: horse.predictionScore,
            conditionFit: horse.conditionFit,
            distanceCourseAptitudeStats: horse.distanceCourseAptitudeStats,
            trackAptitudeLabel: horse.trackAptitudeLabel,
            bestTimeStats: horse.bestTimeStats,
            fastestAgariStats: horse.fastestAgariStats,
            overallScore: horse.overallScore,
            expectedValue: horse.expectedValue,
            legStyleProfile: horse.legStyleProfile,
            previousHorseWeight: horse.previousHorseWeight,
            previousJockey: horse.previousJockey,
            // DBから取得したプロフィール情報を優先してセット
            ownerName: (profile.ownerName.isNotEmpty) ? profile.ownerName : horse.ownerName,
            ownerId: (profile.ownerId.isNotEmpty) ? profile.ownerId : horse.ownerId,
            ownerImageLocalPath: (profile.ownerImageLocalPath.isNotEmpty) ? profile.ownerImageLocalPath : horse.ownerImageLocalPath,
            breederName: (profile.breederName.isNotEmpty) ? profile.breederName : horse.breederName,
            fatherName: (profile.fatherName.isNotEmpty) ? profile.fatherName : horse.fatherName,
            motherName: (profile.motherName.isNotEmpty) ? profile.motherName : horse.motherName,
          ));
        } else {
          updatedHorses.add(horse);
        }
      }

      // PredictionRaceData を再構築して返す
      return PredictionRaceData(
        raceId: data.raceId,
        raceName: data.raceName,
        raceDate: data.raceDate,
        venue: data.venue,
        raceNumber: data.raceNumber,
        shutubaTableUrl: data.shutubaTableUrl,
        raceGrade: data.raceGrade,
        raceDetails1: data.raceDetails1,
        horses: updatedHorses,
        racePacePrediction: data.racePacePrediction,
      );
    }
    return null;
  }
}