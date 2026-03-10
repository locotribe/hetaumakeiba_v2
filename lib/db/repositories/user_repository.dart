// lib/db/repositories/user_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';

class UserRepository {
  final DbProvider _dbProvider = DbProvider();

  // ---------------------------------------------------------------------------
  // ユーザー (users) 関連
  // ---------------------------------------------------------------------------

  Future<int> insertUser(User user) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableUsers,
      {
        'uuid': user.uuid,
        'username': user.username,
        'hashedPassword': user.hashedPassword,
        'createdAt': user.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<int> updateUser(User user) async {
    final db = await _dbProvider.database;
    return await db.update(
      DbConstants.tableUsers,
      {
        'hashedPassword': user.hashedPassword,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [user.id],
    );
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableUsers,
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

  Future<User?> getUserByUuid(String uuid) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableUsers,
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

  // ---------------------------------------------------------------------------
  // ユーザーの印 (user_marks) 関連
  // ---------------------------------------------------------------------------

  Future<int> insertOrUpdateUserMark(UserMark mark) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableUserMarks,
      mark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserMark?> getUserMark(String userId, String raceId, String horseId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableUserMarks,
      where: '${DbConstants.colUserId} = ? AND raceId = ? AND horseId = ?',
      whereArgs: [userId, raceId, horseId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserMark.fromMap(maps.first);
    }
    return null;
  }

  Future<List<UserMark>> getAllUserMarksForRace(String userId, String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableUserMarks,
      where: '${DbConstants.colUserId} = ? AND raceId = ?',
      whereArgs: [userId, raceId],
    );
    return List.generate(maps.length, (i) {
      return UserMark.fromMap(maps[i]);
    });
  }

  Future<int> deleteUserMark(String userId, String raceId, String horseId) async {
    final db = await _dbProvider.database;
    return await db.delete(
      DbConstants.tableUserMarks,
      where: '${DbConstants.colUserId} = ? AND raceId = ? AND horseId = ?',
      whereArgs: [userId, raceId, horseId],
    );
  }

  // ---------------------------------------------------------------------------
  // ユーザーフィード (user_feeds) 関連
  // ---------------------------------------------------------------------------

  Future<int> insertFeed(Feed feed) async {
    final db = await _dbProvider.database;
    return await db.insert(DbConstants.tableUserFeeds, feed.toMap());
  }

  Future<List<Feed>> getAllFeeds(String userId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
        DbConstants.tableUserFeeds,
        where: '${DbConstants.colUserId} = ?',
        whereArgs: [userId],
        orderBy: 'display_order ASC'
    );
    return List.generate(maps.length, (i) {
      return Feed.fromMap(maps[i]);
    });
  }

  Future<int> updateFeed(Feed feed) async {
    final db = await _dbProvider.database;
    return await db.update(
      DbConstants.tableUserFeeds,
      feed.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [feed.id],
    );
  }

  Future<int> deleteFeed(int id) async {
    final db = await _dbProvider.database;
    return await db.delete(
      DbConstants.tableUserFeeds,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateFeedOrder(List<Feed> feeds) async {
    final db = await _dbProvider.database;
    final batch = db.batch();
    for (int i = 0; i < feeds.length; i++) {
      final feed = feeds[i];
      batch.update(
        DbConstants.tableUserFeeds,
        {'display_order': i},
        where: '${DbConstants.colId} = ?',
        whereArgs: [feed.id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // ユーザーの全データ削除
  // ---------------------------------------------------------------------------

  Future<void> deleteAllDataForUser(String userId) async {
    final db = await _dbProvider.database;
    await db.delete(DbConstants.tableQrData, where: '${DbConstants.colUserId} = ?', whereArgs: [userId]);
    await db.delete(DbConstants.tableUserMarks, where: '${DbConstants.colUserId} = ?', whereArgs: [userId]);
    await db.delete(DbConstants.tableUserFeeds, where: '${DbConstants.colUserId} = ?', whereArgs: [userId]);
  }
}