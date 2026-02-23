// lib/db/repositories/ticket_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';

/// QRコードおよび馬券データに関するデータベース操作を行うリポジトリ。
class TicketRepository {
  final DbProvider _dbProvider = DbProvider();

  /// 指定されたQRコードがデータベースに存在するかを確認します。
  Future<bool> qrCodeExists(String qrCode) async {
    final db = await _dbProvider.database;
    final count = Sqflite.firstIntValue(await db.query(
      DbConstants.tableQrData,
      columns: ['COUNT(*)'],
      where: 'qr_code = ?',
      whereArgs: [qrCode],
    ));
    return count != null && count > 0;
  }

  /// IDとユーザーIDを指定して単一のQRコードデータを取得します。
  Future<QrData?> getQrData(int id, String userId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableQrData,
      where: '${DbConstants.colId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
    if (maps.isNotEmpty) {
      return QrData.fromMap(maps.first);
    }
    return null;
  }

  /// 指定したユーザーの保存されている全てのQRコードデータを取得します。
  Future<List<QrData>> getAllQrData(String userId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableQrData,
      where: '${DbConstants.colUserId} = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
  }

  /// レースIDを指定して馬券データを高速に取得します。
  Future<List<QrData>> getQrDataByRaceId(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableQrData,
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return QrData.fromMap(maps[i]);
    });
  }

  /// 新しいQRコードデータをデータベースに挿入または更新します。
  Future<int> insertQrData(QrData qrData) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableQrData,
      qrData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// IDとユーザーIDを指定してQRコードデータを削除します。
  Future<int> deleteQrData(int id, String userId) async {
    final db = await _dbProvider.database;
    return await db.delete(
      DbConstants.tableQrData,
      where: '${DbConstants.colId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
  }
}