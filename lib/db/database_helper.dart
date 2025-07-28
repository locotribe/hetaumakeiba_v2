// lib/db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart'; // ★★★★★ 追加：競走馬成績モデルをインポート ★★★★★

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
      version: 1,
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
        // ★★★★★ ここから追加：競走馬成績データテーブルの作成 ★★★★★
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
        // ★★★★★ ここまで追加 ★★★★★
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

  // ★★★★★ ここから追加：HorsePerformanceデータ関連のメソッド ★★★★★

  /// 競走馬の単一の競走成績をデータベースに挿入または更新します。
  /// horse_idとdateが重複する場合は既存のレコードを上書きします。
  Future<int> insertOrUpdateHorsePerformance(HorseRaceRecord record) async {
    final db = await database;
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

  // ★★★★★ ここまで追加 ★★★★★

  /// 全てのデータを削除します。
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('qr_data');
    await db.delete('race_results');
    await db.delete('horse_performance'); // ★★★★★ 修正：競走馬成績データも削除対象に追加 ★★★★★
    print('DEBUG: All data deleted from qr_data, race_results, and horse_performance tables.');
  }
}
