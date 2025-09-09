// lib/models/fastest_agari_stats_model.dart

class FastestAgariStats {
  final double agariInSeconds;    // 秒数に変換された上がりタイム (例: 34.5)
  final String formattedAgari;    // 表示用のタイム文字列 (例: "34.5")
  final String trackCondition;    // そのタイムが記録された馬場状態 (例: "良")
  final String raceName;          // そのタイムが記録されたレース名
  final String date;              // そのタイムが記録された日付

  FastestAgariStats({
    required this.agariInSeconds,
    required this.formattedAgari,
    required this.trackCondition,
    required this.raceName,
    required this.date,
  });
}