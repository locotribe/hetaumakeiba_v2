// lib/db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/ticket_status_enum.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'dart:convert';

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
            shutubaHorsesJson TEXT
          )
        ''');
        // user_marks データテーブルの作成
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
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE featured_races ADD COLUMN shutubaHorsesJson TEXT');
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
        // --- ▼▼▼ Step 1 で追加 ▼▼▼ ---
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE qr_data ADD COLUMN status TEXT');
          await db.execute('ALTER TABLE qr_data ADD COLUMN isHit INTEGER');
          await db.execute('ALTER TABLE qr_data ADD COLUMN payout INTEGER');
          await db.execute('ALTER TABLE qr_data ADD COLUMN hitDetails TEXT');
        }
        // --- ▲▲▲ Step 1 で追加 ▲▲▲ ---
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

  Future<List<QrData>> getUnsettledQrData() async {
    final db = await database;
    final maps = await db.query(
      'qr_data',
      where: 'status = ?',
      whereArgs: [TicketStatus.unsettled.name],
    );
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
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

  Future<int> updateQrData(QrData qrData) async {
    final db = await database;
    return await db.update(
      'qr_data',
      qrData.toMap(),
      where: 'id = ?',
      whereArgs: [qrData.id],
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

  Future<int> insertOrUpdateHorsePerformance(HorseRaceRecord record) async {
    final db = await database;
    print('--- [DB Save] Horse Performance ---');
    print('Horse ID: ${record.horseId}, Date: ${record.date}, Race: ${record.raceName}, Rank: ${record.rank}');
    return await db.insert(
      'horse_performance',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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

  Future<int> deleteHorsePerformance(String horseId) async {
    final db = await database;
    return await db.delete(
      'horse_performance',
      where: 'horse_id = ?',
      whereArgs: [horseId],
    );
  }

  // FeaturedRaceデータ関連のメソッド

  Future<int> insertOrUpdateFeaturedRace(FeaturedRace featuredRace) async {
    final db = await database;
    print('--- DBに保存するFeaturedRaceデータ ---');
    print(featuredRace.toMap());
    print('------------------------------------');
    return await db.insert(
      'featured_races',
      featuredRace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FeaturedRace>> getAllFeaturedRaces() async {
    final db = await database;
    final maps = await db.query('featured_races', orderBy: 'last_scraped DESC');
    return List.generate(maps.length, (i) {
      return FeaturedRace.fromMap(maps[i]);
    });
  }

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

  Future<int> deleteAllFeaturedRaces() async {
    final db = await database;
    return await db.delete('featured_races');
  }

  // UserMark 関連のメソッド
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

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('qr_data');
    await db.delete('race_results');
    await db.delete('horse_performance');
    await db.delete('featured_races');
    await db.delete('user_marks');
    print('DEBUG: All data deleted from qr_data, race_results, horse_performance, featured_races, and user_marks tables.');
  }
}