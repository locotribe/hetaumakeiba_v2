// lib/db/repositories/featured_race_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';

class FeaturedRaceRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<int> insertOrUpdateFeaturedRace(FeaturedRace featuredRace) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DbConstants.tableFeaturedRaces,
      featuredRace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FeaturedRace>> getAllFeaturedRaces() async {
    final db = await _dbProvider.database;
    final maps = await db.query(DbConstants.tableFeaturedRaces, orderBy: 'last_scraped DESC');
    return List.generate(maps.length, (i) {
      return FeaturedRace.fromMap(maps[i]);
    });
  }

  Future<FeaturedRace?> getFeaturedRace(String raceId) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableFeaturedRaces,
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
    final db = await _dbProvider.database;
    return await db.delete(DbConstants.tableFeaturedRaces);
  }
}
