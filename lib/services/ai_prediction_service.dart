// lib/services/ai_prediction_service.dart
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/ai_prediction_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';

// 計算結果をまとめて返すためのデータクラス
class AiPredictionScores {
  final Map<String, double> overallScores;
  final Map<String, double> expectedValues;
  final Map<String, String> legStyles;
  final Map<String, ConditionFitResult> conditionFits;

  AiPredictionScores({
    required this.overallScores,
    required this.expectedValues,
    required this.legStyles,
    required this.conditionFits,
  });
}

class AiPredictionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<AiPredictionScores> calculatePredictionScores(
      PredictionRaceData raceData, String raceId) async {
    final prefs = await SharedPreferences.getInstance();
    // getDoubleをgetIntに変更し、型をMap<String, int>にする
    final customWeights = {
      'legType': prefs.getInt('legTypeWeight') ?? 20,
      'courseFit': prefs.getInt('courseFitWeight') ?? 20,
      'trackCondition': prefs.getInt('trackConditionWeight') ?? 15,
      'humanFactor': prefs.getInt('humanFactorWeight') ?? 15,
      'condition': prefs.getInt('conditionWeight') ?? 10,
      'earlySpeed': prefs.getInt('earlySpeedWeight') ?? 5,
      'finishingKick': prefs.getInt('finishingKickWeight') ?? 10,
      'stamina': prefs.getInt('staminaWeight') ?? 5,
    };

    final Map<String, double> scores = {};
    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    final Map<String, String> legStyles = {};
    final Map<String, ConditionFitResult> conditionFits = {};
    RaceStatistics? raceStats;
    try {
      // 統計データの取得を試みる
      raceStats = await _dbHelper.getRaceStatistics(raceId);
    } catch (e) {
      // テーブルが存在しない等のエラーが発生しても処理を続行する
      print('レース統計データの取得に失敗しました (テーブル未作成の可能性があります): $e');
      raceStats = null; // エラー時はnullとして扱う
    }
    // まず全馬の過去成績を取得し、総合適性スコアと脚質を計算
    for (var horse in raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;
      scores[horse.horseId] = AiPredictionAnalyzer.calculateOverallAptitudeScore(
        horse,
        raceData,
        pastRecords,
        customWeights: customWeights,
      );
      // ▼▼▼ ここからが修正箇所 ▼▼▼
      legStyles[horse.horseId] = AiPredictionAnalyzer.getRunningStyle(pastRecords);
      conditionFits[horse.horseId] = AiPredictionAnalyzer.analyzeConditionFit(
        horse: horse,
        raceData: raceData,
        pastRecords: pastRecords,
        raceStats: raceStats,
      );
      // ▲▲▲ ここまでが修正箇所 ▲▲▲
    }

    // 全馬のスコア合計を算出
    final double totalScore = scores.values.fold(0.0, (sum, score) => sum + score);

    final Map<String, double> expectedValues = {};
    // 各馬の期待値を計算
    for (var horse in raceData.horses) {
      final score = scores[horse.horseId] ?? 0.0;
      final odds = horse.odds ?? 0.0;
      // ▼▼▼ ここからが修正箇所 ▼▼▼
      expectedValues[horse.horseId] = AiPredictionAnalyzer.calculateExpectedValue(
        score,
        odds,
        totalScore,
      );
      // ▲▲▲ ここまでが修正箇所 ▲▲▲
    }

    // 計算結果をデータベースに保存
    final List<AiPrediction> predictionsToSave = [];
    for (final horse in raceData.horses) {
      predictionsToSave.add(AiPrediction(
        raceId: raceId,
        horseId: horse.horseId,
        overallScore: scores[horse.horseId] ?? 0.0,
        expectedValue: expectedValues[horse.horseId] ?? 0.0,
        predictionTimestamp: DateTime.now(),
      ));
    }
    await _dbHelper.insertOrUpdateAiPredictions(predictionsToSave);

    return AiPredictionScores(
      overallScores: scores,
      expectedValues: expectedValues,
      legStyles: legStyles,
      conditionFits: conditionFits,
    );
  }
}