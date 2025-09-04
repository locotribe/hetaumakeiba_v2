// lib/models/prediction_race_data.dart

import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';

/// レース全体の予想データを保持するコンテナです。
class PredictionRaceData {
  final String raceId;
  final String raceName;
  final String raceDate;
  final String venue;
  final String raceNumber;
  final String shutubaTableUrl;
  final String raceGrade;
  final String? raceDetails1;
  final List<PredictionHorseDetail> horses;
  RacePacePrediction? racePacePrediction;

  PredictionRaceData({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.venue,
    required this.raceNumber,
    required this.shutubaTableUrl,
    required this.raceGrade,
    this.raceDetails1,
    required this.horses,
    this.racePacePrediction,
  });

  Map<String, dynamic> toJson() {
    return {
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
  }

  factory PredictionRaceData.fromJson(Map<String, dynamic> json) {
    return PredictionRaceData(
      raceId: json['raceId'] as String,
      raceName: json['raceName'] as String,
      raceDate: json['raceDate'] as String,
      venue: json['venue'] as String,
      raceNumber: json['raceNumber'] as String,
      shutubaTableUrl: json['shutubaTableUrl'] as String,
      raceGrade: json['raceGrade'] as String,
      raceDetails1: json['raceDetails1'] as String?,
      horses: (json['horses'] as List<dynamic>)
          .map((e) => PredictionHorseDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 各出走馬の予想に必要な詳細情報（特に動的な情報）を保持します。
class PredictionHorseDetail {
  final String horseId;
  final int horseNumber;
  final int gateNumber;
  final String horseName;
  final String sexAndAge;
  final String jockey;
  final double carriedWeight;
  final String trainer;
  double? odds;
  int? popularity;
  String? horseWeight;
  UserMark? userMark;
  HorseMemo? userMemo;
  final bool isScratched;
  HorsePredictionScore? predictionScore;
  ConditionFitResult? conditionFit;

  PredictionHorseDetail({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.sexAndAge,
    required this.jockey,
    required this.carriedWeight,
    required this.trainer,
    this.odds,
    this.popularity,
    this.horseWeight,
    this.userMark,
    this.userMemo,
    required this.isScratched,
    this.predictionScore,
    this.conditionFit,
  });

  factory PredictionHorseDetail.fromShutubaHorseDetail(ShutubaHorseDetail detail) {
    return PredictionHorseDetail(
      horseId: detail.horseId,
      horseNumber: detail.horseNumber,
      gateNumber: detail.gateNumber,
      horseName: detail.horseName,
      sexAndAge: detail.sexAndAge,
      jockey: detail.jockey,
      carriedWeight: detail.carriedWeight,
      trainer: detail.trainer,
      horseWeight: detail.horseWeight,
      odds: detail.odds,
      popularity: detail.popularity,
      isScratched: detail.isScratched,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'horseId': horseId,
      'horseNumber': horseNumber,
      'gateNumber': gateNumber,
      'horseName': horseName,
      'sexAndAge': sexAndAge,
      'jockey': jockey,
      'carriedWeight': carriedWeight,
      'trainer': trainer,
      'odds': odds,
      'popularity': popularity,
      'horseWeight': horseWeight,
      'isScratched': isScratched,
    };
  }

  factory PredictionHorseDetail.fromJson(Map<String, dynamic> json) {
    return PredictionHorseDetail(
      horseId: json['horseId'] as String,
      horseNumber: json['horseNumber'] as int,
      gateNumber: json['gateNumber'] as int,
      horseName: json['horseName'] as String,
      sexAndAge: json['sexAndAge'] as String,
      jockey: json['jockey'] as String,
      carriedWeight: (json['carriedWeight'] as num).toDouble(),
      trainer: json['trainer'] as String,
      odds: (json['odds'] as num?)?.toDouble(),
      popularity: json['popularity'] as int?,
      horseWeight: json['horseWeight'] as String?,
      isScratched: json['isScratched'] as bool,
    );
  }
}