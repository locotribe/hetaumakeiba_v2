// lib/db/repositories/course_preset_repository.dart

import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

class CoursePresetRepository {
  final DbProvider _dbProvider = DbProvider();

  Future<CoursePreset?> getCoursePreset(String id) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      DbConstants.tableCoursePresets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      return CoursePreset(
        id: map['id'] as String,
        venueCode: map['venueCode'] as String,
        venueName: map['venueName'] as String,
        distance: map['distance'] as String,
        direction: map['direction'] as String,
        straightLength: map['straightLength'] as int,
        courseLayout: map['courseLayout'] as String,
        keyPoints: map['keyPoints'] as String,
      );
    }
    return null;
  }
}