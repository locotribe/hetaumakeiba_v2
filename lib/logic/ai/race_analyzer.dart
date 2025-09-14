// lib/logic/ai/race_analyzer.dart

import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/ai/aptitude_analyzer.dart';

// シミュレーション中の馬の状態を管理するための内部ヘルパークラス
class _SimHorse {
  final PredictionHorseDetail detail;
  double positionScore; // 数値が小さいほど前
  final double staminaScore;
  final double finishingKickScore;

  _SimHorse({
    required this.detail,
    required this.positionScore,
    required this.staminaScore,
    required this.finishingKickScore,
  });
}

class RaceAnalyzer {
  // レースに出走する全馬のデータを受け取り、レース全体の展開を予測して返すメソッド
  static RacePacePrediction predictRacePace(
      List<PredictionHorseDetail> horses,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<RaceResult> pastRaceResults, // 過去10年間のレース結果を追加
      ) {
    // 1. レースの基本特性（過去10年）を分析
    final paceCounts = <String, int>{'ハイ': 0, 'ミドル': 0, 'スロー': 0};
    if (pastRaceResults.isNotEmpty) {
      for (final result in pastRaceResults) {
        final pace = RaceDataParser.calculatePaceFromRaceResult(result);
        paceCounts[pace] = (paceCounts[pace] ?? 0) + 1;
      }
    }

    // 2. メンバー特性（今回の出走馬）を分析
    int nigeCount = 0;
    int senkoCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = getRunningStyle(records);
      if (style == "逃げ") nigeCount++;
      if (style == "先行") senkoCount++;
    }
    final frontRunners = nigeCount + senkoCount;

    // 3. 予測ロジック
    String finalPrediction;
    final totalPastRaces = pastRaceResults.length;

    // 過去傾向が極端な場合 (7割以上)
    if (totalPastRaces > 0) {
      if (paceCounts['ハイ']! / totalPastRaces >= 0.7) {
        finalPrediction = 'ハイペース';
      } else if (paceCounts['スロー']! / totalPastRaces >= 0.7) {
        finalPrediction = 'スローペース';
      }
    }

    // メンバー構成から予測を微調整
    if (frontRunners >= (horses.length / 2)) {
      finalPrediction =
      paceCounts['ハイ']! > paceCounts['スロー']! ? 'ハイペース' : 'ミドルからハイ';
    } else if (nigeCount == 0 && frontRunners <= 2) {
      finalPrediction =
      paceCounts['スロー']! > paceCounts['ハイ']! ? 'スローペース' : 'スローからミドル';
    } else {
      finalPrediction = 'ミドルペース';
    }

    // 最終的な5段階評価に決定
    if (nigeCount >= 2 && frontRunners > (horses.length * 0.4)) {
      finalPrediction = 'ハイペース';
    } else if (nigeCount == 1 && frontRunners > (horses.length * 0.4)) {
      finalPrediction = 'ミドルからハイ';
    } else if (nigeCount == 0 && frontRunners <= 1) {
      finalPrediction = 'スローペース';
    } else if (nigeCount == 0 && frontRunners <= 3) {
      finalPrediction = 'スローからミドル';
    } else {
      finalPrediction = 'ミドルペース';
    }

