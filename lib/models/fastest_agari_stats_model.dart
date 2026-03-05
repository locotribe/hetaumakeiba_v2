// lib/models/fastest_agari_stats_model.dart

class FastestAgariStats {
  final double agariInSeconds;
  final String formattedAgari;
  final String trackCondition;
  final String raceName;
  final String date;

  final String? sourceRaceId;
  final String? venueAndDistance;
  final double? cushionValue;
  // ▼ 変更: 1つだった含水率を、ゴール前(G)と4コーナー(4c)の2つに分割
  final double? moistureGoal;
  final double? moisture4c;

  FastestAgariStats({
    required this.agariInSeconds,
    required this.formattedAgari,
    required this.trackCondition,
    required this.raceName,
    required this.date,
    this.sourceRaceId,
    this.venueAndDistance,
    this.cushionValue,
    this.moistureGoal,
    this.moisture4c,
  });

  Map<String, dynamic> toMap() {
    return {
      'agariInSeconds': agariInSeconds,
      'formattedAgari': formattedAgari,
      'trackCondition': trackCondition,
      'raceName': raceName,
      'date': date,
      'sourceRaceId': sourceRaceId,
      'venueAndDistance': venueAndDistance,
      'cushionValue': cushionValue,
      'moistureGoal': moistureGoal,
      'moisture4c': moisture4c,
    };
  }

  factory FastestAgariStats.fromMap(Map<String, dynamic> map) {
    return FastestAgariStats(
      agariInSeconds: (map['agariInSeconds'] as num).toDouble(),
      formattedAgari: map['formattedAgari'] as String,
      trackCondition: map['trackCondition'] as String,
      raceName: map['raceName'] as String,
      date: map['date'] as String,
      sourceRaceId: map['sourceRaceId'] as String?,
      venueAndDistance: map['venueAndDistance'] as String?,
      cushionValue: (map['cushionValue'] as num?)?.toDouble(),
      moistureGoal: (map['moistureGoal'] as num?)?.toDouble(),
      moisture4c: (map['moisture4c'] as num?)?.toDouble(),
    );
  }

  FastestAgariStats copyWithTrackCondition({
    double? cushionValue,
    double? moistureGoal,
    double? moisture4c,
  }) {
    return FastestAgariStats(
      agariInSeconds: agariInSeconds,
      formattedAgari: formattedAgari,
      trackCondition: trackCondition,
      raceName: raceName,
      date: date,
      sourceRaceId: sourceRaceId,
      venueAndDistance: venueAndDistance,
      cushionValue: cushionValue ?? this.cushionValue,
      moistureGoal: moistureGoal ?? this.moistureGoal,
      moisture4c: moisture4c ?? this.moisture4c,
    );
  }
}