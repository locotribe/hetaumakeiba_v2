// lib/models/best_time_stats_model.dart

class BestTimeStats {
  final double timeInSeconds;     // 秒に変換されたタイム (例: 118.2)
  final String formattedTime;     // 表示用のタイム文字列 (例: "1:58.2")
  final String trackCondition;    // そのタイムが記録された馬場状態 (例: "良")
  final String raceName;          // そのタイムが記録されたレース名
  final String date;              // そのタイムが記録された日付

  BestTimeStats({
    required this.timeInSeconds,
    required this.formattedTime,
    required this.trackCondition,
    required this.raceName,
    required this.date,
  });
}