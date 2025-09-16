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

  Map<String, dynamic> toMap() {
    return {
      'agariInSeconds': agariInSeconds,
      'formattedAgari': formattedAgari,
      'trackCondition': trackCondition,
      'raceName': raceName,
      'date': date,
    };
  }

  factory FastestAgariStats.fromMap(Map<String, dynamic> map) {
    return FastestAgariStats(
      agariInSeconds: (map['agariInSeconds'] as num).toDouble(),
      formattedAgari: map['formattedAgari'] as String,
      trackCondition: map['trackCondition'] as String,
      raceName: map['raceName'] as String,
      date: map['date'] as String,
    );
  }
}