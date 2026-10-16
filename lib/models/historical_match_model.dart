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
  // [追加] 総合シンクロ率と血統クロス Step2: 前走の路線の表示名（過去分析のローテの表と同じ。'BBBS（芝1600）' の形。前走が分からなければ '-'） (v.2026.10.16+26101615)
  final String rotationRouteLabel;

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
    required this.rotationRouteLabel,
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
  // [削除] 総合シンクロ率と血統クロス Step2: 好走血統（bestSire）は画面で使っていないので削除した (v.2026.10.16+26101615)
  final double avgCushion; // ★追加

  TrendSummary({
    required this.medianWeight,
    required this.bestZone,
    required this.bestRotation,
    required this.bestPrevPop,
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

// [修正] 総合シンクロ率と血統クロス Step4: 血統クロスは、過去の全出走馬（取消・除外を除く）を父ごとに数えた着度数にした。
// 3着以内の回数（PedigreeCount）と全体傾向の父・母父の一覧（overallSires・overallBms）は削除した (v.2026.10.16+26101617)
/// 父1頭分の着度数。
class PedigreeRecordCount {
  /// 父の名前
  final String name;

  /// 過去の出走（延べ頭数）
  final int total;

  /// 1着の数
  final int win;

  /// 1〜2着の数
  final int place;

  /// 1〜3着の数
  final int show;

  const PedigreeRecordCount({
    required this.name,
    required this.total,
    required this.win,
    required this.place,
    required this.show,
  });

  /// 着度数（1着-2着-3着-着外）
  String get recordText =>
      '$win-${place - win}-${show - place}-${total - show}';
}

class CrossAnalysisResult {
  final List<PedigreeRecordCount> highCushionSires;
  final List<PedigreeRecordCount> standardCushionSires;
  final List<PedigreeRecordCount> lowCushionSires;

  final List<PedigreeRecordCount> highMoistureSires;
  final List<PedigreeRecordCount> lowMoistureSires;

  /// 数えた過去の出走（父が分かる馬。延べ頭数）
  final int countedStarts;

  /// 血統が無く数えなかった過去の出走（延べ頭数）
  final int missingStarts;

  /// クッション値が無く、クッション値別に入らなかったレースの数
  final int racesWithoutCushion;

  /// 含水率が無く、含水率別に入らなかったレースの数
  final int racesWithoutMoisture;

  CrossAnalysisResult({
    required this.highCushionSires,
    required this.standardCushionSires,
    required this.lowCushionSires,
    required this.highMoistureSires,
    required this.lowMoistureSires,
    required this.countedStarts,
    required this.missingStarts,
    required this.racesWithoutCushion,
    required this.racesWithoutMoisture,
  });
}