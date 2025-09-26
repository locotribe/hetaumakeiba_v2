// lib/logic/ai/summary_generator.dart

import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

class SummaryGenerator {
  /// AI予測のサマリーと解説文を生成する
  static String generatePredictionSummary(
      PredictionRaceData raceData,
      Map<String, double> overallScores,
      Map<String, List<HorseRaceRecord>> allPastRecords, {
        CoursePreset? coursePreset,
      }) {
    // 1. レースの基本情報と脚質構成を分析
    int nigeCount = 0;
    int senkoCount = 0;
    int sashiCount = 0;
    int oikomiCount = 0;

    for (var horse in raceData.horses) {
      final style =
          LegStyleAnalyzer.getRunningStyle(allPastRecords[horse.horseId] ?? []).primaryStyle;
      if (style == '逃げ') nigeCount++;
      if (style == '先行') senkoCount++;
      if (style == '差し') sashiCount++;
      if (style == '追い込み') oikomiCount++;
    }
    final frontRunners = nigeCount + senkoCount;
    final backRunners = sashiCount + oikomiCount;

    // 2. 文章パーツを生成
    final introPhrase = _generateIntroPhrase(raceData);
    final pacePhrase = _generatePacePhrase(raceData, nigeCount, frontRunners, backRunners);
    final coursePhrase = coursePreset != null ? _generateCourseContextPhrase(coursePreset) : '';
    final honmeiPhrase = _generateHonmeiPhrase(raceData, overallScores, allPastRecords);

    // 3. 文章を結合して返す
    return [introPhrase, pacePhrase, coursePhrase, honmeiPhrase].where((s) => s.isNotEmpty).join(' ');
  }

  // --- 以下、文章パーツを生成するためのヘルパーメソッド ---
  // 新しく追加するメソッド
  static String _generateCourseContextPhrase(CoursePreset coursePreset) {
    if (coursePreset.straightLength > 500) {
      return '日本屈指の長い直線を考慮すると、末脚の持続力が問われる展開になりそうだ。';
    }
    if (coursePreset.straightLength < 300) {
      return '直線が短いため、いかに早く前方のポジションを取れるかが鍵となる。';
    }
    if (coursePreset.keyPoints.contains('急坂')) {
      return 'ゴール前の急坂をこなすパワーも重要な要素となる。';
    }
    return ''; // 特に特徴がなければ何も返さない
  }
  // 導入文を生成
  static String _generateIntroPhrase(PredictionRaceData raceData) {
    final horseCount = raceData.horses.length;
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceData.raceDetails1 ?? '');
    final distance = distanceMatch != null ? int.parse(distanceMatch.group(1)!) : 0;

    List<String> sentences = [];
    if (horseCount <= 12) {
      sentences.add('少頭数の一戦。');
    } else if (horseCount >= 16) {
      sentences.add('多頭数で紛れも考慮したい一戦。');
    }

    if (distance <= 1400) {
      sentences.add('短距離戦らしく、前半からスピードが問われる。');
    } else if (distance >= 2200) {
      sentences.add('長距離戦で、序盤は落ち着いた流れになりやすい。');
    }
    return sentences.join(' ');
  }

  // ペース・展開予測の文章を生成
  static String _generatePacePhrase(
      PredictionRaceData raceData, int nigeCount, int frontRunners, int backRunners) {
    final predictedPace = raceData.racePacePrediction?.predictedPace ?? '不明';
    List<String> sentences = [];

    if (nigeCount == 0) {
      sentences.add('明確な逃げ馬が不在で、');
      if (frontRunners <= 2) {
        sentences.add('スローペースからの瞬発力勝負が濃厚。');
      } else {
        sentences.add('先行馬同士の出方次第でペースが変わりそう。');
      }
    } else if (nigeCount == 1) {
      sentences.add('単騎逃げが見込める構成で、');
      if (frontRunners <= 3) {
        sentences.add('ペースは落ち着く可能性が高い。');
      } else {
        sentences.add('番手に控えたい馬が多く、楽な逃げにはならないか。');
      }
    } else {
      sentences.add('逃げ馬が複数おり、');
      sentences.add('前半から激しい先行争いが予想される。');
    }

    sentences.add('AIの予測ペースは「$predictedPace」。');

    if (frontRunners >= raceData.horses.length * 0.5) {
      sentences.add('前に行きたい馬が多く、持続力が問われる展開になりそうだ。');
    } else if (backRunners >= raceData.horses.length * 0.5) {
      sentences.add('差し・追い込み馬が多く、ペースが緩むと前残りの展開も考えられる。');
    }

    return sentences.join(' ');
  }

  // 本命馬の解説文を生成
  static String _generateHonmeiPhrase(
      PredictionRaceData raceData,
      Map<String, double> overallScores,
      Map<String, List<HorseRaceRecord>> allPastRecords) {
    final sortedHorses = raceData.horses.toList()
      ..sort((a, b) =>
          (overallScores[b.horseId] ?? 0.0)
              .compareTo(overallScores[a.horseId] ?? 0.0));

    if (sortedHorses.isEmpty) return '';

    final topHorse = sortedHorses.first;
    final topHorseRecords = allPastRecords[topHorse.horseId] ?? [];

    final scores = {
      '先行力': AptitudeAnalyzer.evaluateEarlySpeedFit(topHorse, raceData, topHorseRecords),
      '瞬発力': AptitudeAnalyzer.evaluateFinishingKickFit(topHorse, raceData, topHorseRecords),
      'スタミナ': AptitudeAnalyzer.evaluateStaminaFit(topHorse, raceData, topHorseRecords),
    };

    final topAbility = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    final predictedPace = raceData.racePacePrediction?.predictedPace ?? '不明';

    String paceFitComment = '';
    if ((predictedPace.contains('ハイ') && topAbility.key == 'スタミナ') ||
        (predictedPace.contains('スロー') && topAbility.key == '瞬発力')) {
      paceFitComment = '予測されるペースも向きそうだ。';
    }

    return '総合評価1位の「${topHorse.horseName}」は、特に「${topAbility.key}」のスコアが高い。$paceFitComment';
  }
}