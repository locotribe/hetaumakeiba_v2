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
  // [追加] 馬柱の上り列に、その上がりを出した過去走の枠番・着順・人気を表示するための項目 (v.2026.9.24+26092402)
  final int? frameNumber; // その走の枠番
  final int? finishRank; // その走の着順
  final int? popularity; // その走の人気

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
    // [追加] 枠番・着順・人気 (v.2026.9.24+26092402)
    this.frameNumber,
    this.finishRank,
    this.popularity,
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
      // [追加] 枠番・着順・人気 (v.2026.9.24+26092402)
      'frameNumber': frameNumber,
      'finishRank': finishRank,
      'popularity': popularity,
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
      // [追加] 旧キャッシュにキーが無い場合は null（後方互換） (v.2026.9.24+26092402)
      frameNumber: (map['frameNumber'] as num?)?.toInt(),
      finishRank: (map['finishRank'] as num?)?.toInt(),
      popularity: (map['popularity'] as num?)?.toInt(),
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
      // [追加] 枠番・着順・人気は元の値を維持する (v.2026.9.24+26092402)
      frameNumber: frameNumber,
      finishRank: finishRank,
      popularity: popularity,
    );
  }
}
