// lib/logic/ai/race_analyzer.dart

import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/ai/aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

class _SimHorse {
  final PredictionHorseDetail detail;
  double positionScore;
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
  // JRA競馬場コードと名称のマッピング
  static final Map<String, String> venueCodeMap = {
    '札幌': '01', '函館': '02', '福島': '03', '新潟': '04', '東京': '05',
    '中山': '06', '中京': '07', '京都': '08', '阪神': '09', '小倉': '10',
  };

  // トラック種別をID用の文字列に変換するマッピング
  static final Map<String, String> trackIdMap = {
    '芝': 'shiba', 'ダ': 'dirt', '障': 'obstacle',
  };

  static RacePacePrediction predictRacePace(
      List<PredictionHorseDetail> horses,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<RaceResult> pastRaceResults,
      ) {
    final paceCounts = <String, int>{'ハイ': 0, 'ミドル': 0, 'スロー': 0};
    if (pastRaceResults.isNotEmpty) {
      for (final result in pastRaceResults) {
        final pace = RaceDataParser.calculatePaceFromRaceResult(result);
        paceCounts[pace] = (paceCounts[pace] ?? 0) + 1;
      }
    }

    int nigeCount = 0;
    int senkoCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = LegStyleAnalyzer.getRunningStyle(records).primaryStyle;
      if (style == "逃げ") nigeCount++;
      if (style == "先行") senkoCount++;
    }
    final frontRunners = nigeCount + senkoCount;

    String finalPrediction;
    final totalPastRaces = pastRaceResults.length;

    if (totalPastRaces > 0) {
      if (paceCounts['ハイ']! / totalPastRaces >= 0.7) {
        finalPrediction = 'ハイペース';
      } else if (paceCounts['スロー']! / totalPastRaces >= 0.7) {
        finalPrediction = 'スローペース';
      }
    }

    if (frontRunners >= (horses.length / 2)) {
      finalPrediction =
      paceCounts['ハイ']! > paceCounts['スロー']! ? 'ハイペース' : 'ミドルからハイ';
    } else if (nigeCount == 0 && frontRunners <= 2) {
      finalPrediction =
      paceCounts['スロー']! > paceCounts['ハイ']! ? 'スローペース' : 'スローからミドル';
    } else {
      finalPrediction = 'ミドルペース';
    }

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

    return RacePacePrediction(predictedPace: finalPrediction);
  }



  /// 各馬の脚質と枠順を元に、各コーナーの展開を予測（シミュレーション）します。
  static Future<Map<String, String>> simulateRaceDevelopment(
      PredictionRaceData raceData,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<String> cornersToPredict,
      ) async {
    final dbHelper = DatabaseHelper();
    final venueCode = venueCodeMap[raceData.venue];
    String trackType = '';
    String distance = '';

    final raceInfo = raceData.raceDetails1 ?? '';
    if (raceInfo.contains('障')) {
      trackType = 'obstacle';
    } else if (raceInfo.contains('ダ')) {
      trackType = 'dirt';
    } else {
      trackType = 'shiba';
    }

    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      distance = distanceMatch.group(1)!;
    }

    final courseId = '${venueCode}_${trackType}_$distance';
    final CoursePreset? coursePreset = await dbHelper.getCoursePreset(courseId);

    final simHorses = raceData.horses.map((horse) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];
      final distribution = horse.legStyleProfile?.styleDistribution ?? {};
      double initialPositionScore;

      final nigeRate = distribution['逃げ'] ?? 0.0;
      final senkoRate = distribution['先行'] ?? 0.0;
      final sashiRate = distribution['差し'] ?? 0.0;
      final oikomiRate = distribution['追い込み'] ?? 0.0;

      if ((nigeRate + senkoRate + sashiRate + oikomiRate) > 0) {
        initialPositionScore = (nigeRate * 1.0) + (senkoRate * 2.0) + (sashiRate * 3.5) + (oikomiRate * 4.5);
      } else {
        final style = horse.legStyleProfile?.primaryStyle ?? '不明';
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
      }

      final earlySpeedScore =
      AptitudeAnalyzer.evaluateEarlySpeedFit(horse, raceData, pastRecords);
      initialPositionScore -= (earlySpeedScore / 100.0) * 0.5;

      // コース特性による補正
      if (coursePreset != null) {
        if (coursePreset.keyPoints.contains('内枠有利') && horse.gateNumber <= 2) {
          initialPositionScore -= 0.2; // 内枠ボーナス
        }
        if (coursePreset.keyPoints.contains('外枠不利') && horse.gateNumber >= 7) {
          initialPositionScore += 0.2; // 外枠ペナルティ
        }
      }


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

    simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
    if (cornersToPredict.contains('1-2コーナー')) {
      development['1-2コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('3コーナー')) {
      for (final horse in simHorses) {
        if (horse.positionScore < 2.5 && horse.staminaScore < 75.0) {
          horse.positionScore += 0.2;
        }
        if (horse.positionScore >= 2.5 && horse.staminaScore > 80.0) {
          horse.positionScore -= 0.1;
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['3コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('4コーナー')) {
      for (final horse in simHorses) {
        // コース特性による補正
        if (coursePreset != null) {
          if (coursePreset.straightLength > 450) { // 長い直線
            horse.positionScore -= (horse.finishingKickScore / 100.0) * 1.8; // 瞬発力の影響を大きく
          } else if (coursePreset.straightLength < 330) { // 短い直線
            horse.positionScore -= (horse.finishingKickScore / 100.0) * 1.2; // 瞬発力の影響を小さく
            if (horse.positionScore < 3.0 && horse.finishingKickScore < 75.0) {
              horse.positionScore += 0.4; // 前の馬はさらに粘りやすく
            }
          } else {
            horse.positionScore -= (horse.finishingKickScore / 100.0) * 1.5;
          }
        } else {
          horse.positionScore -= (horse.finishingKickScore / 100.0) * 1.5;
        }


        if (horse.positionScore < 3.0 && horse.finishingKickScore < 70.0) {
          horse.positionScore += 0.3;
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['4コーナー'] = _formatTairetsu(simHorses);
    }

    return development;
  }

  static String _formatTairetsu(List<_SimHorse> simHorses) {
    final List<List<_SimHorse>> groups = [];
    if (simHorses.isNotEmpty) {
      groups.add([simHorses.first]);
      for (int i = 1; i < simHorses.length; i++) {
        final currentHorse = simHorses[i];
        final prevHorse = simHorses[i - 1];
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