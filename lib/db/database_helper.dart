// lib/db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';

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
      version: 1, // バージョンを1のまま維持
      onCreate: _onCreate,
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

  // ==== ここから新しいメソッドの追加 ====
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
// ==== ここまで新しいメソッドの追加 ====
}