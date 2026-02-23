// lib/logic/ai/race_analyzer.dart

import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/ai/aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/db/repositories/course_preset_repository.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';

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
    // 1. 過去レースのペース傾向を分析
    final Map<String, int> pastPaceCounts = {'ハイ': 0, 'ミドル': 0, 'スロー': 0};
    if (pastRaceResults.isNotEmpty) {
      for (final result in pastRaceResults) {
        final pace = RaceDataParser.calculatePaceFromRaceResult(result);
        pastPaceCounts[pace] = (pastPaceCounts[pace] ?? 0) + 1;
      }
    }

    // 2. 今回のメンバー構成を分析
    int nigeCount = 0;
    int senkoCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = LegStyleAnalyzer.getRunningStyle(records).primaryStyle;
      if (style == "逃げ") nigeCount++;
      if (style == "先行") senkoCount++;
    }
    final frontRunnersRatio = (nigeCount + senkoCount) / horses.length;

    // 3. ベースとなる確率を計算
    Map<String, double> paceProbabilities = {'ハイペース': 0.33, 'ミドルペース': 0.34, 'スローペース': 0.33};

    // 4. メンバー構成に応じて確率を調整
    if (nigeCount >= 2 || frontRunnersRatio > 0.5) {
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) + 0.3;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) - 0.3;
    } else if (nigeCount == 0 && frontRunnersRatio < 0.2) {
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) - 0.3;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) + 0.3;
    }

    // 5. 過去レースの傾向に応じてさらに確率を調整
    final totalPastRaces = pastRaceResults.length;
    if (totalPastRaces > 5) { // 十分なデータ数がある場合のみ
      final pastHighPaceRatio = (pastPaceCounts['ハイ'] ?? 0) / totalPastRaces;
      final pastSlowPaceRatio = (pastPaceCounts['スロー'] ?? 0) / totalPastRaces;
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) + (pastHighPaceRatio - 0.33) * 0.5;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) + (pastSlowPaceRatio - 0.33) * 0.5;
    }

    // 6. 確率の合計が1になるように正規化
    final totalProbability = paceProbabilities.values.reduce((a, b) => a + b);
    if (totalProbability > 0) {
      paceProbabilities.updateAll((key, value) => (value / totalProbability).clamp(0.0, 1.0));
    } else {
      // 予期せぬエラーで合計が0になった場合は均等割りにフォールバック
      paceProbabilities = {'ハイペース': 0.33, 'ミドルペース': 0.34, 'スローペース': 0.33};
    }

    // 最終的なキー名を調整
    final finalProbabilities = {
      'ハイペース': paceProbabilities['ハイペース']!,
      'ミドルペース': paceProbabilities['ミドルペース']!,
      'スローペース': paceProbabilities['スローペース']!,
    };

    return RacePacePrediction(paceProbabilities: finalProbabilities);
  }



  /// 各馬の脚質と枠順を元に、各コーナーの展開を予測（シミュレーション）します。
  static Future<Map<String, String>> simulateRaceDevelopment(
      PredictionRaceData raceData,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<String> cornersToPredict,
      Map<String, JockeyStats> allJockeyStats,
      ) async {
    final CoursePresetRepository coursePresetRepo = CoursePresetRepository();
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
    final CoursePreset? coursePreset = await coursePresetRepo.getCoursePreset(courseId);

    final simHorses = raceData.horses.map((horse) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];
      final distribution = horse.legStyleProfile?.styleDistribution ?? {};
      double initialPositionScore;

      final nigeRate = distribution['逃げ'] ?? 0.0;
      final senkoRate = distribution['先行'] ?? 0.0;
      final sashiRate = distribution['差し'] ?? 0.0;
      final oikomiRate = distribution['追い込み'] ?? 0.0;

      if ((nigeRate + senkoRate + sashiRate + oikomiRate) > 0) {
        initialPositionScore =
            (nigeRate * 1.0) + (senkoRate * 2.0) + (sashiRate * 3.5) +
                (oikomiRate * 4.5);
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
      // 騎手要因による補正
      final jockeyStats = allJockeyStats[horse.jockeyId];
      if (jockeyStats != null && jockeyStats.courseStats != null &&
          jockeyStats.courseStats!.raceCount > 2) {
        // 当該コースの複勝率をスコアに反映（平均15%を基準とする）
        final courseShowRate = jockeyStats.courseStats!.showRate / 100.0;
        initialPositionScore -= (courseShowRate - 0.15) * 0.5; // 影響度は小さめに設定
      }

      final earlySpeedScore =
      AptitudeAnalyzer.evaluateEarlySpeedFit(horse, raceData, pastRecords);
      initialPositionScore -= (earlySpeedScore / 100.0) * 0.5;

      // コース特性による補正
      if (coursePreset != null) {
        if (coursePreset.keyPoints.contains('内枠有利') &&
            horse.gateNumber <= 2) {
          initialPositionScore -= 0.2; // 内枠ボーナス
        }
        if (coursePreset.keyPoints.contains('外枠不利') &&
            horse.gateNumber >= 7) {
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
    final predictedPace = raceData.racePacePrediction?.predictedPace ??
        'ミドルペース';

    simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
    if (cornersToPredict.contains('1-2コーナー')) {
      development['1-2コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('3コーナー')) {
      for (final horse in simHorses) {
        // ペースによる影響
        if (predictedPace.contains('ハイ') && horse.staminaScore < 70.0) {
          horse.positionScore += 0.25; // ハイペースでスタミナがない馬は後退
        }
        if (horse.positionScore >= 2.5 && horse.staminaScore > 80.0) {
          horse.positionScore -= 0.1; // 差し・追込でスタミナがある馬は進出開始
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['3コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('4コーナー')) {
      for (final horse in simHorses) {
        // ペースによる影響
        double kickFactor = 1.5;
        if (predictedPace.contains('スロー')) {
          kickFactor = 2.0; // スローなら瞬発力の影響を大きく
        } else if (predictedPace.contains('ハイ')) {
          kickFactor = 1.0; // ハイペースなら瞬発力の影響を小さく
        }

        // コース特性による補正
        if (coursePreset != null) {
          if (coursePreset.straightLength > 450) { // 長い直線
            horse.positionScore -=
                (horse.finishingKickScore / 100.0) * kickFactor * 1.2;
          } else if (coursePreset.straightLength < 330) { // 短い直線
            horse.positionScore -=
                (horse.finishingKickScore / 100.0) * kickFactor * 0.8;
            if (horse.positionScore < 3.0 && horse.finishingKickScore < 75.0) {
              horse.positionScore += 0.4; // 前の馬はさらに粘りやすく
            }
          } else {
            horse.positionScore -=
                (horse.finishingKickScore / 100.0) * kickFactor;
          }
        } else {
          horse.positionScore -=
              (horse.finishingKickScore / 100.0) * kickFactor;
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
      return parallelGroups.join('-');
    }).join('-');
  }
}