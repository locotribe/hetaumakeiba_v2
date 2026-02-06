// lib/models/historical_match_model.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

class HistoricalMatchModel {
  final String horseId;
  final String horseName;

  // 総合評価
  final double totalScore;

  // (既存フィールド...)
  final double weightScore;
  final double? usedWeight;
  final double weightDiff;
  final bool isWeightCurrent;
  final String weightStr;

  final double frameScore;
  final int gateNumber;
  final int totalHorses;
  final double relativePos;
  final String positionZone;

  // --- 人気妙味データ (大幅アップデート) ---
  final double popularityScore;    // 妙味スコア (0-100)
  final double valueIndex;         // 累積妙味指数 (生データ: +15.5, -8.0など)
  final String popDiagnosis;       // 診断 (例: "お宝馬", "過剰人気")
  final String valueReasoning;     // 根拠の自然言語解説 (新規)
  final String currentPopStr;      // 今回人気
  final String prevPopStr;         // 前走人気

  final double rotationScore;
  final String prevRaceName;
  final String rotDiagnosis;

  final List<HorseRaceRecord> recentHistory;

  HistoricalMatchModel({
    required this.horseId,
    required this.horseName,
    required this.totalScore,
    required this.weightScore,
    this.usedWeight,
    required this.weightDiff,
    required this.isWeightCurrent,
    required this.weightStr,
    required this.frameScore,
    required this.gateNumber,
    required this.totalHorses,
    required this.relativePos,
    required this.positionZone,
    required this.popularityScore,
    required this.valueIndex,     // 追加
    required this.popDiagnosis,
    required this.valueReasoning, // 追加
    required this.currentPopStr,
    required this.prevPopStr,
    required this.rotationScore,
    required this.prevRaceName,
    required this.rotDiagnosis,
    required this.recentHistory,
  });
}

class TrendSummary {
  final double medianWeight;
  final String bestZone;
  final String bestRotation;
  final String bestPrevPop;

  TrendSummary({
    required this.medianWeight,
    required this.bestZone,
    required this.bestRotation,
    required this.bestPrevPop,
  });
}