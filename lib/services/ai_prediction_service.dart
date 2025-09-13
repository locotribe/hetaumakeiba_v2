// lib/services/ai_prediction_service.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/ai_prediction_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';

class AiPredictionScores {
  final Map<String, double> overallScores;
  final Map<String, double> expectedValues;
  final Map<String, String> legStyles;
  final Map<String, ConditionFitResult> conditionFits;
  final Map<String, double> earlySpeedScores;
  final Map<String, double> finishingKickScores;
  final Map<String, double> staminaScores;

  AiPredictionScores({
    required this.overallScores,
    required this.expectedValues,
    required this.legStyles,
    required this.conditionFits,
    required this.earlySpeedScores,
    required this.finishingKickScores,
    required this.staminaScores,
  });
}

class AiPredictionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<AiPredictionScores> calculatePredictionScores(
      PredictionRaceData raceData, String raceId) async {
    final prefs = await SharedPreferences.getInstance();
    final customWeights = {
      'legType': prefs.getInt('legTypeWeight_${raceId}') ?? prefs.getInt('legTypeWeight') ?? 20,
      'courseFit': prefs.getInt('courseFitWeight_${raceId}') ?? prefs.getInt('courseFitWeight') ?? 20,
      'trackCondition': prefs.getInt('trackConditionWeight_${raceId}') ?? prefs.getInt('trackConditionWeight') ?? 15,
      'humanFactor': prefs.getInt('humanFactorWeight_${raceId}') ?? prefs.getInt('humanFactorWeight') ?? 15,
      'condition': prefs.getInt('conditionWeight_${raceId}') ?? prefs.getInt('conditionWeight') ?? 10,
      'earlySpeed': prefs.getInt('earlySpeedWeight_${raceId}') ?? prefs.getInt('earlySpeedWeight') ?? 5,
      'finishingKick': prefs.getInt('finishingKickWeight_${raceId}') ?? prefs.getInt('finishingKickWeight') ?? 10,
      'stamina': prefs.getInt('staminaWeight_${raceId}') ?? prefs.getInt('staminaWeight') ?? 5,
    };

    final Map<String, double> scores = {};
    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    final Map<String, String> legStyles = {};
    final Map<String, ConditionFitResult> conditionFits = {};
    final Map<String, double> earlySpeedScores = {};
    final Map<String, double> finishingKickScores = {};
    final Map<String, double> staminaScores = {};
    RaceStatistics? raceStats;
    try {
      raceStats = await _dbHelper.getRaceStatistics(raceId);
    } catch (e) {
      print('レース統計データの取得に失敗しました (テーブル未作成の可能性があります): $e');
      raceStats = null;
    }

    for (var horse in raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;
      scores[horse.horseId] = AiPredictionAnalyzer.calculateOverallAptitudeScore(
        horse,
        raceData,
        pastRecords,
        customWeights: customWeights,
      );
      legStyles[horse.horseId] = AiPredictionAnalyzer.getRunningStyle(pastRecords);
      conditionFits[horse.horseId] = AiPredictionAnalyzer.analyzeConditionFit(
        horse: horse,
        raceData: raceData,
        pastRecords: pastRecords,
        raceStats: raceStats,
      );
      earlySpeedScores[horse.horseId] = AiPredictionAnalyzer.evaluateEarlySpeedFit(horse, raceData, pastRecords);
      finishingKickScores[horse.horseId] = AiPredictionAnalyzer.evaluateFinishingKickFit(horse, raceData, pastRecords);
      staminaScores[horse.horseId] = AiPredictionAnalyzer.evaluateStaminaFit(horse, raceData, pastRecords);
    }

    final double totalScore = scores.values.fold(0.0, (sum, score) => sum + score);
    final Map<String, double> expectedValues = {};
    for (var horse in raceData.horses) {
      final score = scores[horse.horseId] ?? 0.0;
      final odds = horse.odds ?? 0.0;
      expectedValues[horse.horseId] = AiPredictionAnalyzer.calculateExpectedValue(
        score,
        odds,
        totalScore,
      );
    }

    final List<AiPrediction> predictionsToSave = [];
    for (final horse in raceData.horses) {
      final details = {
        'legStyle': legStyles[horse.horseId],
        'earlySpeedScore': earlySpeedScores[horse.horseId],
        'finishingKickScore': finishingKickScores[horse.horseId],
        'staminaScore': staminaScores[horse.horseId],
      };

      predictionsToSave.add(AiPrediction(
        raceId: raceId,
        horseId: horse.horseId,
        overallScore: scores[horse.horseId] ?? 0.0,
        expectedValue: expectedValues[horse.horseId] ?? 0.0,
        predictionTimestamp: DateTime.now(),
        analysisDetailsJson: json.encode(details),
      ));
    }
    await _dbHelper.insertOrUpdateAiPredictions(predictionsToSave);

    return AiPredictionScores(
      overallScores: scores,
      expectedValues: expectedValues,
      legStyles: legStyles,
      conditionFits: conditionFits,
      earlySpeedScores: earlySpeedScores,
      finishingKickScores: finishingKickScores,
      staminaScores: staminaScores,
    );
  }
}