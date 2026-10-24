// lib/logic/final_training_refetch.dart

// [追加] 出走の意味 調教の行 Step4: netkeiba の脚色が付いた後の、調教の取り直しの時刻と判定。
// 脚色は、GⅠはレースの2日前、それ以外の重賞は前日の13時頃に付く（オーナー確認・netkeiba のヘルプの掲載時刻）。通信はしない (v.2026.10.24+26102404)

/// 取り直しを始める時刻。GⅠは開催日の2日前の13時、それ以外は前日の13時。
DateTime finalTrainingRefetchTime(DateTime raceDay, {required bool isG1}) {
  final day = DateTime(raceDay.year, raceDay.month, raceDay.day);
  final base = DateTime(day.year, day.month, day.day - (isG1 ? 2 : 1), 13);
  return base;
}

/// 取り直すか。次の3つがすべて当てはまるとき true。
/// 1. 今が取り直しの時刻より後  2. 今日がレース日より前  3. その時刻より後に取り直した記録が無い
bool shouldRefetchFinalTraining({
  required DateTime raceDay,
  required bool isG1,
  required DateTime now,
  DateTime? lastRefetchedAt,
}) {
  final threshold = finalTrainingRefetchTime(raceDay, isG1: isG1);
  if (now.isBefore(threshold)) return false;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(raceDay.year, raceDay.month, raceDay.day);
  if (!today.isBefore(day)) return false;
  if (lastRefetchedAt != null && lastRefetchedAt.isAfter(threshold)) {
    return false;
  }
  return true;
}
