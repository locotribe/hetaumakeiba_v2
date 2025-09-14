// lib/logic/ai/summary_generator.dart

import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/aptitude_analyzer.dart';

class SummaryGenerator {
  /// AI予測のサマリーと解説文を生成する
  static String generatePredictionSummary(
      PredictionRaceData raceData,
      Map<String, double> overallScores,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      ) {
    final sentences = <String>[];

    // 1. 脚質構成の分析
    int nigeCount = 0;
    int senkoCount = 0;
    for (var horse in raceData.horses) {
      final style =
      RaceAnalyzer.getRunningStyle(allPastRecords[horse.horseId] ?? []);
      if (style == '逃げ') nigeCount++;
      if (style == '先行') senkoCount++;
    }

    final frontRunners = nigeCount + senkoCount;
    if (frontRunners == 0) {
      sentences.add('明確な逃げ・先行馬が不在。');
    } else if (frontRunners >= raceData.horses.length / 2) {
      sentences.add('先行馬が揃い、ペースは速くなる可能性がある。');
    } else if (nigeCount > 1) {
      sentences.add('逃げ馬が複数おり、先行争いが激化しそう。');
    }

    // 2. 予測ペースの言語化
    final pace = raceData.racePacePrediction?.predictedPace ?? '不明';
    sentences.add('AIの予測ペースは「$pace」。'); // advantageousStyleの参照を削除

    // 3. 本命馬の強み分析
    final sortedHorses = raceData.horses.toList()
      ..sort((a, b) =>
          (overallScores[b.horseId] ?? 0.0)
              .compareTo(overallScores[a.horseId] ?? 0.0));

    if (sortedHorses.isNotEmpty) {
      final topHorse = sortedHorses.first;
      final topHorseRecords = allPastRecords[topHorse.horseId] ?? [];

      final scores = {
        '先行力':
        AptitudeAnalyzer.evaluateEarlySpeedFit(topHorse, raceData, topHorseRecords),
        '瞬発力': AptitudeAnalyzer.evaluateFinishingKickFit(
            topHorse, raceData, topHorseRecords),
        'スタミナ':
        AptitudeAnalyzer.evaluateStaminaFit(topHorse, raceData, topHorseRecords),
      };

      final topAbility =
      scores.entries.reduce((a, b) => a.value > b.value ? a : b);

      sentences
          .add('総合評価1位の「${topHorse.horseName}」は、特に「${topAbility.key}」のスコアが高い。');
    }

    return sentences.join(' ');
  }
}