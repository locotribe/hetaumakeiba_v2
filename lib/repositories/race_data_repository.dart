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
import '../services/horse_profile_scraper_service.dart';
// 追加: Managerをインポート
import '../services/scraping_manager.dart';

/// データの保存を一元管理するリポジトリ
class RaceDataRepository {
  final dbHelper = DatabaseHelper();
  // 追加: Managerのインスタンス
  final ScrapingManager _scrapingManager = ScrapingManager();

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

  /// 競走馬の戦績リストを一括保存する
  Future<void> saveHorsePerformanceList(List<HorseRaceRecord> records) async {
    await dbHelper.insertHorseRaceRecords(records);
  }

  /// 出走馬リストを受け取り、プロフィールがない馬のデータをバックグラウンドで取得する
  /// UI側で「1頭取得するごとに画面更新」ができるよう、コールバック関数を受け取る
  /// ★修正: Managerを使用してリクエストを直列化・待機させる
  Future<void> syncMissingHorseProfiles(
      List<PredictionHorseDetail> horses,
      Function(String horseId) onProfileUpdated,
      ) async {

    print('DEBUG: syncMissingHorseProfiles started for ${horses.length} horses via Manager.');

    for (final horse in horses) {
      // 1. DBにプロフィールがあるか確認 (ここは同期的にチェックしてOK)
      final existingProfile = await dbHelper.getHorseProfile(horse.horseId);

      // 2. プロフィールがない、または情報が不足している場合に取得リクエストをキューに追加
      if (existingProfile == null || existingProfile.ownerName.isEmpty) {

        // Managerにリクエストを追加
        _scrapingManager.addRequest(
            'プロフィール取得: ${horse.horseName}',
                () async {
              print('DEBUG: Executing queued profile fetch for: ${horse.horseName} (${horse.horseId})');

              // スクレイピング実行
              final newProfile = await HorseProfileScraperService.scrapeAndSaveProfile(horse.horseId);

              if (newProfile != null) {
                print('DEBUG: Profile synced for ${horse.horseId}, calling callback.');
                // コールバック経由でUIを更新（呼び出し元のsetState等が呼ばれる）
                onProfileUpdated(horse.horseId);
              } else {
                print('DEBUG: Failed to sync profile for ${horse.horseId}');
              }
            }
        );
      }
    }
  }

  /// 出馬表データ（AI予測用データ含む）を取得する
  Future<PredictionRaceData?> getShutubaData(String raceId) async {
    final cache = await dbHelper.getShutubaTableCache(raceId);

    if (cache != null) {
      var data = cache.predictionRaceData;

      // プロフィール情報の結合処理
      final List<PredictionHorseDetail> updatedHorses = [];

      for (var horse in data.horses) {
        // 各馬のプロフィール情報をDBから取得
        final profile = await dbHelper.getHorseProfile(horse.horseId);

        if (profile != null) {
          // プロフィール情報がある場合、値を更新した新しいインスタンスを作成
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

      // PredictionRaceDataを再構築して返す
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

  // ---------------------------------------------------------------------------
  // Step 1: 過去10年マッチング機能用 追加メソッド
  // ---------------------------------------------------------------------------

  /// レース名の一部（例："東京新聞杯"）で race_results テーブルを検索し、
  /// 該当する List<RaceResult> を返します。
  Future<List<RaceResult>> searchRaceResultsByName(String partialName) async {
    final db = await dbHelper.database;

    // race_results テーブルから全レコードを取得
    final maps = await db.query('race_results');

    final List<RaceResult> matches = [];

    for (final map in maps) {
      final jsonStr = map['race_result_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          // JSON文字列から RaceResult オブジェクトを復元
          final result = raceResultFromJson(jsonStr);

          // レース名に検索キーワードが含まれているか判定
          if (result.raceTitle.contains(partialName)) {
            matches.add(result);
          }
        } catch (e) {
          print('Error parsing race result in searchRaceResultsByName: $e');
        }
      }
    }

    return matches;
  }

  /// 馬IDを指定して、DBから戦績リストを取得します。
  Future<List<HorseRaceRecord>> getHorseRaceRecords(String horseId) async {
    // 既存のメソッドを利用して同じ機能を返す
    return dbHelper.getHorsePerformanceRecords(horseId);
  }

  /// 取得した戦績リストをDBに一括保存します。
  Future<void> insertHorseRaceRecords(List<HorseRaceRecord> records) async {
    await dbHelper.insertHorseRaceRecords(records);
  }

  // ---------------------------------------------------------------------------
  // Step 2: 競走馬プロフィール管理用 追加メソッド
  // ---------------------------------------------------------------------------

  Future<int> insertOrUpdateHorseProfile(HorseProfile profile) async {
    return dbHelper.insertOrUpdateHorseProfile(profile);
  }

  /// 馬IDを指定して競走馬プロフィールを取得します。
  Future<HorseProfile?> getHorseProfile(String horseId) async {
    return dbHelper.getHorseProfile(horseId);
  }
}