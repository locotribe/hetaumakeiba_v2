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
import '../services/scraping_manager.dart';
import '../models/jyusyoichiran_page_data_model.dart';
import '../models/race_schedule_model.dart'; // ★追加

/// データの保存を一元管理するリポジトリ
class RaceDataRepository {
  final dbHelper = DatabaseHelper();
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

  // ---------------------------------------------------------------------------
  // Step 3: 重賞一覧ページ (JyusyoRace) 管理用メソッド (ここに追加)
  // ---------------------------------------------------------------------------

  /// 指定した年の重賞レースをリストで取得します (Modelに変換して返します)
  Future<List<JyusyoRace>> getJyusyoRaces(int year) async {
    final List<Map<String, dynamic>> maps = await dbHelper.getJyusyoRacesByYear(year);
    return maps.map((m) => JyusyoRace.fromMap(m)).toList();
  }

  /// 重賞レースリストを保存します (マージ処理)
  Future<void> saveJyusyoRaces(List<JyusyoRace> races) async {
    // DatabaseHelperはList<dynamic>を受け取る仕様にしているためそのまま渡す
    await dbHelper.mergeJyusyoRaces(races);
  }

  /// レースIDを更新します (詳細取得後)
  Future<void> updateJyusyoRaceId(int id, String newRaceId) async {
    await dbHelper.updateJyusyoRaceId(id, newRaceId);
  }

// ★修正: スケジュールデータから重賞一覧のIDを更新・自動連携する（デバッグログ追加版）
  Future<void> reflectScheduleDataToJyusyoRaces(RaceSchedule schedule) async {
    print('DEBUG: reflectScheduleDataToJyusyoRaces START for date: ${schedule.date}');

    // 1. スケジュールの年を取得
    int year;
    try {
      year = int.parse(schedule.date.substring(0, 4));
    } catch (e) {
      print('DEBUG: Error parsing year from date: $e');
      return;
    }

    // 2. その年の重賞データをDBから全て取得してメモリに展開
    List<JyusyoRace> jyusyoRaces = await getJyusyoRaces(year);
    if (jyusyoRaces.isEmpty) {
      print('DEBUG: No Jyusyo races found in DB for year $year');
      return;
    }
    print('DEBUG: Loaded ${jyusyoRaces.length} Jyusyo races from DB for year $year');

    // 3. 日付のマッチング用文字列を作成 (yyyy-MM-dd -> MM/dd)
    // 例: "2026-02-22" -> "02/22"
    String scheduleDateMMdd = schedule.date.substring(5).replaceAll('-', '/');
    print('DEBUG: Schedule date formatted for matching: $scheduleDateMMdd');

    int processedCount = 0;
    int matchedCount = 0;

    for (var venue in schedule.venues) {
      print('DEBUG: Checking venue: ${venue.venueTitle}');

      for (var race in venue.races) {
        // IDが取得できていないレースはスキップ
        if (race.raceId.isEmpty) continue;

        // デバッグ用: ダイヤモンドS または グレードがあるレースのみ詳細ログを出す
        bool isTarget = race.raceName.contains('ダイヤモンド') || race.grade.isNotEmpty;

        if (isTarget) {
          print('DEBUG: Processing schedule race: ${race.raceName} (ID: ${race.raceId}, Grade: ${race.grade}, Details: ${race.details})');
        }

        // DB上の重賞リストから候補を絞り込む
        var candidates = jyusyoRaces.where((j) {
          // 条件A: IDがまだない (race_id IS NULL or Empty)
          bool hasNoId = j.raceId == null || j.raceId!.isEmpty;

          // 条件B: 日付が一致する (前方一致 "02/22")
          bool dateMatch = j.date.startsWith(scheduleDateMMdd);

          // 条件C: 開催場所が含まれる (例: "1回東京8日" に "東京" が含まれる)
          bool venueMatch = venue.venueTitle.contains(j.venue);

          // ダイヤモンドSの候補判定ログ
          if (isTarget && (j.raceName.contains('ダイヤモンド') || race.raceName.contains('ダイヤモンド'))) {
            print('DEBUG: Candidate Check [${j.raceName}] vs [${race.raceName}] -> HasNoID: $hasNoId, DateMatch: $dateMatch (${j.date} vs $scheduleDateMMdd), VenueMatch: $venueMatch (${j.venue} vs ${venue.venueTitle})');
          }

          return hasNoId && dateMatch && venueMatch;
        }).toList();

        if (isTarget && candidates.isNotEmpty) {
          print('DEBUG: Found ${candidates.length} candidate(s) for ${race.raceName}');
        } else if (isTarget) {
          print('DEBUG: No candidates found for ${race.raceName} (Date/Venue mismatch or ID already exists)');
        }

        for (var candidate in candidates) {
          bool isMatch = false;
          print('DEBUG: Matching logic for [${candidate.raceName}] vs [${race.raceName}]');

          // 条件D-1: グレードの一致
          if (candidate.grade.isNotEmpty && race.grade.isNotEmpty) {
            if (candidate.grade == race.grade) {
              isMatch = true;
              print('DEBUG: -> Match confirmed by GRADE (${candidate.grade})');
            } else {
              print('DEBUG: -> Grade mismatch (${candidate.grade} vs ${race.grade})');
            }
          }

          // 条件D-2: 距離の一致
          if (!isMatch) {
            RegExp digitRegex = RegExp(r'(\d+)');
            String? dist1 = digitRegex.firstMatch(candidate.distance)?.group(1);
            String? dist2 = digitRegex.firstMatch(race.details)?.group(1);

            print('DEBUG: -> Distance check: DB=$dist1 vs Schedule=$dist2');

            if (dist1 != null && dist2 != null && dist1 == dist2) {
              isMatch = true;
              print('DEBUG: -> Match confirmed by DISTANCE');
            }
          }

          // 条件D-3: レース名の類似判定
          if (!isMatch) {
            String n1 = candidate.raceName.replaceAll(RegExp(r'\s'), '');
            String n2 = race.raceName.replaceAll(RegExp(r'\s'), '');
            print('DEBUG: -> Name check: $n1 vs $n2');
            if (n1 == n2) {
              isMatch = true;
              print('DEBUG: -> Match confirmed by NAME');
            }
          }

          // マッチした場合はIDを更新
          if (isMatch && candidate.id != null) {
            await updateJyusyoRaceId(candidate.id!, race.raceId);
            print('DEBUG: SUCCESS! Database updated for ${candidate.raceName} with ID ${race.raceId}');
            matchedCount++;
          } else {
            print('DEBUG: FAILED match for ${candidate.raceName}');
          }
        }
        processedCount++;
      }
    }
    print('DEBUG: reflectScheduleDataToJyusyoRaces END. Processed: $processedCount, Matched: $matchedCount');
  }

// ★修正: 名前比較を廃止し、コース種別・距離・グレードによる厳格マッチングに変更
  Future<List<JyusyoRace>> fillMissingJyusyoIdsFromLocalSchedule(int year, {int? targetMonth}) async {
    List<JyusyoRace> updatedRaces = [];

    // 1. その年の全重賞データを取得
    List<JyusyoRace> allRaces = await getJyusyoRaces(year);

    // 2. IDがなく、かつ指定された月のレースだけを抽出
    List<JyusyoRace> missingIdRaces = allRaces.where((r) {
      if (r.raceId != null && r.raceId!.isNotEmpty) return false;

      // 月の判定
      final dateMatch = RegExp(r'^(\d{1,2})/').firstMatch(r.date);
      if (dateMatch == null) return false;

      int raceMonth = int.parse(dateMatch.group(1)!);

      // targetMonthが指定されていれば、その月のみ対象にする
      if (targetMonth != null && raceMonth != targetMonth) return false;

      return true;
    }).toList();

    if (missingIdRaces.isEmpty) return [];

    print('DEBUG: checking ${missingIdRaces.length} races for $year-${targetMonth ?? "ALL"}');

    // 3. 1件ずつスケジュールDBを確認
    for (var targetRace in missingIdRaces) {
      // 日付フォーマット変換 "02/14(土)" -> "2026-02-14"
      String dateStr = targetRace.date;
      final dateMatch = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(dateStr);
      if (dateMatch == null) continue;

      String month = dateMatch.group(1)!.padLeft(2, '0');
      String day = dateMatch.group(2)!.padLeft(2, '0');
      String targetDate = '$year-$month-$day';

      // DBからその日のスケジュールを取得
      final schedule = await dbHelper.getRaceSchedule(targetDate);
      if (schedule == null) continue; // データがなければスキップ

      bool isUpdated = false;
      String? foundRaceId;

      // 4. 新・マッチングロジック (名前は見ない)
      for (var venue in schedule.venues) {
        // 会場チェック (例: "1回小倉" に "小倉" が含まれるか)
        if (!venue.venueTitle.contains(targetRace.venue)) continue;

        for (var race in venue.races) {
          if (race.raceId.isEmpty) continue;

          bool isMatch = false;

          // --- 【条件A】 コース種別と距離の完全一致 (最優先) ---
          // JyusyoRace.distance (例: "障3390m")
          // SimpleRaceInfo.details (例: "14:00 障3390m 12頭")

          String type1 = _getCourseType(targetRace.distance);
          String type2 = _getCourseType(race.details); // detailsから種別抽出

          int? dist1 = _extractNumber(targetRace.distance);
          int? dist2 = _extractNumber(race.details);

          // 両方の種別と距離が取得でき、かつ一致する場合
          if (type1.isNotEmpty && type2.isNotEmpty && dist1 != null && dist2 != null) {
            if (type1 == type2 && dist1 == dist2) {
              isMatch = true;
            }
          }

          // --- 【条件B】 グレードの一致 (補完・正規化比較) ---
          // 条件Aで決まらなかった場合のみチェック（重賞一覧にあるレースは必ずグレードがあるため）
          if (!isMatch && targetRace.grade.isNotEmpty && race.grade.isNotEmpty) {
            // 記号を削除して比較 ("J.G3" == "J-G3" -> "JG3" == "JG3")
            String g1 = targetRace.grade.replaceAll(RegExp(r'[.\-\s]'), '');
            String g2 = race.grade.replaceAll(RegExp(r'[.\-\s]'), '');

            if (g1 == g2) {
              // グレードが一致する場合、距離が大きく矛盾していなければマッチとみなす
              // (念のため距離データが取れなかった場合の保険)
              isMatch = true;
            }
          }

          // ※名前(raceName)によるマッチングは廃止しました

          if (isMatch) {
            foundRaceId = race.raceId;
            isUpdated = true;
            break;
          }
        }
        if (isUpdated) break;
      }

      // 5. 更新処理
      if (isUpdated && foundRaceId != null && targetRace.id != null) {
        await updateJyusyoRaceId(targetRace.id!, foundRaceId);
        print('DEBUG: Auto-filled ID for ${targetRace.raceName}: $foundRaceId (By Type/Distance/Grade)');

        updatedRaces.add(JyusyoRace(
          id: targetRace.id,
          raceId: foundRaceId,
          year: targetRace.year,
          date: targetRace.date,
          raceName: targetRace.raceName,
          grade: targetRace.grade,
          venue: targetRace.venue,
          distance: targetRace.distance,
          conditions: targetRace.conditions,
          weight: targetRace.weight,
          sourceUrl: targetRace.sourceUrl,
        ));
      }
    }

    return updatedRaces;
  }

  // ヘルパー: 文字列から数値を抽出
  int? _extractNumber(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  // ヘルパー: コース種別(芝/ダ/障)を抽出
  String _getCourseType(String text) {
    if (text.contains('障')) return '障';
    if (text.contains('ダ')) return 'ダ';
    if (text.contains('芝')) return '芝';
    return '';
  }
}