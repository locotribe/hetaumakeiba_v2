// lib/logic/track_condition_active_filter.dart

// [追加] 馬場状態ページに表示する「開催中の会場」を、最新測定日の新しさで絞り込む (v.2026.10.6+26100602)

/// 開催中とみなす、最新測定日の差の上限（日数）。
/// 全会場で最も新しい測定日から、この日数以内に測定がある会場だけを開催中とする。
const int kActiveMeetingMaxLagDays = 4;

/// [candidateNames] の並び順を保ったまま、開催中の会場名だけを返す。
/// [latestDateByName] は 会場名 → その会場の最新測定日（'YYYY-MM-DD'）。
/// 最新測定日が無い・日付として読めない会場は除く。
List<String> selectActiveCourseNames(
  List<String> candidateNames,
  Map<String, String> latestDateByName, {
  int maxLagDays = kActiveMeetingMaxLagDays,
}) {
  final Map<String, DateTime> dates = {};
  for (final name in candidateNames) {
    final dateStr = latestDateByName[name];
    if (dateStr == null) continue;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) continue;
    dates[name] = DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
  if (dates.isEmpty) return [];

  DateTime newest = dates.values.first;
  for (final d in dates.values) {
    if (d.isAfter(newest)) newest = d;
  }

  return candidateNames
      .where((name) =>
          dates.containsKey(name) &&
          newest.difference(dates[name]!).inDays <= maxLagDays)
      .toList();
}
