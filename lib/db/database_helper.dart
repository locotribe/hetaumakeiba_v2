// lib/db/database_helper.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_cache_model.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';
import 'package:hetaumakeiba_v2/db/course_presets.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';

/// アプリケーションのSQLiteデータベース操作を管理するヘルパークラス。
/// このクラスはシングルトンパターンで実装されており、アプリ全体で単一のインスタンスを共有します。
class DatabaseHelper {
  /// シングルトンインスタンスを保持するためのプライベート変数。
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  /// データベース接続を保持するためのプライベート変数。
  static Database? _database;


  /// `DatabaseHelper`のシングルトンインスタンスを返します。
  factory DatabaseHelper() {
    return _instance;
  }

  /// 内部からのみ呼び出されるプライベートコンストラクタ。
  DatabaseHelper._internal();

  /// データベースへの接続を取得します。
  /// 既に接続が存在する場合はそれを返し、ない場合は新しく初期化します。
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// データベースを初期化します。
  /// データベースファイルへのパスを設定し、テーブルを作成または更新します。
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    // pathパッケージのjoinを使い、OSに依存しない安全なパスを作成します。
    final path = join(databasePath, 'hetaumakeiba_v2.db');

    return await openDatabase(
      path,
      // スキーマを変更した場合は、このバージョンを上げる必要があります。
      version: 7,
      /// データベースが初めて作成されるときに呼び出されます。
      /// ここで初期テーブルの作成を行います。すべてのテーブルが最新のスキーマで作成されます。
      onCreate: (db, version) async {
        // QRコードデータテーブルの作成
        await db.execute('''
          CREATE TABLE qr_data(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            qr_code TEXT UNIQUE,
            timestamp TEXT,
            parsed_data_json TEXT
          )
        ''');
        // レース結果データテーブルの作成
        await db.execute('''
          CREATE TABLE race_results(
            race_id TEXT PRIMARY KEY,
            race_result_json TEXT
          )
        ''');
        // 競走馬成績データテーブルの作成
        await db.execute('''
          CREATE TABLE horse_performance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            horse_id TEXT NOT NULL,
            race_id TEXT NOT NULL,
            date TEXT NOT NULL,
            venue TEXT,
            weather TEXT,
            race_number TEXT,
            race_name TEXT,
            number_of_horses TEXT,
            frame_number TEXT,
            horse_number TEXT,
            odds TEXT,
            popularity TEXT,
            rank TEXT,
            jockey TEXT,
            jockey_id TEXT,
            carried_weight TEXT,
            distance TEXT,
            track_condition TEXT,
            time TEXT,
            margin TEXT,
            corner_passage TEXT,
            pace TEXT,
            agari TEXT,
            horse_weight TEXT,
            winner_or_second_horse TEXT,
            prize_money TEXT,
            UNIQUE(horse_id, date) ON CONFLICT REPLACE
          )
        ''');
        // 注目レースデータテーブルの作成
        await db.execute('''
          CREATE TABLE featured_races(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            race_id TEXT UNIQUE,
            race_name TEXT,
            race_grade TEXT,
            race_date TEXT,
            venue TEXT,
            race_number TEXT,
            shutuba_table_url TEXT,
            last_scraped TEXT,
            distance TEXT,
            conditions TEXT,
            weight TEXT,
            race_details_1 TEXT,
            race_details_2 TEXT,
            shutubaHorsesJson TEXT
          )
        ''');
        // ユーザーの印データテーブルの作成
        await db.execute('''
          CREATE TABLE user_marks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            raceId TEXT NOT NULL,
            horseId TEXT NOT NULL,
            mark TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            UNIQUE(userId, raceId, horseId) ON CONFLICT REPLACE
          )
        ''');
        // ユーザーが設定したフィード（RSSなど）のデータテーブル作成
        await db.execute('''
          CREATE TABLE user_feeds(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            type TEXT NOT NULL,
            display_order INTEGER NOT NULL
          )
        ''');
        // 分析用の集計データテーブル作成
        await db.execute('''
          CREATE TABLE analytics_aggregates(
            aggregate_key TEXT NOT NULL,
            userId TEXT NOT NULL,
            total_investment INTEGER NOT NULL DEFAULT 0,
            total_payout INTEGER NOT NULL DEFAULT 0,
            hit_count INTEGER NOT NULL DEFAULT 0,
            bet_count INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (aggregate_key, userId)
          )
        ''');
        // 競走馬メモデータテーブルの作成
        await db.execute('''
          CREATE TABLE horse_memos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            raceId TEXT NOT NULL,
            horseId TEXT NOT NULL,
            predictionMemo TEXT,
            reviewMemo TEXT,
            odds REAL,
            popularity INTEGER,
            timestamp TEXT NOT NULL,
            UNIQUE(userId, raceId, horseId) ON CONFLICT REPLACE
          )
        ''');
        // ユーザーデータテーブルの作成
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            username TEXT NOT NULL UNIQUE,
            hashedPassword TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        // レース統計データテーブルの作成
        await db.execute('''
          CREATE TABLE race_statistics(
            raceId TEXT PRIMARY KEY,
            raceName TEXT NOT NULL,
            statisticsJson TEXT NOT NULL,
            analyzedRacesJson TEXT,
            lastUpdatedAt TEXT NOT NULL
          )
        ''');
        // 馬統計キャッシュデータテーブルの作成
        await db.execute('''
          CREATE TABLE horse_stats_cache(
            raceId TEXT PRIMARY KEY,
            statsJson TEXT NOT NULL,
            lastUpdatedAt TEXT NOT NULL
          )
        ''');
        // 開催日程テーブルの作成
        await db.execute('''
          CREATE TABLE race_schedules(
            date TEXT PRIMARY KEY,
            dayOfWeek TEXT NOT NULL,
            scheduleJson TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE week_schedules_cache(
            week_key TEXT PRIMARY KEY,
            available_dates_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE shutuba_table_cache(
            race_id TEXT PRIMARY KEY,
            shutuba_data_json TEXT,
            last_updated TEXT
          )
        ''');
        // AI予測結果を保存するテーブルを追加
        await db.execute('''
          CREATE TABLE ai_predictions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            race_id TEXT NOT NULL,
            horse_id TEXT NOT NULL,
            overall_score REAL NOT NULL,
            expected_value REAL NOT NULL,
            prediction_timestamp TEXT NOT NULL,
            analysis_details_json TEXT,
            UNIQUE(race_id, horse_id) ON CONFLICT REPLACE
          )
        ''');
        // 新しい course_presets テーブルを作成
        await _createCoursePresetsTable(db);
        // course_presets テーブルに初期データを投入
        await _initCoursePresets(db);
        // 競走馬プロフィールデータテーブルの作成
        await db.execute('''
          CREATE TABLE horse_profiles(
            horseId TEXT PRIMARY KEY,
            horseName TEXT,
            birthday TEXT,
            ownerId TEXT,
            ownerName TEXT,
            ownerImageLocalPath TEXT,
            trainerId TEXT,
            trainerName TEXT,
            breederName TEXT,
            fatherId TEXT,
            fatherName TEXT,
            motherId TEXT,
            motherName TEXT,
            ffName TEXT,
            fmName TEXT,
            mfName TEXT,
            mmName TEXT,
            lastUpdated TEXT
          )
        ''');

        // ★追加: 重賞一覧ページ専用テーブル (v6で追加)
        await db.execute('''
          CREATE TABLE jyusyo_races(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            race_id TEXT,
            year INTEGER NOT NULL, -- ★追加
            date TEXT NOT NULL,
            race_name TEXT NOT NULL,
            grade TEXT,
            venue TEXT,
            distance TEXT,
            conditions TEXT,
            weight TEXT,
            source_url TEXT,
            UNIQUE(year, date, race_name) -- ★修正: 年も含めてユニークに
          )
        ''');
      },
      // ★修正: 既存ユーザー向けのマイグレーション処理を安全化
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            // race_statisticsテーブルに analyzedRacesJson カラムを追加
            await db.execute('ALTER TABLE race_statistics ADD COLUMN analyzedRacesJson TEXT');
          } catch (e) {
            print('Migration error (v1->v2): $e');
            // カラム重複エラー等は無視して続行
          }
        }
        if (oldVersion < 3) {
          try {
            // shutubaHorsesJsonカラムを追加
            await db.execute('ALTER TABLE featured_races ADD COLUMN shutubaHorsesJson TEXT');
          } catch (e) {
            // エラーログ: "duplicate column name: shutubaHorsesJson" が出ても無視する
            print('Migration error (v2->v3): $e - Assuming column already exists.');
          }
        }
        // v3 -> v4 マイグレーション (horse_profilesテーブル追加)
        if (oldVersion < 5) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS horse_profiles(
                horseId TEXT PRIMARY KEY,
                horseName TEXT,
                birthday TEXT,
                ownerId TEXT,
                ownerName TEXT,
                ownerImageLocalPath TEXT,
                trainerId TEXT,
                trainerName TEXT,
                breederName TEXT,
                fatherId TEXT,
                fatherName TEXT,
                motherId TEXT,
                motherName TEXT,
                ffName TEXT,
                fmName TEXT,
                mfName TEXT,
                mmName TEXT,
                lastUpdated TEXT
              )
            ''');
            print('DEBUG: horse_profiles table created or verified.');
          } catch (e) {
            print('DEBUG: Migration error (v->v5): $e');
          }
        }

        // ★追加: v5 -> v6 マイグレーション (jyusyo_racesテーブル追加)
        if (oldVersion < 6) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS jyusyo_races(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                race_id TEXT,
                date TEXT NOT NULL,
                race_name TEXT NOT NULL,
                grade TEXT,
                venue TEXT,
                distance TEXT,
                conditions TEXT,
                weight TEXT,
                source_url TEXT,
                UNIQUE(date, race_name)
              )
            ''');
            print('DEBUG: jyusyo_races table created.');
          } catch (e) {
            print('DEBUG: Migration error (v5->v6): $e');
          }
        }

        // ★追加: v6 -> v7 マイグレーション (yearカラム追加のため再作成)
        if (oldVersion < 7) {
          try {
            // カラム追加のために一度削除して作り直すのが確実
            await db.execute('DROP TABLE IF EXISTS jyusyo_races');
            await db.execute('''
              CREATE TABLE jyusyo_races(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                race_id TEXT,
                year INTEGER NOT NULL,
                date TEXT NOT NULL,
                race_name TEXT NOT NULL,
                grade TEXT,
                venue TEXT,
                distance TEXT,
                conditions TEXT,
                weight TEXT,
                source_url TEXT,
                UNIQUE(year, date, race_name)
              )
            ''');
            print('DEBUG: jyusyo_races table recreated for v7.');
          } catch (e) {
            print('DEBUG: Migration error (v6->v7): $e');
          }
        }
      },
    );
  }

  /// course_presets テーブルを作成する独立したメソッド
  Future<void> _createCoursePresetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE course_presets(
        id TEXT PRIMARY KEY,
        venueCode TEXT NOT NULL,
        venueName TEXT NOT NULL,
        distance TEXT NOT NULL,
        direction TEXT NOT NULL,
        straightLength INTEGER NOT NULL,
        courseLayout TEXT NOT NULL,
        keyPoints TEXT NOT NULL
      )
    ''');
  }

  /// course_presets テーブルに初期データを投入する
  Future<void> _initCoursePresets(Database db) async {
    final batch = db.batch();
    for (final preset in coursePresets) {
      batch.insert(
        'course_presets',
        preset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 指定されたQRコードがデータベースに存在するかを確認します。
  Future<bool> qrCodeExists(String qrCode) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.query(
      'qr_data',
      columns: ['COUNT(*)'],
      where: 'qr_code = ?',
      whereArgs: [qrCode],
    ));
    return count! > 0;
  }

  /// IDを指定して単一のQRコードデータを取得します。
  Future<QrData?> getQrData(int id, String userId) async {
    final db = await database;
    final maps = await db.query(
      'qr_data',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
    if (maps.isNotEmpty) {
      return QrData.fromMap(maps.first);
    }
    return null;
  }

  /// 保存されている全てのQRコードデータを取得します。
  Future<List<QrData>> getAllQrData(String userId) async {
    final db = await database;
    final maps = await db.query(
        'qr_data',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC'
    );
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
  }

  /// 新しいQRコードデータをデータベースに挿入します。
  Future<int> insertQrData(QrData qrData) async {

    final db = await database;
    return await db.insert(
      'qr_data',
      qrData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// IDを指定してQRコードデータを削除します。
  Future<int> deleteQrData(int id, String userId) async {
    final db = await database;

    return await db.delete(
      'qr_data',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  /// レースIDを指定してレース結果を取得します。
  Future<RaceResult?> getRaceResult(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'race_results',
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    if (maps.isNotEmpty) {
      return raceResultFromJson(maps.first['race_result_json'] as String);
    }
    return null;
  }

  Future<Map<String, RaceResult>> getMultipleRaceResults(List<String> raceIds) async {
    if (raceIds.isEmpty) {
      return {};
    }
    final db = await database;
    final placeholders = List.filled(raceIds.length, '?').join(',');
    final maps = await db.query(
      'race_results',
      where: 'race_id IN ($placeholders)',
      whereArgs: raceIds,
    );

    final Map<String, RaceResult> results = {};
    for (final map in maps) {
      final result = raceResultFromJson(map['race_result_json'] as String);
      results[result.raceId] = result;
    }
    return results;
  }

  /// レース結果を挿入または更新します。
  Future<int> insertOrUpdateRaceResult(RaceResult raceResult) async {
    final db = await database;
    return await db.insert(
      'race_results',
      {
        'race_id': raceResult.raceId,
        'race_result_json': raceResultToJson(raceResult),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 競走馬の成績を1件挿入または更新します。
  Future<int> insertOrUpdateHorsePerformance(HorseRaceRecord record) async {
    final db = await database;
    return await db.insert(
      'horse_performance',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 指定された馬IDの全成績レコードを取得します。
  Future<List<HorseRaceRecord>> getHorsePerformanceRecords(String horseId) async {
    final db = await database;
    final maps = await db.query(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return HorseRaceRecord.fromMap(maps[i]);
    });
  }

  /// 指定された馬IDの最新の成績レコードを1件取得します。
  Future<HorseRaceRecord?> getLatestHorsePerformanceRecord(String horseId) async {
    final db = await database;
    final maps = await db.query(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return HorseRaceRecord.fromMap(maps.first);
    }
    return null;
  }

  /// 指定された馬IDの全成績レコードを削除します。
  Future<int> deleteHorsePerformance(String horseId) async {
    final db = await database;
    return await db.delete(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
    );
  }

  /// 注目レースを挿入または更新します。
  Future<int> insertOrUpdateFeaturedRace(FeaturedRace featuredRace) async {
    final db = await database;
    return await db.insert(
      'featured_races',
      featuredRace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 保存されている全ての注目レースを取得します。
  Future<List<FeaturedRace>> getAllFeaturedRaces() async {
    final db = await database;
    final maps = await db.query('featured_races', orderBy: 'last_scraped DESC');
    return List.generate(maps.length, (i) {
      return FeaturedRace.fromMap(maps[i]);
    });
  }

  /// レースIDを指定して注目レースを取得します。
  Future<FeaturedRace?> getFeaturedRace(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'featured_races',
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return FeaturedRace.fromMap(maps.first);
    }
    return null;
  }

  /// 全ての注目レースデータを削除します。
  Future<int> deleteAllFeaturedRaces() async {
    final db = await database;
    return await db.delete('featured_races');
  }

  /// ユーザーが付けた印を挿入または更新します。
  Future<int> insertOrUpdateUserMark(UserMark mark) async {

    final db = await database;
    return await db.insert(
      'user_marks',
      mark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 特定のレースの特定の馬に対するユーザーの印を取得します。
  Future<UserMark?> getUserMark(String userId, String raceId, String horseId) async {
    final db = await database;
    final maps = await db.query(
      'user_marks',
      where: 'userId = ? AND raceId = ? AND horseId = ?',
      whereArgs: [userId, raceId, horseId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserMark.fromMap(maps.first);
    }
    return null;
  }

  /// 特定のレースに付けられた全てのユーザーの印を取得します。
  Future<List<UserMark>> getAllUserMarksForRace(String userId, String raceId) async {
    final db = await database;
    final maps = await db.query(
      'user_marks',
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
    );
    return List.generate(maps.length, (i) {
      return UserMark.fromMap(maps[i]);
    });
  }

  /// 特定のレースの特定の馬に付けられた印を削除します。
  Future<int> deleteUserMark(String userId, String raceId, String horseId) async {

    final db = await database;
    return await db.delete(
      'user_marks',
      where: 'userId = ? AND raceId = ? AND horseId = ?',
      whereArgs: [userId, raceId, horseId],
    );
  }

  /// 新しいフィードを挿入します。
  Future<int> insertFeed(Feed feed) async {

    final db = await database;
    return await db.insert('user_feeds', feed.toMap());
  }

  /// 保存されている全てのフィードを取得します。
  Future<List<Feed>> getAllFeeds(String userId) async {
    final db = await database;
    final maps = await db.query(
        'user_feeds',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'display_order ASC'
    );
    return List.generate(maps.length, (i) {
      return Feed.fromMap(maps[i]);
    });
  }

  /// 既存のフィード情報を更新します。
  Future<int> updateFeed(Feed feed) async {

    final db = await database;
    return await db.update(
      'user_feeds',
      feed.toMap(),
      where: 'id = ?',
      whereArgs: [feed.id],
    );
  }

  /// IDを指定してフィードを削除します。
  Future<int> deleteFeed(int id) async {
    final db = await database;

    return await db.delete(
      'user_feeds',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// フィードの表示順を一括で更新します。
  Future<void> updateFeedOrder(List<Feed> feeds) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < feeds.length; i++) {
      final feed = feeds[i];
      batch.update(
        'user_feeds',
        {'display_order': i},
        where: 'id = ?',
        whereArgs: [feed.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 全てのテーブルから全てのデータを削除します。
  Future<void> deleteAllDataForUser(String userId) async {

    final db = await database;
    await db.delete('qr_data', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('user_marks', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('user_feeds', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('analytics_aggregates', where: 'userId = ?', whereArgs: [userId]);
  }

  /// 投資額、払戻額、的中数、ベット数などの差分を受け取り、データベースの値を更新します。
  Future<void> updateAggregates(String userId, Map<String, Map<String, int>> updates) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final key in updates.keys) {
        final current = await txn.query(
          'analytics_aggregates',
          where: 'aggregate_key = ? AND userId = ?',
          whereArgs: [key, userId],
        );

        final Map<String, dynamic> updateValues = updates[key]!;
        if (current.isEmpty) {
          await txn.insert('analytics_aggregates', {
            'aggregate_key': key,
            'userId': userId,
            'total_investment': updateValues['investment_delta'] ?? 0,
            'total_payout': updateValues['payout_delta'] ?? 0,
            'hit_count': updateValues['hit_delta'] ?? 0,
            'bet_count': updateValues['bet_delta'] ?? 0,
          });
        } else {
          await txn.update(
            'analytics_aggregates',
            {
              'total_investment': (current.first['total_investment'] as int) + (updateValues['investment_delta'] ?? 0),
              'total_payout': (current.first['total_payout'] as int) + (updateValues['payout_delta'] ?? 0),
              'hit_count': (current.first['hit_count'] as int) + (updateValues['hit_delta'] ?? 0),
              'bet_count': (current.first['bet_count'] as int) + (updateValues['bet_delta'] ?? 0),
            },
            where: 'aggregate_key = ? AND userId = ?',
            whereArgs: [key, userId],
          );
        }
      }
    });
  }

  /// 年単位の集計サマリーを取得します。
  Future<List<Map<String, dynamic>>> getYearlySummaries(String userId) async {
    final db = await database;
    return await db.query(
      'analytics_aggregates',
      where: "aggregate_key LIKE 'total_%' AND aggregate_key NOT LIKE 'total_%-%' AND userId = ?",
      whereArgs: [userId],
      orderBy: 'aggregate_key ASC',
    );
  }

  /// 指定された年の月別データを取得します。
  Future<List<Map<String, dynamic>>> getMonthlyDataForYear(String userId, int year) async {
    final db = await database;
    return await db.query(
      'analytics_aggregates',
      where: "aggregate_key LIKE ? AND userId = ?",
      whereArgs: ['total_$year-%', userId],
      orderBy: 'aggregate_key ASC',
    );
  }

  /// カテゴリ（競馬場、騎手など）ごとの集計サマリーを取得します。
  Future<List<Map<String, dynamic>>> getCategorySummaries(String userId, String prefix, {int? year}) async {
    final db = await database;
    final whereClause = year != null ? "aggregate_key LIKE ? AND userId = ?" : "aggregate_key LIKE ? AND userId = ?";
    final whereArgs = year != null ? ['${prefix}_%_$year', userId] : ['${prefix}_%', userId];
    return await db.query(
      'analytics_aggregates',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<CategorySummary?> getGrandTotalSummary(String userId) async {
    final db = await database;
    final yearlySummaries = await getYearlySummaries(userId);

    if (yearlySummaries.isEmpty) {
      return null;
    }

    int totalInvestment = 0;
    int totalPayout = 0;
    int hitCount = 0;
    int betCount = 0;

    for (final summary in yearlySummaries) {
      totalInvestment += summary['total_investment'] as int;
      totalPayout += summary['total_payout'] as int;
      hitCount += summary['hit_count'] as int;
      betCount += summary['bet_count'] as int;
    }

    return CategorySummary(
      name: '総合計',
      investment: totalInvestment,
      payout: totalPayout,
      hitCount: hitCount,
      betCount: betCount,
    );
  }

  Future<List<PredictionStat>> getPredictionStats(String userId) async {
    final db = await database;
    final maps = await db.query(
      'analytics_aggregates',
      where: "aggregate_key LIKE 'prediction_%_stats' AND userId = ?",
      whereArgs: [userId],
    );

    if (maps.isEmpty) {
      return [];
    }

    final keyPattern = RegExp(r'^prediction_(.+)_(stats)$');
    final List<PredictionStat> resultList = [];

    for (final map in maps) {
      final key = map['aggregate_key'] as String;
      final match = keyPattern.firstMatch(key);
      if (match != null) {
        final mark = match.group(1)!;
        resultList.add(PredictionStat(
          mark: mark,
          totalCount: map['bet_count'] as int,
          winCount: map['hit_count'] as int,
          placeCount: map['total_investment'] as int,
          showCount: map['total_payout'] as int,
        ));
      }
    }
    resultList.sort((a, b) => a.mark.compareTo(b.mark));
    return resultList;
  }


  /// データベースファイルへの絶対パスを取得します。
  Future<String> getDbPath() async {
    final databasePath = await getDatabasesPath();
    return join(databasePath, 'hetaumakeiba_v2.db');
  }

  /// データベース接続を閉じます。
  Future<void> closeDb() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// 競走馬のメモを挿入または更新します。
  Future<int> insertOrUpdateHorseMemo(HorseMemo memo) async {
    final db = await database;
    return await db.insert(
      'horse_memos',
      memo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 複数の競走馬メモを一度に挿入または更新します（バッチ処理）。
  Future<void> insertOrUpdateMultipleMemos(List<HorseMemo> memos) async {
    final db = await database;
    final batch = db.batch();
    for (final memo in memos) {
      batch.insert(
        'horse_memos',
        memo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 特定のレースに紐づく全てのメモを取得します。
  Future<List<HorseMemo>> getMemosForRace(String userId, String raceId) async {
    final db = await database;
    final maps = await db.query(
      'horse_memos',
      where: 'userId = ? AND raceId = ?',
      whereArgs: [userId, raceId],
    );
    return List.generate(maps.length, (i) {
      return HorseMemo.fromMap(maps[i]);
    });
  }

  /// 新しいユーザーをデータベースに挿入します。
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert(
      'users',
      {
        'uuid': user.uuid,
        'username': user.username,
        'hashedPassword': user.hashedPassword,
        'createdAt': user.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }
  /// ユーザー情報を更新する
  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      {
        'hashedPassword': user.hashedPassword,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
  /// ユーザー名でユーザー情報を取得します。
  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      return User(
        id: map['id'] as int,
        uuid: map['uuid'] as String,
        username: map['username'] as String,
        hashedPassword: map['hashedPassword'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }
    return null;
  }

  /// UUIDでユーザー情報を取得します。
  Future<User?> getUserByUuid(String uuid) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      return User(
        id: map['id'] as int,
        uuid: map['uuid'] as String,
        username: map['username'] as String,
        hashedPassword: map['hashedPassword'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }
    return null;
  }

  Future<int> insertOrUpdateRaceStatistics(RaceStatistics stats) async {
    final db = await database;
    return await db.insert(
      'race_statistics',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RaceStatistics?> getRaceStatistics(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'race_statistics',
      where: 'raceId = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return RaceStatistics.fromMap(maps.first);
    }
    return null;
  }

  /// 分析キャッシュ（race_statisticsテーブル）をクリアします。
  Future<void> clearRaceStatistics() async {
    final db = await database;
    await db.delete('race_statistics');
  }

  Future<int> insertOrUpdateHorseStatsCache(HorseStatsCache cache) async {
    final db = await database;
    return await db.insert(
      'horse_stats_cache',
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<HorseStatsCache?> getHorseStatsCache(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'horse_stats_cache',
      where: 'raceId = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return HorseStatsCache.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertOrUpdateRaceSchedule(RaceSchedule schedule) async {
    final db = await database;
    return await db.insert(
      'race_schedules',
      {
        'date': schedule.date,
        'dayOfWeek': schedule.dayOfWeek,
        'scheduleJson': raceScheduleToJson(schedule),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, RaceSchedule>> getMultipleRaceSchedules(List<String> dates) async {
    if (dates.isEmpty) {
      return {};
    }
    final db = await database;
    final placeholders = List.filled(dates.length, '?').join(',');
    final maps = await db.query(
      'race_schedules',
      where: 'date IN ($placeholders)',
      whereArgs: dates,
    );

    final Map<String, RaceSchedule> results = {};
    for (final map in maps) {
      final schedule = raceScheduleFromJson(map['scheduleJson'] as String);
      results[schedule.date] = schedule;
    }
    return results;
  }

  Future<RaceSchedule?> getRaceSchedule(String date) async {
    final db = await database;
    final maps = await db.query(
      'race_schedules',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return raceScheduleFromJson(maps.first['scheduleJson'] as String);
    }
    return null;
  }
  /// 週ごとの開催日リストをDBにキャッシュとして保存または更新します。
  Future<void> insertOrUpdateWeekCache(String weekKey, List<String> availableDates) async {
    final db = await database;
    await db.insert(
      'week_schedules_cache',
      {
        'week_key': weekKey,
        'available_dates_json': json.encode(availableDates),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// DBからキャッシュされた週ごとの開催日リストを取得します。
  Future<List<String>?> getWeekCache(String weekKey) async {
    final db = await database;
    final maps = await db.query(
      'week_schedules_cache',
      where: 'week_key = ?',
      whereArgs: [weekKey],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final jsonString = maps.first['available_dates_json'] as String;
      return (json.decode(jsonString) as List<dynamic>).cast<String>();
    }
    return null;
  }

  Future<void> insertOrUpdateShutubaTableCache(ShutubaTableCache cache) async {
    final db = await database;
    await db.insert(
      'shutuba_table_cache',
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ShutubaTableCache?> getShutubaTableCache(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'shutuba_table_cache',
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ShutubaTableCache.fromMap(maps.first);
    }
    return null;
  }

  /// AI予測結果を複数件、一括で挿入または更新します。
  Future<void> insertOrUpdateAiPredictions(List<AiPrediction> predictions) async {
    final db = await database;
    final batch = db.batch();
    for (final prediction in predictions) {
      batch.insert(
        'ai_predictions',
        prediction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 指定されたレースIDのAI予測結果をすべて取得します。
  Future<List<AiPrediction>> getAiPredictionsForRace(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'ai_predictions',
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    return List.generate(maps.length, (i) {
      return AiPrediction.fromMap(maps[i]);
    });
  }

  /// データベースに保存されている全レース結果から、騎手ごとの得意条件を分析するロジック
  Future<Map<String, RaceResult>> getAllRaceResults() async {
    final db = await database;
    final maps = await db.query('race_results');
    final Map<String, RaceResult> results = {};
    for (final map in maps) {
      final result = raceResultFromJson(map['race_result_json'] as String);
      results[result.raceId] = result;
    }
    return results;
  }

  /// IDを指定してコースプリセットを取得します。
  Future<CoursePreset?> getCoursePreset(String id) async {
    final db = await database;
    final maps = await db.query(
      'course_presets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      return CoursePreset(
        id: map['id'] as String,
        venueCode: map['venueCode'] as String,
        venueName: map['venueName'] as String,
        distance: map['distance'] as String,
        direction: map['direction'] as String,
        straightLength: map['straightLength'] as int,
        courseLayout: map['courseLayout'] as String,
        keyPoints: map['keyPoints'] as String,
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
    final db = await database;

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
    return getHorsePerformanceRecords(horseId);
  }

  /// 取得した戦績リストをDBに一括保存します。
  Future<void> insertHorseRaceRecords(List<HorseRaceRecord> records) async {
    final db = await database;
    final batch = db.batch();

    for (var record in records) {
      batch.insert(
        'horse_performance',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }
  // ---------------------------------------------------------------------------
  // Step 2: 競走馬プロフィール管理用 追加メソッド
  // ---------------------------------------------------------------------------

  Future<int> insertOrUpdateHorseProfile(HorseProfile profile) async {
    final db = await database;
    try {
      print('DEBUG: DB insertOrUpdateHorseProfile called for ${profile.horseName} (${profile.horseId})');
      print('DEBUG: Image Path to save: ${profile.ownerImageLocalPath}');

      final result = await db.insert(
        'horse_profiles',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('DEBUG: DB insert success. Row ID: $result');
      return result;
    } catch (e) {
      print('DEBUG: [ERROR] DB insertOrUpdateHorseProfile failed: $e');
      return -1;
    }
  }

  /// 馬IDを指定して競走馬プロフィールを取得します。
  Future<HorseProfile?> getHorseProfile(String horseId) async {
    final db = await database;
    try {
      final maps = await db.query(
        'horse_profiles',
        where: 'horseId = ?',
        whereArgs: [horseId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        // print('DEBUG: Profile found for $horseId'); // 頻出するためコメントアウト推奨
        return HorseProfile.fromMap(maps.first);
      }
      // print('DEBUG: Profile NOT found for $horseId');
      return null;
    } catch (e) {
      print('DEBUG: [ERROR] getHorseProfile failed: $e');
      return null;
    }
  }
  /// 出馬表キャッシュを保存または更新します
  Future<void> insertShutubaTableCache(ShutubaTableCache cache) async {
    final db = await database;
    await db.insert(
      'shutuba_table_cache', // 既存の参照に合わせて単数形
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  /// レースIDから開催スケジュール(race_schedules)を検索し、そのレースが含まれる日付を返します。
  /// scheduleJson内にレースIDが含まれているかをLIKE検索で判定します。
  Future<String?> getDateFromScheduleByRaceId(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'race_schedules',
      columns: ['date'],
      where: 'scheduleJson LIKE ?',
      whereArgs: ['%$raceId%'],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['date'] as String;
    }
    return null;
  }
// ---------------------------------------------------------------------------
  // Step 3: 重賞一覧ページ専用 (JyusyoRace) メソッド
  // ---------------------------------------------------------------------------

  /// 重賞レースリストをDBにマージ保存します。
  Future<void> mergeJyusyoRaces(List<dynamic> races) async {
    final db = await database;

    await db.transaction((txn) async {
      for (var race in races) {
        final raceMap = (race as dynamic).toMap();

        // ★修正: yearも含めて検索
        final List<Map<String, dynamic>> existing = await txn.query(
          'jyusyo_races',
          columns: ['id', 'race_id'],
          where: 'year = ? AND date = ? AND race_name = ?',
          whereArgs: [raceMap['year'], raceMap['date'], raceMap['race_name']],
        );

        if (existing.isNotEmpty) {
          final currentId = existing.first['id'];
          final currentRaceId = existing.first['race_id'] as String?;
          final newRaceId = raceMap['race_id'] as String?;

          Map<String, dynamic> updateValues = {
            'grade': raceMap['grade'],
            'venue': raceMap['venue'],
            'distance': raceMap['distance'],
            'conditions': raceMap['conditions'],
            'weight': raceMap['weight'],
            'source_url': raceMap['source_url'],
          };

          // IDがない場合のみ新しいIDで更新
          if (currentRaceId == null && newRaceId != null) {
            updateValues['race_id'] = newRaceId;
          }

          await txn.update(
            'jyusyo_races',
            updateValues,
            where: 'id = ?',
            whereArgs: [currentId],
          );
        } else {
          await txn.insert('jyusyo_races', raceMap);
        }
      }
    });
  }

  /// ★追加: 指定した年の重賞レースを取得します。
  Future<List<Map<String, dynamic>>> getJyusyoRacesByYear(int year) async {
    final db = await database;
    return await db.query(
      'jyusyo_races',
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'id ASC', // 必要なら日付順などでソート
    );
  }

  // getAllJyusyoRacesは廃止または非推奨とします

  /// レースIDを更新します
  Future<void> updateJyusyoRaceId(int id, String newRaceId) async {
    final db = await database;
    await db.update(
      'jyusyo_races',
      {'race_id': newRaceId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}