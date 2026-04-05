// lib/db/db_constants.dart

class DbConstants {
  static const String dbName = 'hetaumakeiba_v2.db';
  // [修正] 12 -> 13に更新 (v.13)
  static const int dbVersion = 13;

  // --- Tables ---
  static const String tableQrData = 'qr_data';
  static const String tableRaceResults = 'race_results';
  static const String tableHorsePerformance = 'horse_performance';
  static const String tableFeaturedRaces = 'featured_races';
  static const String tableUserMarks = 'user_marks';
  static const String tableUserFeeds = 'user_feeds';
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
  static const String tableRaceMemos = 'race_memos';
  static const String tableTrainingTimes = 'training_times';
  // 統合レーステーブル
  static const String tableIntegratedRaces = 'integrated_races';

  // --- Common Columns ---
  static const String colId = 'id';
  static const String colUserId = 'userId';
  static const String colRaceId = 'race_id';

  // 統合レーステーブル用カラム
  static const String colTrackType = 'track_type';
  static const String colDistanceValue = 'distance_value';
  static const String colDirection = 'direction';
  static const String colCourseInOut = 'course_in_out';
  static const String colWeather = 'weather';
  static const String colTrackCondition = 'track_condition';
  static const String colHoldingTimes = 'holding_times';
  static const String colHoldingDays = 'holding_days';
  static const String colRaceCategory = 'race_category';
  static const String colHorseCount = 'horse_count';
  static const String colStartTime = 'start_time';
  static const String colBasePrize1st = 'base_prize_1st';
  static const String colBasePrize2nd = 'base_prize_2nd';
  static const String colBasePrize3rd = 'base_prize_3rd';
  static const String colBasePrize4th = 'base_prize_4th';
  static const String colBasePrize5th = 'base_prize_5th';

  static const String colHasShutuba = 'has_shutuba';
  static const String colHasResult = 'has_result';
  static const String colShutubaJson = 'shutuba_json';
  static const String colResultJson = 'result_json';
  static const String colShutubaLastUpdated = 'shutuba_last_updated';
  static const String colResultLastUpdated = 'result_last_updated';

  // --- Training Times Columns ---
  static const String colHorseId = 'horse_id';
  static const String colTrainingDate = 'training_date';
  static const String colTrainingTime = 'training_time';
  static const String colTrackTypeForTraining = 'track_type';
  static const String colLocation = 'location';
  static const String colF6 = 'f6';
  static const String colF5 = 'f5';
  static const String colF4 = 'f4';
  static const String colF3 = 'f3';
  static const String colF2 = 'f2';
  static const String colF1 = 'f1';
  static const String colStableName = 'stable_name';
}