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
}