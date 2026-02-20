// lib/models/track_conditions_model.dart

class TrackConditionRecord {
  final int trackConditionId; // 主キー (12桁: YYYYCCKKDDNN)
  final String date;          // 測定日 (YYYY-MM-DD)
  final String weekDay;       // 曜日 (mo, tu, we, th, fr, sa, su)
  final double? cushionValue; // 芝クッション値
  final double? moistureTurfGoal; // 芝含水率：ゴール前
  final double? moistureTurf4c;   // 芝含水率：4コーナー
  final double? moistureDirtGoal; // ダート含水率：ゴール前
  final double? moistureDirt4c;   // ダート含水率：4コーナー

  TrackConditionRecord({
    required this.trackConditionId,
    required this.date,
    required this.weekDay,
    this.cushionValue,
    this.moistureTurfGoal,
    this.moistureTurf4c,
    this.moistureDirtGoal,
    this.moistureDirt4c,
  });

  factory TrackConditionRecord.fromJson(Map<String, dynamic> json) {
    return TrackConditionRecord(
      trackConditionId: json['track_condition_id'] as int,
      date: json['date'] as String,
      weekDay: json['week_day'] as String,
      cushionValue: (json['cushion_value'] as num?)?.toDouble(),
      moistureTurfGoal: (json['moisture_turf_goal'] as num?)?.toDouble(),
      moistureTurf4c: (json['moisture_turf_4c'] as num?)?.toDouble(),
      moistureDirtGoal: (json['moisture_dirt_goal'] as num?)?.toDouble(),
      moistureDirt4c: (json['moisture_dirt_4c'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_condition_id': trackConditionId,
      'date': date,
      'week_day': weekDay,
      'cushion_value': cushionValue,
      'moisture_turf_goal': moistureTurfGoal,
      'moisture_turf_4c': moistureTurf4c,
      'moisture_dirt_goal': moistureDirtGoal,
      'moisture_dirt_4c': moistureDirt4c,
    };
  }

  @override
  String toString() {
    return 'ID:$trackConditionId | $date($weekDay)\nクッション:$cushionValue | 芝(G/4C):$moistureTurfGoal/$moistureTurf4c | ダ(G/4C):$moistureDirtGoal/$moistureDirt4c';
  }
}