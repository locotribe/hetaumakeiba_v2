// lib/logic/prediction_analyzer.dart
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'dart:math';

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

  /// 各馬の脚質と枠順を元に、各コーナーの展開を予測（シミュレーション）します。
  static Map<String, String> simulateRaceDevelopment(
      List<PredictionHorseDetail> horses,
      Map<String, String> legStyles,
      ) {
    final Map<String, List<PredictionHorseDetail>> groupedByLegStyle = {
      '逃げ': [], '先行': [], '差し': [], '追込': [], '不明': [],
    };

    for (final horse in horses) {
      final style = legStyles[horse.horseId] ?? '不明';
      groupedByLegStyle[style]?.add(horse);
    }

    // 各脚質グループ内で枠番順（内枠が先）にソート
    groupedByLegStyle.forEach((style, horseList) {
      horseList.sort((a, b) => a.gateNumber.compareTo(b.gateNumber));
    });

    // 1-2コーナーの予測 (脚質 > 枠番)
    final initialOrder = [
      ...groupedByLegStyle['逃げ']!,
      ...groupedByLegStyle['先行']!,
      ...groupedByLegStyle['差し']!,
      ...groupedByLegStyle['追込']!,
      ...groupedByLegStyle['不明']!,
    ];
    final corner1_2 = initialOrder.map((h) => h.horseNumber).join('-');

    // 4コーナーの予測 (簡易シミュレーション)
    // 差し・追込馬が少し前に、逃げ・先行馬が少し後ろになるように調整
    final finalOrder = List<PredictionHorseDetail>.from(initialOrder);
    // 簡単な入れ替えロジック
    if (finalOrder.length > 5) {
      final sashiHorse = finalOrder.firstWhere((h) => (legStyles[h.horseId] ?? '') == '差し', orElse: () => finalOrder.last);
      final senkoHorse = finalOrder.firstWhere((h) => (legStyles[h.horseId] ?? '') == '先行', orElse: () => finalOrder.first);
      final sashiIndex = finalOrder.indexOf(sashiHorse);
      final senkoIndex = finalOrder.indexOf(senkoHorse);

      if (sashiIndex > senkoIndex) {
        // 差し馬を先行馬の少し前に移動させる
        final temp = finalOrder.removeAt(sashiIndex);
        finalOrder.insert(max(0, senkoIndex + 1), temp);
      }
    }
    final corner4 = finalOrder.map((h) => h.horseNumber).join('-');

    return {
      '1-2コーナー': corner1_2,
      '3コーナー': corner1_2, // 3コーナーは1-2コーナーと同じと仮定
      '4コーナー': corner4,
    };
  }

  // 既存の predictRacePace は変更しない
  // 内部ヘルパー：脚質を判定する
  static String getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) return "不明";

    List<double> avgPositionRates = [];
    final recentRaces = records.where((r) => !r.cornerPassage.contains('(') && r.cornerPassage.contains('-')).take(5);

    if (recentRaces.isEmpty) return "不明";

    for (var record in recentRaces) {
      final horseCount = int.tryParse(record.numberOfHorses);
      final positions = record.cornerPassage.split('-').map((p) => int.tryParse(p) ?? -1).where((p) => p != -1).toList();

      if (horseCount == null || horseCount == 0 || positions.length < 2) continue;

      // 2コーナーまたはそれに相当する位置の通過順位率を計算
      final positionRate = positions[1] / horseCount;
      avgPositionRates.add(positionRate);
    }

    if (avgPositionRates.isEmpty) return "不明";

    final avgRate = avgPositionRates.reduce((a, b) => a + b) / avgPositionRates.length;

    if (avgRate <= 0.15) return "逃げ";
    if (avgRate <= 0.40) return "先行";
    if (avgRate <= 0.80) return "差し";
    return "追込";
  }

  // レースに出走する全馬のデータを受け取り、レース全体の展開を予測して返すメソッド
  static RacePacePrediction predictRacePace(List<PredictionHorseDetail> horses, Map<String, List<HorseRaceRecord>> allPastRecords) {
    int frontRunnerCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = getRunningStyle(records);
      if (style == "逃げ・先行" || style == "逃げ") { // "逃げ"も先行力にカウント
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