    // advantageousStyle を削除
    return RacePacePrediction(predictedPace: finalPrediction);
  }

  // 内部ヘルパー：脚質を判定する
  static String getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) return "自在";

    List<double> avgPositionRates = [];
    final recentRaces = records
        .where((r) => !r.cornerPassage.contains('(') && r.cornerPassage.contains('-'))
        .take(5);

    if (recentRaces.isEmpty) return "自在";

    for (var record in recentRaces) {
      final horseCount = int.tryParse(record.numberOfHorses);
      final positions = record.cornerPassage
          .split('-')
          .map((p) => int.tryParse(p) ?? -1)
          .where((p) => p != -1)
          .toList();

      if (horseCount == null || horseCount == 0 || positions.length < 2)
        continue;

      // 2コーナーまたはそれに相当する位置の通過順位率を計算
      final positionRate = positions[1] / horseCount;
      avgPositionRates.add(positionRate);
    }

    if (avgPositionRates.isEmpty) return "自在";

    final avgRate =
        avgPositionRates.reduce((a, b) => a + b) / avgPositionRates.length;

    if (avgRate <= 0.15) return "逃げ";
    if (avgRate <= 0.40) return "先行";
    if (avgRate <= 0.80) return "差し";
    return "追込";
  }

  /// 各馬の脚質と枠順を元に、各コーナーの展開を予測（シミュレーション）します。
  static Map<String, String> simulateRaceDevelopment(
      PredictionRaceData raceData,
      Map<String, String> legStyles,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<String> cornersToPredict,
      ) {
    // 1. 全出走馬の能力スコアを算出
    final simHorses = raceData.horses.map((horse) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];
      final style = legStyles[horse.horseId] ?? '不明';
      double initialPositionScore;
      switch (style) {
        case '逃げ':
          initialPositionScore = 1.0;
          break;
        case '先行':
          initialPositionScore = 2.0;
          break;
        case '差し':
          initialPositionScore = 3.0;
          break;
        case '追込':
          initialPositionScore = 4.0;
          break;
        default:
          initialPositionScore = 2.5;
      }
      // 内枠ほど前に出やすいと仮定し、スコアを微調整
      initialPositionScore -= (horse.gateNumber * 0.05);

      return _SimHorse(
        detail: horse,
        positionScore: initialPositionScore,
        staminaScore:
        AptitudeAnalyzer.evaluateStaminaFit(horse, raceData, pastRecords),
        finishingKickScore: AptitudeAnalyzer.evaluateFinishingKickFit(
            horse, raceData, pastRecords),
      );
    }).toList();

    final development = <String, String>{};

    // 2. 1-2コーナー（初期位置）の予測
    simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
    if (cornersToPredict.contains('1-2コーナー')) {
      development['1-2コーナー'] = _formatTairetsu(simHorses);
    }

    // 3. 3コーナーの予測 (スタミナの影響)
    if (cornersToPredict.contains('3コーナー')) {
      for (final horse in simHorses) {
        // スタミナが低い先行馬は少し後退
        if (horse.positionScore < 2.5 && horse.staminaScore < 75.0) {
          horse.positionScore += 0.2;
        }
        // スタミナがある差し馬は少し前進
        if (horse.positionScore >= 2.5 && horse.staminaScore > 80.0) {
          horse.positionScore -= 0.1;
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['3コーナー'] = _formatTairetsu(simHorses);
    }

    // 4. 4コーナーの予測 (瞬発力の影響)
    if (cornersToPredict.contains('4コーナー')) {
      for (final horse in simHorses) {
        // 瞬発力が高い馬は大きく前進
        horse.positionScore -= (horse.finishingKickScore / 100.0) * 1.5;
        // 逃げ・先行馬で瞬発力が低い馬は後退
        if (horse.positionScore < 3.0 && horse.finishingKickScore < 70.0) {
          horse.positionScore += 0.3;
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['4コーナー'] = _formatTairetsu(simHorses);
    }

    return development;
  }

  // 隊列を文字列フォーマットするヘルパー関数
  static String _formatTairetsu(List<_SimHorse> simHorses) {
    final List<List<_SimHorse>> groups = [];
    if (simHorses.isNotEmpty) {
      groups.add([simHorses.first]);
      for (int i = 1; i < simHorses.length; i++) {
        final currentHorse = simHorses[i];
        final prevHorse = simHorses[i - 1];
        // 位置取りスコアの差が大きければ新しいグループを作成
        if ((currentHorse.positionScore - prevHorse.positionScore).abs() > 0.8) {
          groups.add([]);
        }
        groups.last.add(currentHorse);
      }
    }

    return groups.map((group) {
      group.sort((a, b) => a.detail.gateNumber.compareTo(b.detail.gateNumber));

      final parallelGroups = <String>[];
      for (int i = 0; i < group.length;) {
        if (i + 1 < group.length &&
            (group[i + 1].detail.gateNumber - group[i].detail.gateNumber) <= 2) {
          parallelGroups.add(
              '(${group[i].detail.horseNumber},${group[i + 1].detail.horseNumber})');
          i += 2;
        } else {
          parallelGroups.add(group[i].detail.horseNumber.toString());
          i += 1;
        }
      }
      return parallelGroups.join(',');
    }).join('-');
  }
}