// lib/db/database_helper.dart

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
      version: 1,
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
      },
      /// データベースのバージョンがアップグレードされたときに呼び出されます。
      /// バージョンを1にリセットしたため、過去のアップグレードロジックは全て削除しました。
      /// 今後、新しいバージョンのスキーマ変更が必要になった場合に、ここに新しいアップグレードロジックを記述します。
      onUpgrade: (db, oldVersion, newVersion) async {
        // 例: もし将来的にバージョン2にアップグレードする場合
      //  if (oldVersion < 2) {

      //  }
      },
    );
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
  /// 主にデバッグやリセット機能のために使用します。
  Future<void> deleteAllDataForUser(String userId) async {

    final db = await database;
    await db.delete('qr_data', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('user_marks', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('user_feeds', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('analytics_aggregates', where: 'userId = ?', whereArgs: [userId]);
  }

  /// 分析用の集計データを更新します。
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
}
