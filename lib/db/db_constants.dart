// lib/db/db_constants.dart

class DbConstants {
  static const String dbName = 'hetaumakeiba_v2.db';
  static const int dbVersion = 9;

  // --- Tables ---
  static const String tableQrData = 'qr_data';
  static const String tableRaceResults = 'race_results';
  static const String tableHorsePerformance = 'horse_performance';
  static const String tableFeaturedRaces = 'featured_races';
  static const String tableUserMarks = 'user_marks';
  static const String tableUserFeeds = 'user_feeds';
  static const String tableAnalyticsAggregates = 'analytics_aggregates';
  static const String tableHorseMemos = 'horse_memos';
  static const String tableUsers = 'users';
  static const String tableRaceStatistics = 'race_statistics';
  static const String tableHorseStatsCache = 'horse_stats_cache';
  static const String tableRaceSchedules = 'race_schedules';
  static const String tableWeekSchedulesCache = 'week_schedules_cache';
  static const String tableShutubaTableCache = 'shutuba_table_cache';
  static const String tableAiPredictions = 'ai_predictions';
  static const String tableCoursePresets = 'course_presets';
  static const String tableHorseProfiles = 'horse_profiles';
  static const String tableJyusyoRaces = 'jyusyo_races';
  static const String tableTrackConditions = 'track_conditions';

  // --- Common Columns ---
  static const String colId = 'id';
  static const String colUserId = 'userId';
}