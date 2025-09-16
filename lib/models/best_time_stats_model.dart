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

  Map<String, dynamic> toMap() {
    return {
      'timeInSeconds': timeInSeconds,
      'formattedTime': formattedTime,
      'trackCondition': trackCondition,
      'raceName': raceName,
      'date': date,
    };
  }

  factory BestTimeStats.fromMap(Map<String, dynamic> map) {
    return BestTimeStats(
      timeInSeconds: (map['timeInSeconds'] as num).toDouble(),
      formattedTime: map['formattedTime'] as String,
      trackCondition: map['trackCondition'] as String,
      raceName: map['raceName'] as String,
      date: map['date'] as String,
    );
  }
}