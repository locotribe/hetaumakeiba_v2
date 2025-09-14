// lib/logic/ai/condition_analyzer.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';

class ConditionAnalyzer {
  static ConditionFitResult analyzeConditionFit({
    required PredictionHorseDetail horse,
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
    RaceStatistics? raceStats,
  }) {
    final trackFit = _evaluateTrackFit(horse, raceData, pastRecords);
    final paceFit = _evaluatePaceFit(horse, raceData, pastRecords);
    final weightFit = _evaluateWeightFit(horse, raceData, pastRecords);
    final gateFit = _evaluateGateFit(horse, raceData, pastRecords, raceStats);

    return ConditionFitResult(
      trackFit: trackFit,
      paceFit: paceFit,
      weightFit: weightFit,
      gateFit: gateFit,
    );
  }

  static FitnessRating _evaluateTrackFit(PredictionHorseDetail horse,
      PredictionRaceData raceData, List<HorseRaceRecord> pastRecords) {
    // 1. 今回のレースの馬場状態を取得
    final raceInfo = raceData.raceDetails1 ?? '';
    final raceInfoParts = raceInfo.split('/');
    String currentCondition = '良'; // デフォルトは良馬場
    if (raceInfoParts.length > 2) {
      final conditionPart = raceInfoParts[2].trim();
      if (conditionPart.contains('稍重')) {
        currentCondition = '稍重';
      } else if (conditionPart.contains('重'))
        currentCondition = '重';
      else if (conditionPart.contains('不良')) currentCondition = '不良';
    }
    final isHeavyTrack = currentCondition != '良';

    // 2. 過去の道悪実績と良馬場実績を抽出
    final heavyTrackRaces = pastRecords
        .where((r) => ['稍重', '重', '不良'].contains(r.trackCondition))
        .toList();
    final goodTrackRaces =
    pastRecords.where((r) => r.trackCondition == '良').toList();

    // 3. 評価ロジック
    if (isHeavyTrack) {
      // 今回が道悪の場合
      if (heavyTrackRaces.isEmpty) return FitnessRating.unknown; // 道悪未経験
      final topThreeFinishes = heavyTrackRaces
          .where((r) => (int.tryParse(r.rank) ?? 99) <= 3)
          .length;
      final placeRate = topThreeFinishes / heavyTrackRaces.length;
      if (placeRate >= 0.5) return FitnessRating.excellent; // 道悪巧者
      if (placeRate > 0) return FitnessRating.good; // 道悪実績あり
      return FitnessRating.poor; // 道悪で好走歴なし
    } else {
      // 今回が良馬場の場合
      if (goodTrackRaces.isEmpty) return FitnessRating.unknown; // 良馬場未経験
      final topThreeFinishes = goodTrackRaces
          .where((r) => (int.tryParse(r.rank) ?? 99) <= 3)
          .length;
      final placeRate = topThreeFinishes / goodTrackRaces.length;
      if (placeRate >= 0.5) return FitnessRating.excellent;
      if (placeRate > 0) return FitnessRating.good;
      return FitnessRating.average; // 良馬場で好走歴がなくても平均評価
    }
  }

  static FitnessRating _evaluatePaceFit(PredictionHorseDetail horse,
      PredictionRaceData raceData, List<HorseRaceRecord> pastRecords) {
    final predictedPace =
        raceData.racePacePrediction?.predictedPace ?? 'ミドルペース';
    final horseStyle = RaceAnalyzer.getRunningStyle(pastRecords);

    if (horseStyle == '不明') return FitnessRating.unknown;

    switch (predictedPace) {
      case 'ハイペース':
        return (horseStyle == '差し' || horseStyle == '追込')
            ? FitnessRating.excellent
            : FitnessRating.poor;
      case 'スローペース':
        return (horseStyle == '逃げ' || horseStyle == '先行')
            ? FitnessRating.excellent
            : FitnessRating.poor;
      case 'ミドルペース':
      default:
        return FitnessRating.average;
    }
  }

  static FitnessRating _evaluateWeightFit(PredictionHorseDetail horse,
      PredictionRaceData raceData, List<HorseRaceRecord> pastRecords) {
    final goodPerformances =
    pastRecords.where((r) => (int.tryParse(r.rank) ?? 99) <= 3).toList();
    if (goodPerformances.isEmpty) return FitnessRating.unknown;

    double totalWeight = 0;
    for (final record in goodPerformances) {
      totalWeight += double.tryParse(record.carriedWeight) ?? 0;
    }
    final avgGoodWeight = totalWeight / goodPerformances.length;

    final difference = horse.carriedWeight - avgGoodWeight;

    if (difference <= -1.0) return FitnessRating.excellent; // 1kg以上の斤量減
    if (difference < 1.0) return FitnessRating.good; // ほぼ同斤量
    if (difference < 2.0) return FitnessRating.average; // 1kg台の斤量増
    return FitnessRating.poor; // 2kg以上の斤量増
  }

  static FitnessRating _evaluateGateFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      RaceStatistics? raceStats) {
    if (raceStats == null) return FitnessRating.unknown;

    try {
      final statsData =
      json.decode(raceStats.statisticsJson) as Map<String, dynamic>;
      final frameStats = statsData['frameStats'] as Map<String, dynamic>?;
      if (frameStats == null) return FitnessRating.unknown;

      // 全枠の平均複勝率を計算
      int totalHorses = 0;
      int totalShows = 0;
      frameStats.forEach((key, value) {
        totalHorses += (value['total'] as int? ?? 0);
        totalShows += (value['show'] as int? ?? 0);
      });
      if (totalHorses == 0) return FitnessRating.unknown;
      final avgShowRate = totalShows / totalHorses;

      // この馬の枠の複勝率を取得
      final gateNumberStr = horse.gateNumber.toString();
      if (!frameStats.containsKey(gateNumberStr)) return FitnessRating.unknown;

      final gateData = frameStats[gateNumberStr];
      final gateTotal = gateData['total'] as int? ?? 0;
      final gateShows = gateData['show'] as int? ?? 0;
      if (gateTotal == 0) return FitnessRating.unknown;
      final gateShowRate = gateShows / gateTotal;

      // 平均との差で評価
      if (gateShowRate > avgShowRate * 1.5)
        return FitnessRating.excellent; // 平均の1.5倍以上
      if (gateShowRate > avgShowRate * 1.1)
        return FitnessRating.good; // 平均の1.1倍以上
      if (gateShowRate < avgShowRate * 0.9)
        return FitnessRating.poor; // 平均の0.9倍未満
      return FitnessRating.average;
    } catch (e) {
      print('Error parsing gate fit stats: $e');
      return FitnessRating.unknown;
    }
  }
}