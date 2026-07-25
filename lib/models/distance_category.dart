// lib/models/distance_category.dart

// [追加] 距離カテゴリ（0-4 距離延長短縮の隣接カテゴリ跨ぎ判定用） (v.2026.7.26+26072602)
enum DistanceCategory {
  sprint, // 〜1300m
  mile,   // 1400〜1600m
  middle, // 1700〜2000m
  long,   // 2100m〜
}

// [追加] メートル値を距離カテゴリに分類する（不明はnull） (v.2026.7.26+26072602)
DistanceCategory? distanceCategoryOf(int? meters) {
  if (meters == null || meters <= 0) return null;
  if (meters <= 1300) return DistanceCategory.sprint;
  if (meters <= 1600) return DistanceCategory.mile;
  if (meters <= 2000) return DistanceCategory.middle;
  return DistanceCategory.long;
}
