// lib/db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart'; // ★追加
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart'; // ★追加
import 'dart:convert'; // ★追加
import 'package:hetaumakeiba_v2/models/analytics_summary_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'hetaumakeiba_v2.db');

    return await openDatabase(
      path,
      version: 3, // ★バージョンを2から3に更新
      onCreate: (db, version) async {
        // QRコードデータテーブルの作成
        await db.execute('''
          CREATE TABLE qr_data(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
            shutubaHorsesJson TEXT  -- ★追加
          )
        ''');
        // ★追加：user_marks データテーブルの作成
        await db.execute('''
          CREATE TABLE user_marks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            raceId TEXT NOT NULL,
            horseId TEXT NOT NULL,
            mark TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            UNIQUE(raceId, horseId) ON CONFLICT REPLACE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ★onUpgrade メソッドを追加/修正
        if (oldVersion < 2) {
          // featured_races テーブルに shutubaHorsesJson カラムを追加
          await db.execute('ALTER TABLE featured_races ADD COLUMN shutubaHorsesJson TEXT');
          // user_marks テーブルを作成
          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_marks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              raceId TEXT NOT NULL,
              horseId TEXT NOT NULL,
              mark TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              UNIQUE(raceId, horseId) ON CONFLICT REPLACE
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE analytics_summaries(
              period TEXT PRIMARY KEY,
              totalInvestment INTEGER,
              totalPayout INTEGER,
              hitCount INTEGER,
              betCount INTEGER,
              lastCalculated TEXT
            )
          ''');
        }
      },
    );
  }

  // QRデータ関連のメソッド

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

  Future<QrData?> getQrData(int id) async {
    final db = await database;
    final maps = await db.query(
      'qr_data',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return QrData.fromMap(maps.first);
    }
    return null;
  }

  Future<List<QrData>> getAllQrData() async {
    final db = await database;
    final maps = await db.query('qr_data', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
  }

  Future<int> insertQrData(QrData qrData) async {
    final db = await database;
    return await db.insert(
      'qr_data',
      qrData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteQrData(int id) async {
    final db = await database;
    return await db.delete(
      'qr_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // RaceResultデータ関連のメソッド

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

  // HorsePerformanceデータ関連のメソッド

  /// 競走馬の単一の競走成績をデータベースに挿入または更新します。
  /// horse_idとdateが重複する場合は既存のレコードを上書きします。
  Future<int> insertOrUpdateHorsePerformance(HorseRaceRecord record) async {
    final db = await database;
    print('--- [DB Save] Horse Performance ---'); //
    print('Horse ID: ${record.horseId}, Date: ${record.date}, Race: ${record.raceName}, Rank: ${record.rank}'); //
    return await db.insert(
      'horse_performance',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // 重複した場合は更新
    );
  }

  /// 特定の競走馬の全ての競走成績を取得します。
  Future<List<HorseRaceRecord>> getHorsePerformanceRecords(String horseId) async {
    final db = await database;
    final maps = await db.query(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'date DESC', // 日付の新しい順にソート
    );
    return List.generate(maps.length, (i) {
      return HorseRaceRecord.fromMap(maps[i]);
    });
  }

  /// 特定の競走馬の最新の競走成績を1件取得します。
  Future<HorseRaceRecord?> getLatestHorsePerformanceRecord(String horseId) async {
    final db = await database;
    final maps = await db.query(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
      orderBy: 'date DESC', // 日付の新しい順にソート
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return HorseRaceRecord.fromMap(maps.first);
    }
    return null;
  }

  /// 特定の競走馬の全ての競走成績を削除します。
  Future<int> deleteHorsePerformance(String horseId) async {
    final db = await database;
    return await db.delete(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
    );
  }

  // FeaturedRaceデータ関連のメソッド

  /// 注目レースの単一のレコードをデータベースに挿入または更新します。
  /// race_idが重複する場合は既存のレコードを上書きします。
  Future<int> insertOrUpdateFeaturedRace(FeaturedRace featuredRace) async {
    final db = await database;
    print('--- DBに保存するFeaturedRaceデータ ---');
    print('[DB Save] 注目レース: ${featuredRace.raceName}');
    print('------------------------------------');
    return await db.insert(
      'featured_races',
      featuredRace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // 重複した場合は更新
    );
  }

  /// データベースに保存されている全ての注目レースを取得します。
  Future<List<FeaturedRace>> getAllFeaturedRaces() async {
    final db = await database;
    final maps = await db.query('featured_races', orderBy: 'last_scraped DESC'); // 最新のスクレイピング日時でソート
    return List.generate(maps.length, (i) {
      return FeaturedRace.fromMap(maps[i]);
    });
  }

  /// 特定の注目レースをraceIdで取得します。
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

  // ★追加：UserMark 関連のメソッド
  Future<int> insertOrUpdateUserMark(UserMark mark) async {
    final db = await database;
    return await db.insert(
      'user_marks',
      mark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserMark?> getUserMark(String raceId, String horseId) async {
    final db = await database;
    final maps = await db.query(
      'user_marks',
      where: 'raceId = ? AND horseId = ?',
      whereArgs: [raceId, horseId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserMark.fromMap(maps.first);
    }
    return null;
  }

  Future<List<UserMark>> getAllUserMarksForRace(String raceId) async {
    final db = await database;
    final maps = await db.query(
      'user_marks',
      where: 'raceId = ?',
      whereArgs: [raceId],
    );
    return List.generate(maps.length, (i) {
      return UserMark.fromMap(maps[i]);
    });
  }

  Future<int> deleteUserMark(String raceId, String horseId) async {
    final db = await database;
    return await db.delete(
      'user_marks',
      where: 'raceId = ? AND horseId = ?',
      whereArgs: [raceId, horseId],
    );
  }

  // AnalyticsSummary (キャッシュ) 関連のメソッド
  Future<void> insertOrUpdateSummary(AnalyticsSummary summary) async {
    final db = await database;
    await db.insert(
      'analytics_summaries',
      summary.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AnalyticsSummary?> getSummary(String period) async {
    final db = await database;
    final maps = await db.query(
      'analytics_summaries',
      where: 'period = ?',
      whereArgs: [period],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return AnalyticsSummary.fromMap(maps.first);
    }
    return null;
  }

  Future<void> deleteSummary(String period) async {
    final db = await database;
    await db.delete(
      'analytics_summaries',
      where: 'period = ?',
      whereArgs: [period],
    );
  }

  /// 全てのデータを削除します。
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('qr_data');
    await db.delete('race_results');
    await db.delete('horse_performance');
    await db.delete('featured_races');
    await db.delete('user_marks'); // ★追加
    await db.delete('analytics_summaries');
    print('DEBUG: All data deleted from qr_data, race_results, horse_performance, featured_races, user_marks, and analytics_summaries tables.');
  }
}