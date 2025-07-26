// lib/db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'qr_codes.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE qr_codes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        qr_code TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE race_results(
        race_id TEXT PRIMARY KEY,
        race_data TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE race_results(
          race_id TEXT PRIMARY KEY,
          race_data TEXT NOT NULL
        )
      ''');
    }
  }

  Future<int> insertQrData(QrData qrData) async {
    final db = await database;
    return await db.insert('qr_codes', qrData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<QrData>> getAllQrData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('qr_codes', orderBy: 'timestamp ASC');
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
  }

  Future<int> deleteQrData(int id) async {
    final db = await database;
    return await db.delete(
      'qr_codes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ★★★★★ 修正箇所：メソッド名を変更し、レース結果テーブルも削除するように修正 ★★★★★
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('qr_codes'); // 馬券データをすべて削除
    await db.delete('race_results'); // レース結果データもすべて削除
  }

  Future<bool> qrCodeExists(String qrCode) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'qr_codes',
      where: 'qr_code = ?',
      whereArgs: [qrCode],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertOrUpdateRaceResult(RaceResult result) async {
    final db = await database;
    await db.insert(
      'race_results',
      {
        'race_id': result.raceId,
        'race_data': raceResultToJson(result),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RaceResult?> getRaceResult(String raceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'race_results',
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return raceResultFromJson(maps.first['race_data'] as String);
    }
    return null;
  }
}
