// lib/models/shutuba_table_cache_model.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

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

// PredictionRaceData と PredictionHorseDetail に toJson/fromJson を追加する必要があります
// lib/models/prediction_race_data.dart に追記

// PredictionRaceData class
extension PredictionRaceDataJson on PredictionRaceData {
  Map<String, dynamic> toJson() => {
    'raceId': raceId,
    'raceName': raceName,
    'raceDate': raceDate,
    'venue': venue,
    'raceNumber': raceNumber,
    'shutubaTableUrl': shutubaTableUrl,
    'raceGrade': raceGrade,
    'raceDetails1': raceDetails1,
    'horses': horses.map((h) => h.toJson()).toList(),
  };

  static PredictionRaceData fromJson(Map<String, dynamic> json) => PredictionRaceData(
    raceId: json['raceId'],
    raceName: json['raceName'],
    raceDate: json['raceDate'],
    venue: json['venue'],
    raceNumber: json['raceNumber'],
    shutubaTableUrl: json['shutubaTableUrl'],
    raceGrade: json['raceGrade'],
    raceDetails1: json['raceDetails1'],
    horses: (json['horses'] as List).map((h) => PredictionHorseDetail.fromJson(h)).toList(),
  );
}

// PredictionHorseDetail class
extension PredictionHorseDetailJson on PredictionHorseDetail {
  Map<String, dynamic> toJson() => {
    'horseId': horseId,
    'horseNumber': horseNumber,
    'gateNumber': gateNumber,
    'horseName': horseName,
    'sexAndAge': sexAndAge,
    'jockey': jockey,
    'carriedWeight': carriedWeight,
    'trainerName': trainerName,
    'trainerAffiliation': trainerAffiliation,
    'odds': odds,
    'popularity': popularity,
    'horseWeight': horseWeight,
    'isScratched': isScratched,
  };

  static PredictionHorseDetail fromJson(Map<String, dynamic> json) => PredictionHorseDetail(
    horseId: json['horseId'],
    horseNumber: json['horseNumber'],
    gateNumber: json['gateNumber'],
    horseName: json['horseName'],
    sexAndAge: json['sexAndAge'],
    jockey: json['jockey'],
    jockeyId: json['jockeyId'] ?? '',
    carriedWeight: json['carriedWeight'],
    trainerName: json['trainerName'],
    trainerAffiliation: json['trainerAffiliation'],
    odds: json['odds'],
    popularity: json['popularity'],
    horseWeight: json['horseWeight'],
    isScratched: json['isScratched'],
  );
}