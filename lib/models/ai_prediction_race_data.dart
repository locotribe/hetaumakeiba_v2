// lib/models/ai_prediction_race_data.dart

import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/complex_aptitude_model.dart';
import 'package:hetaumakeiba_v2/models/best_time_stats_model.dart';
import 'package:hetaumakeiba_v2/models/fastest_agari_stats_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';

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
  final String jockeyId;
  final double carriedWeight;
  final String trainerName;
  final String trainerAffiliation;
  double? odds;
  int? popularity;
  String? horseWeight;
  UserMark? userMark;
  HorseMemo? userMemo;
  final bool isScratched;
  HorsePredictionScore? predictionScore;
  ConditionFitResult? conditionFit;
  ComplexAptitudeStats? distanceCourseAptitudeStats; // 距離・コース適性
  String? trackAptitudeLabel; // 馬場適性
  BestTimeStats? bestTimeStats;
  FastestAgariStats? fastestAgariStats;
  double? overallScore;
  double? expectedValue;
  LegStyleProfile? legStyleProfile;

  PredictionHorseDetail({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.sexAndAge,
    required this.jockey,
    required this.jockeyId,
    required this.carriedWeight,
    required this.trainerName,
    required this.trainerAffiliation,
    this.odds,
    this.popularity,
    this.horseWeight,
    this.userMark,
    this.userMemo,
    required this.isScratched,
    this.predictionScore,
    this.conditionFit,
    this.distanceCourseAptitudeStats,
    this.trackAptitudeLabel,
    this.bestTimeStats,
    this.fastestAgariStats,
    this.overallScore,
    this.expectedValue,
    this.legStyleProfile,
  });

  factory PredictionHorseDetail.fromShutubaHorseDetail(ShutubaHorseDetail detail) {
    return PredictionHorseDetail(
      horseId: detail.horseId,
      horseNumber: detail.horseNumber,
      gateNumber: detail.gateNumber,
      horseName: detail.horseName,
      sexAndAge: detail.sexAndAge,
      jockey: detail.jockey,
      jockeyId: detail.jockeyId,
      carriedWeight: detail.carriedWeight,
      trainerName: detail.trainerName,
      trainerAffiliation: detail.trainerAffiliation,
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
      'jockeyId': jockeyId,
      'carriedWeight': carriedWeight,
      'trainerName': trainerName,
      'trainerAffiliation': trainerAffiliation,
      'odds': odds,
      'popularity': popularity,
      'horseWeight': horseWeight,
      'isScratched': isScratched,
      'userMark': userMark?.toMap(),
      'userMemo': userMemo?.toMap(),
      'overallScore': overallScore,
      'expectedValue': expectedValue,
      'distanceCourseAptitudeStats': distanceCourseAptitudeStats?.toMap(),
      'trackAptitudeLabel': trackAptitudeLabel,
      'legStyleProfile': legStyleProfile?.toJson(),
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
      jockeyId: json['jockeyId'] as String? ?? '',
      carriedWeight: (json['carriedWeight'] as num).toDouble(),
      trainerName: json['trainerName'] as String,
      trainerAffiliation: json['trainerAffiliation'] as String,
      odds: (json['odds'] as num?)?.toDouble(),
      popularity: json['popularity'] as int?,
      horseWeight: json['horseWeight'] as String?,
      isScratched: json['isScratched'] as bool,
      userMark: json['userMark'] != null
          ? UserMark.fromMap(json['userMark'] as Map<String, dynamic>)
          : null,
      userMemo: json['userMemo'] != null
          ? HorseMemo.fromMap(json['userMemo'] as Map<String, dynamic>)
          : null,
      overallScore: (json['overallScore'] as num?)?.toDouble(),
      expectedValue: (json['expectedValue'] as num?)?.toDouble(),
      distanceCourseAptitudeStats: json['distanceCourseAptitudeStats'] != null
          ? ComplexAptitudeStats.fromMap(json['distanceCourseAptitudeStats'] as Map<String, dynamic>)
          : null,
      trackAptitudeLabel: json['trackAptitudeLabel'] as String?,
      legStyleProfile: json['legStyleProfile'] != null // <<< 新しく追加
          ? LegStyleProfile.fromJson(json['legStyleProfile'] as Map<String, dynamic>)
          : null,
    );
  }


}