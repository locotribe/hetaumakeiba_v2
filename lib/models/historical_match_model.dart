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

  // --- 人気妙味データ ---
  final double popularityScore;
  final double valueIndex;
  final String popDiagnosis;
  final String valueReasoning;
  final String currentPopStr;
  final String prevPopStr;

  final double rotationScore;
  final String prevRaceName;
  final String rotDiagnosis;

  // ★新規追加: 血統ファクターデータ
  final double pedigreeScore;
  final String pedigreeDiag;

  // ★新規追加: 馬場シナリオ別スコア (High, Standard, Low)
  final Map<String, double> trackConditionScores;
  // ★新規追加: シナリオ別の最終総合スコア
  final Map<String, double> scenarioTotalScores;

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
    required this.valueIndex,
    required this.popDiagnosis,
    required this.valueReasoning,
    required this.currentPopStr,
    required this.prevPopStr,
    required this.rotationScore,
    required this.prevRaceName,
    required this.rotDiagnosis,
    required this.pedigreeScore, // ★追加
    required this.pedigreeDiag,  // ★追加
    required this.trackConditionScores, // ★追加
    required this.scenarioTotalScores,  // ★追加
    required this.recentHistory,
  });
}

class TrendSummary {
  final double medianWeight;
  final String bestZone;
  final String bestRotation;
  final String bestPrevPop;
  final String bestSire; // ★追加
  final double avgCushion; // ★追加

  TrendSummary({
    required this.medianWeight,
    required this.bestZone,
    required this.bestRotation,
    required this.bestPrevPop,
    this.bestSire = '-', // ★追加
    this.avgCushion = 0.0, // ★追加
  });
}

class TrackConditionTrendResult {
  final double avgCushion;
  final double maxCushion;
  final double minCushion;
  final double avgTurfMoisture;
  final double avgDirtMoisture;

  TrackConditionTrendResult({
    required this.avgCushion,
    required this.maxCushion,
    required this.minCushion,
    required this.avgTurfMoisture,
    required this.avgDirtMoisture,
  });
}

class PedigreeCount {
  final String name;
  int count;
  PedigreeCount(this.name, this.count);
}

class CrossAnalysisResult {
  final List<PedigreeCount> overallSires;
  final List<PedigreeCount> overallBms;

  final List<PedigreeCount> highCushionSires;
  final List<PedigreeCount> standardCushionSires;
  final List<PedigreeCount> lowCushionSires;

  final List<PedigreeCount> highMoistureSires;
  final List<PedigreeCount> lowMoistureSires;

  CrossAnalysisResult({
    required this.overallSires,
    required this.overallBms,
    required this.highCushionSires,
    required this.standardCushionSires,
    required this.lowCushionSires,
    required this.highMoistureSires,
    required this.lowMoistureSires,
  });
}