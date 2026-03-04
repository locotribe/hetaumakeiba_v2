// lib/db/db_constants.dart

class DbConstants {
  static const String dbName = 'hetaumakeiba_v2.db';
  static const int dbVersion = 11;

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
  static const String tableCoursePresets = 'course_presets';
  static const String tableHorseProfiles = 'horse_profiles';
  static const String tableJyusyoRaces = 'jyusyo_races';
  static const String tableTrackConditions = 'track_conditions';
  static const String tableRaceMemos = 'race_memos'; // 新規追加
  static const String tableTrainingTimes = 'training_times'; // 調教データ用テーブル

  // --- Common Columns ---
  static const String colId = 'id';
  static const String colUserId = 'userId';

  // --- Training Times Columns ---
  static const String colHorseId = 'horse_id';
  static const String colTrainingDate = 'training_date';
  static const String colTrainingTime = 'training_time';
  static const String colTrackType = 'track_type';
  static const String colLocation = 'location';
  static const String colF6 = 'f6';
  static const String colF5 = 'f5';
  static const String colF4 = 'f4';
  static const String colF3 = 'f3';
  static const String colF2 = 'f2';
  static const String colF1 = 'f1';
  static const String colStableName = 'stable_name';
}