// lib/db/repositories/user_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';

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
    await db.delete(DbConstants.tableAnalyticsAggregates, where: '${DbConstants.colUserId} = ?', whereArgs: [userId]);
  }

  // ---------------------------------------------------------------------------
  // 分析集計 (analytics_aggregates) 関連
  // ---------------------------------------------------------------------------

  Future<void> updateAggregates(String userId, Map<String, Map<String, int>> updates) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      for (final key in updates.keys) {
        final current = await txn.query(
          DbConstants.tableAnalyticsAggregates,
          where: 'aggregate_key = ? AND ${DbConstants.colUserId} = ?',
          whereArgs: [key, userId],
        );

        final Map<String, dynamic> updateValues = updates[key]!;
        if (current.isEmpty) {
          await txn.insert(DbConstants.tableAnalyticsAggregates, {
            'aggregate_key': key,
            DbConstants.colUserId: userId,
            'total_investment': updateValues['investment_delta'] ?? 0,
            'total_payout': updateValues['payout_delta'] ?? 0,
            'hit_count': updateValues['hit_delta'] ?? 0,
            'bet_count': updateValues['bet_delta'] ?? 0,
          });
        } else {
          await txn.update(
            DbConstants.tableAnalyticsAggregates,
            {
              'total_investment': (current.first['total_investment'] as int) + (updateValues['investment_delta'] ?? 0),
              'total_payout': (current.first['total_payout'] as int) + (updateValues['payout_delta'] ?? 0),
              'hit_count': (current.first['hit_count'] as int) + (updateValues['hit_delta'] ?? 0),
              'bet_count': (current.first['bet_count'] as int) + (updateValues['bet_delta'] ?? 0),
            },
            where: 'aggregate_key = ? AND ${DbConstants.colUserId} = ?',
            whereArgs: [key, userId],
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getYearlySummaries(String userId) async {
    final db = await _dbProvider.database;
    return await db.query(
      DbConstants.tableAnalyticsAggregates,
      where: "aggregate_key LIKE 'total_%' AND aggregate_key NOT LIKE 'total_%-%' AND ${DbConstants.colUserId} = ?",
      whereArgs: [userId],
      orderBy: 'aggregate_key ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyDataForYear(String userId, int year) async {
    final db = await _dbProvider.database;
    return await db.query(
      DbConstants.tableAnalyticsAggregates,
      where: "aggregate_key LIKE ? AND ${DbConstants.colUserId} = ?",
      whereArgs: ['total_$year-%', userId],
      orderBy: 'aggregate_key ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getCategorySummaries(String userId, String prefix, {int? year}) async {
    final db = await _dbProvider.database;
    final whereClause = year != null
        ? "aggregate_key LIKE ? AND ${DbConstants.colUserId} = ?"
        : "aggregate_key LIKE ? AND ${DbConstants.colUserId} = ?";
    final whereArgs = year != null ? ['${prefix}_%_$year', userId] : ['${prefix}_%', userId];
    return await db.query(
      DbConstants.tableAnalyticsAggregates,
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<CategorySummary?> getGrandTotalSummary(String userId) async {
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
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableAnalyticsAggregates,
      where: "aggregate_key LIKE 'prediction_%_stats' AND ${DbConstants.colUserId} = ?",
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
}