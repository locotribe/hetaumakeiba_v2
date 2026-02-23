// lib/db/db_provider.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/course_presets.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';

/// アプリケーションのSQLiteデータベース接続と初期化・マイグレーションを管理するクラス。
class DbProvider {
  static final DbProvider _instance = DbProvider._internal();
  static Database? _database;

  factory DbProvider() => _instance;

  DbProvider._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, DbConstants.dbName);

    return await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // テーブル作成ロジックをDatabaseHelperから完全移植
    await db.execute('''
      CREATE TABLE ${DbConstants.tableQrData}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        qr_code TEXT UNIQUE,
        timestamp TEXT,
        parsed_data_json TEXT,
        race_id TEXT 
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableRaceResults}(
        race_id TEXT PRIMARY KEY,
        race_result_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableHorsePerformance}(
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

    await db.execute('''
      CREATE TABLE ${DbConstants.tableFeaturedRaces}(
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

    await db.execute('''
      CREATE TABLE ${DbConstants.tableUserMarks}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        raceId TEXT NOT NULL,
        horseId TEXT NOT NULL,
        mark TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        UNIQUE(userId, raceId, horseId) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableUserFeeds}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        type TEXT NOT NULL,
        display_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableAnalyticsAggregates}(
        aggregate_key TEXT NOT NULL,
        userId TEXT NOT NULL,
        total_investment INTEGER NOT NULL DEFAULT 0,
        total_payout INTEGER NOT NULL DEFAULT 0,
        hit_count INTEGER NOT NULL DEFAULT 0,
        bet_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (aggregate_key, userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableHorseMemos}(
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

    await db.execute('''
      CREATE TABLE ${DbConstants.tableUsers}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        username TEXT NOT NULL UNIQUE,
        hashedPassword TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableRaceStatistics}(
        raceId TEXT PRIMARY KEY,
        raceName TEXT NOT NULL,
        statisticsJson TEXT NOT NULL,
        analyzedRacesJson TEXT,
        lastUpdatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableHorseStatsCache}(
        raceId TEXT PRIMARY KEY,
        statsJson TEXT NOT NULL,
        lastUpdatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableRaceSchedules}(
        date TEXT PRIMARY KEY,
        dayOfWeek TEXT NOT NULL,
        scheduleJson TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableWeekSchedulesCache}(
        week_key TEXT PRIMARY KEY,
        available_dates_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableShutubaTableCache}(
        race_id TEXT PRIMARY KEY,
        shutuba_data_json TEXT,
        last_updated TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableAiPredictions}(
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

    await _createCoursePresetsTable(db);
    await _initCoursePresets(db);

    await db.execute('''
      CREATE TABLE ${DbConstants.tableHorseProfiles}(
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

    await db.execute('''
      CREATE TABLE ${DbConstants.tableJyusyoRaces}(
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

    await db.execute('''
      CREATE TABLE ${DbConstants.tableTrackConditions}(
        track_condition_id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,
        week_day TEXT NOT NULL,
        cushion_value REAL,
        moisture_turf_goal REAL,
        moisture_turf_4c REAL,
        moisture_dirt_goal REAL,
        moisture_dirt_4c REAL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // DatabaseHelperの安全なマイグレーションロジックを完全移植
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE ${DbConstants.tableRaceStatistics} ADD COLUMN analyzedRacesJson TEXT');
      } catch (e) { print('Migration error (v1->v2): $e'); }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE ${DbConstants.tableFeaturedRaces} ADD COLUMN shutubaHorsesJson TEXT');
      } catch (e) { print('Migration error (v2->v3): $e'); }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DbConstants.tableHorseProfiles}(
            horseId TEXT PRIMARY KEY, horseName TEXT, birthday TEXT, ownerId TEXT, ownerName TEXT,
            ownerImageLocalPath TEXT, trainerId TEXT, trainerName TEXT, breederName TEXT,
            fatherId TEXT, fatherName TEXT, motherId TEXT, motherName TEXT,
            ffName TEXT, fmName TEXT, mfName TEXT, mmName TEXT, lastUpdated TEXT
          )
        ''');
      } catch (e) { print('DEBUG: Migration error (v4->v5): $e'); }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DbConstants.tableJyusyoRaces}(
            id INTEGER PRIMARY KEY AUTOINCREMENT, race_id TEXT, date TEXT NOT NULL,
            race_name TEXT NOT NULL, grade TEXT, venue TEXT, distance TEXT,
            conditions TEXT, weight TEXT, source_url TEXT, UNIQUE(date, race_name)
          )
        ''');
      } catch (e) { print('DEBUG: Migration error (v5->v6): $e'); }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableJyusyoRaces}');
        await db.execute('''
          CREATE TABLE ${DbConstants.tableJyusyoRaces}(
            id INTEGER PRIMARY KEY AUTOINCREMENT, race_id TEXT, year INTEGER NOT NULL,
            date TEXT NOT NULL, race_name TEXT NOT NULL, grade TEXT, venue TEXT,
            distance TEXT, conditions TEXT, weight TEXT, source_url TEXT,
            UNIQUE(year, date, race_name)
          )
        ''');
      } catch (e) { print('DEBUG: Migration error (v6->v7): $e'); }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE ${DbConstants.tableQrData} ADD COLUMN race_id TEXT');
        final List<Map<String, dynamic>> allQrData = await db.query(DbConstants.tableQrData);
        final batch = db.batch();
        for (final row in allQrData) {
          final id = row['id'] as int;
          final qrCode = row['qr_code'] as String;
          final generatedId = generateRaceIdFromQr(qrCode);
          if (generatedId != null) {
            batch.update(DbConstants.tableQrData, {'race_id': generatedId}, where: 'id = ?', whereArgs: [id]);
          }
        }
        await batch.commit(noResult: true);
      } catch (e) { print('DEBUG: Migration error (v7->v8): $e'); }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DbConstants.tableTrackConditions}(
            track_condition_id INTEGER PRIMARY KEY, date TEXT NOT NULL, week_day TEXT NOT NULL,
            cushion_value REAL, moisture_turf_goal REAL, moisture_turf_4c REAL,
            moisture_dirt_goal REAL, moisture_dirt_4c REAL
          )
        ''');
      } catch (e) { print('DEBUG: Migration error (v8->v9): $e'); }
    }
  }

  Future<void> _createCoursePresetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableCoursePresets}(
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

  Future<void> _initCoursePresets(Database db) async {
    final batch = db.batch();
    for (final preset in coursePresets) {
      batch.insert(
        DbConstants.tableCoursePresets,
        preset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> closeDb() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}