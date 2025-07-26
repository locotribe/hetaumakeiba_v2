// lib/db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart'; // ★追加：新しいデータモデルをインポート

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
      version: 2, // ★★★★★ 修正箇所：データベースのバージョンを2に更新 ★★★★★
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // ★★★★★ 修正箇所：アップグレード処理を追加 ★★★★★
    );
  }

  // データベースが初めて作成されるときに呼ばれる
  Future<void> _onCreate(Database db, int version) async {
    // qr_codesテーブルを作成
    await db.execute('''
      CREATE TABLE qr_codes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        qr_code TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    // ★★★★★ 修正箇所：新しいrace_resultsテーブルも作成 ★★★★★
    await db.execute('''
      CREATE TABLE race_results(
        race_id TEXT PRIMARY KEY,
        race_data TEXT NOT NULL
      )
    ''');
  }

  // ★★★★★ 修正箇所：データベースのバージョンが上がった時に呼ばれる処理を追加 ★★★★★
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // バージョン2へのアップグレード：race_resultsテーブルを追加
      await db.execute('''
        CREATE TABLE race_results(
          race_id TEXT PRIMARY KEY,
          race_data TEXT NOT NULL
        )
      ''');
    }
  }

  // データの挿入
  Future<int> insertQrData(QrData qrData) async {
    final db = await database;
    return await db.insert('qr_codes', qrData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 全データの取得
  Future<List<QrData>> getAllQrData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('qr_codes', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
  }

  // 特定のIDのデータを削除
  Future<int> deleteQrData(int id) async {
    final db = await database;
    return await db.delete(
      'qr_codes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 全データの削除
  Future<int> deleteAllQrData() async {
    final db = await database;
    return await db.delete('qr_codes');
  }

  /// 指定されたQRコードがデータベースに存在するかどうかを確認します。
  Future<bool> qrCodeExists(String qrCode) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'qr_codes',
      where: 'qr_code = ?',
      whereArgs: [qrCode],
      limit: 1, // 1件見つかれば十分
    );
    return result.isNotEmpty;
  }

  // ★★★★★ ここから新しいメソッドを追加 ★★★★★

  /// レース結果をデータベースに挿入または更新します。
  Future<void> insertOrUpdateRaceResult(RaceResult result) async {
    final db = await database;
    await db.insert(
      'race_results',
      {
        'race_id': result.raceId,
        'race_data': raceResultToJson(result), // RaceResultオブジェクトをJSON文字列に変換
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // 既に存在する場合は上書き
    );
  }

  /// race_idをキーにレース結果を取得します。見つからない場合はnullを返します。
  Future<RaceResult?> getRaceResult(String raceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'race_results',
      where: 'race_id = ?',
      whereArgs: [raceId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      // JSON文字列をRaceResultオブジェクトに変換して返す
      return raceResultFromJson(maps.first['race_data'] as String);
    }
    return null;
  }
// ★★★★★ ここまで新しいメソッドを追加 ★★★★★
}
