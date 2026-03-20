// lib/models/shutuba_table_cache_model.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/models/race_data.dart';

class ShutubaTableCache {
  final String raceId;
  final PredictionRaceData predictionRaceData;
  final DateTime lastUpdatedAt;

  ShutubaTableCache({
    required this.raceId,
    required this.predictionRaceData,
    required this.lastUpdatedAt,
  });

  factory ShutubaTableCache.fromMap(Map<String, dynamic> map) {
    return ShutubaTableCache(
      raceId: map['race_id'] as String,
      predictionRaceData: PredictionRaceData.fromJson(json.decode(map['shutuba_data_json'] as String)),
      lastUpdatedAt: DateTime.parse(map['last_updated'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'race_id': raceId,
      'shutuba_data_json': json.encode(predictionRaceData.toJson()),
      'last_updated': lastUpdatedAt.toIso8601String(),
    };
  }
}