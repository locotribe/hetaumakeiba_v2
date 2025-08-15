// lib/logic/prediction_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart'; // 新しく追加
import 'dart:math'; // 乱数生成のために追加

class PredictionAnalyzer {
  // --- 既存の簡易スコア算出ロジックは計画書通り完全に破棄 ---

  // #################################################
  // ## フェーズ2.2: 「的中重視」ロジック
  // #################################################

  /// 様々なファクターを総合評価し、0〜100点の「総合適性スコア」を算出します。
  /// このメソッドが、各ファクター評価メソッドを呼び出す司令塔となります。
  static double calculateOverallAptitudeScore(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    // 各ファクターのスコアを0-100点で算出
    final legTypeScore = _evaluateLegTypeAndPaceFit(horse, raceData, pastRecords); // 1. 脚質・展開適性
    final courseFitScore = _evaluateCourseFit(horse, raceData); // 2. コース適性
    final trackConditionScore = _evaluateTrackConditionFit(horse, raceData, pastRecords); // 3. 馬場適性
    final humanFactorScore = _evaluateHumanFactors(horse); // 4. 人的要因
    final conditionScore = _evaluateCondition(horse); // 5. コンディション

    // 各ファクターの重要度に応じて重み付けを行う (例)
    final weights = {
      'legType': 0.30,
      'courseFit': 0.25,
      'trackCondition': 0.20,
      'humanFactor': 0.15,
      'condition': 0.10,
    };

    // 重み付け加算して総合スコアを算出
    final totalScore = (legTypeScore * weights['legType']!) +
        (courseFitScore * weights['courseFit']!) +
        (trackConditionScore * weights['trackCondition']!) +
        (humanFactorScore * weights['humanFactor']!) +
        (conditionScore * weights['condition']!);

    return totalScore.clamp(0, 100); // 最終スコアを0-100の範囲に収める
  }

  // 1. 脚質・展開適性評価
  static double _evaluateLegTypeAndPaceFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    // 擬似的なロジック: 本来はRaceDataParser等で精密な分析が必要
    if (raceData.racePacePrediction?.predictedPace == "ハイペース") {
      // ハイペースなら差し・追込が有利と仮定
      return horse.horseNumber % 2 == 0 ? 85.0 : 60.0;
    } else {
      // それ以外なら先行が有利と仮定
      return horse.horseNumber % 2 != 0 ? 85.0 : 60.0;
    }
  }

  // 2. コース適性評価
  static double _evaluateCourseFit(PredictionHorseDetail horse, PredictionRaceData raceData) {
    // 擬似的なロジック: 枠番が内側ほど有利と仮定
    return max(0.0, 100.0 - (horse.gateNumber * 5));
  }

  // 3. 馬場適性評価
  static double _evaluateTrackConditionFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    // 擬似的なロジック: ダートならパワーがありそうな馬名、そうでなければランダム
    if (raceData.raceDetails1?.contains('ダ') ?? false) {
      return horse.horseName.contains('パワー') ? 95.0 : 70.0;
    }
    return 60.0 + Random().nextDouble() * 30.0;
  }

  // 4. 人的要因評価
  static double _evaluateHumanFactors(PredictionHorseDetail horse) {
    // 擬似的なロジック: 特定の騎手なら高評価
    if (horse.jockey.contains('ルメール') || horse.jockey.contains('川田')) {
      return 98.0;
    }
    return 75.0;
  }

  // 5. コンディション評価
  static double _evaluateCondition(PredictionHorseDetail horse) {
    // 擬似的なロジック: 馬体重が変動していないほど良いと仮定
    final weightChangeMatch = RegExp(r'\(([\+\-]\d+)\)').firstMatch(horse.horseWeight ?? "");
    if (weightChangeMatch != null) {
      final change = int.tryParse(weightChangeMatch.group(1)!) ?? 0;
      return max(0.0, 100.0 - (change.abs() * 10));
    }
    return 80.0; // 馬体重不明の場合
  }


  // #################################################
  // ## フェーズ2.2: 「回収率重視」ロジック
  // #################################################

  /// 全出走馬のスコアとオッズから「期待値」を算出します。
  static double calculateExpectedValue(double overallScore, double odds, double totalScoreOfAllHorses) {
    if (totalScoreOfAllHorses == 0 || odds == 0) {
      return -1.0; // 計算不能の場合は-1を返す
    }

    // 1. 総合適性スコアを正規化し、アプリ独自の「真の勝率」を算出
    final trueWinRate = overallScore / totalScoreOfAllHorses;

    // 2. 期待値を算出
    // (真の勝率 × 単勝オッズ) - 1
    final expectedValue = (trueWinRate * odds) - 1.0;

    return expectedValue;
  }

  // 既存の predictRacePace は変更しない
  // 内部ヘルパー：脚質を判定する
  static String _getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) return "不明";

    int frontRunnerCount = 0;
    final recentRaces = records.take(3); // 直近3走で判断

    for(var record in recentRaces) {
      final positions = record.cornerPassage.split('-').map((p) => int.tryParse(p) ?? 99).toList();
      if (positions.isNotEmpty) {
        // 第2コーナー(インデックス1)までの順位が馬群の1/4以内なら先行タイプと判定
        final horseCount = int.tryParse(record.numberOfHorses) ?? 12;
        if (positions.first <= (horseCount / 4)) {
          frontRunnerCount++;
        }
      }
    }
    // 3走中2走以上で先行していれば「逃げ・先行」と判断
    if (frontRunnerCount >= 2) return "逃げ・先行";
    return "差し・追込";
  }

  // レースに出走する全馬のデータを受け取り、レース全体の展開を予測して返すメソッド
  static RacePacePrediction predictRacePace(List<PredictionHorseDetail> horses, Map<String, List<HorseRaceRecord>> allPastRecords) {
    int frontRunnerCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = _getRunningStyle(records);
      if (style == "逃げ・先行") {
        frontRunnerCount++;
      }
    }

    String predictedPace;
    String advantageousStyle;

    // 逃げ・先行タイプの馬の数に応じてペースを予測
    if (frontRunnerCount >= (horses.length / 3)) {
      predictedPace = "ハイペース";
      advantageousStyle = "差し・追込有利";
    } else if (frontRunnerCount <= 1) {
      predictedPace = "スローペース";
      advantageousStyle = "逃げ・先行有利";
    } else {
      predictedPace = "ミドルペース";
      advantageousStyle = "展開次第";
    }

    return RacePacePrediction(
      predictedPace: predictedPace,
      advantageousStyle: advantageousStyle,
    );
  }
}