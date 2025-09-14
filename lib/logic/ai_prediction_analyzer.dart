// lib/logic/ai_prediction_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/complex_aptitude_model.dart';
import 'package:hetaumakeiba_v2/models/best_time_stats_model.dart';
import 'package:hetaumakeiba_v2/models/fastest_agari_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';

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

class AiPredictionAnalyzer {

  static const Map<String, int> _defaultWeights = {
    'legType': 20, 'courseFit': 20, 'trackCondition': 15, 'humanFactor': 15, 'condition': 10,
    'earlySpeed': 5, 'finishingKick': 10, 'stamina': 5,
  };

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

  static FitnessRating _evaluateTrackFit(PredictionHorseDetail horse, PredictionRaceData raceData, List<HorseRaceRecord> pastRecords) {
    // 1. 今回のレースの馬場状態を取得
    final raceInfo = raceData.raceDetails1 ?? '';
    final raceInfoParts = raceInfo.split('/');
    String currentCondition = '良'; // デフォルトは良馬場
    if (raceInfoParts.length > 2) {
      final conditionPart = raceInfoParts[2].trim();
      if (conditionPart.contains('稍重')) {
        currentCondition = '稍重';
      } else if (conditionPart.contains('重')) currentCondition = '重';
      else if (conditionPart.contains('不良')) currentCondition = '不良';
    }
    final isHeavyTrack = currentCondition != '良';

    // 2. 過去の道悪実績と良馬場実績を抽出
    final heavyTrackRaces = pastRecords.where((r) => ['稍重', '重', '不良'].contains(r.trackCondition)).toList();
    final goodTrackRaces = pastRecords.where((r) => r.trackCondition == '良').toList();

    // 3. 評価ロジック
    if (isHeavyTrack) { // 今回が道悪の場合
      if (heavyTrackRaces.isEmpty) return FitnessRating.unknown; // 道悪未経験
      final topThreeFinishes = heavyTrackRaces.where((r) => (int.tryParse(r.rank) ?? 99) <= 3).length;
      final placeRate = topThreeFinishes / heavyTrackRaces.length;
      if (placeRate >= 0.5) return FitnessRating.excellent; // 道悪巧者
      if (placeRate > 0) return FitnessRating.good; // 道悪実績あり
      return FitnessRating.poor; // 道悪で好走歴なし
    } else { // 今回が良馬場の場合
      if (goodTrackRaces.isEmpty) return FitnessRating.unknown; // 良馬場未経験
      final topThreeFinishes = goodTrackRaces.where((r) => (int.tryParse(r.rank) ?? 99) <= 3).length;
      final placeRate = topThreeFinishes / goodTrackRaces.length;
      if (placeRate >= 0.5) return FitnessRating.excellent;
      if (placeRate > 0) return FitnessRating.good;
      return FitnessRating.average; // 良馬場で好走歴がなくても平均評価
    }
  }

  static FitnessRating _evaluatePaceFit(PredictionHorseDetail horse, PredictionRaceData raceData, List<HorseRaceRecord> pastRecords) {
    final predictedPace = raceData.racePacePrediction?.predictedPace ?? 'ミドルペース';
    final horseStyle = getRunningStyle(pastRecords);

    if (horseStyle == '不明') return FitnessRating.unknown;

    switch (predictedPace) {
      case 'ハイペース':
        return (horseStyle == '差し' || horseStyle == '追込') ? FitnessRating.excellent : FitnessRating.poor;
      case 'スローペース':
        return (horseStyle == '逃げ' || horseStyle == '先行') ? FitnessRating.excellent : FitnessRating.poor;
      case 'ミドルペース':
      default:
        return FitnessRating.average;
    }
  }

  static FitnessRating _evaluateWeightFit(PredictionHorseDetail horse, PredictionRaceData raceData, List<HorseRaceRecord> pastRecords) {
    final goodPerformances = pastRecords.where((r) => (int.tryParse(r.rank) ?? 99) <= 3).toList();
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

  static FitnessRating _evaluateGateFit(PredictionHorseDetail horse, PredictionRaceData raceData, List<HorseRaceRecord> pastRecords, RaceStatistics? raceStats) {
    if (raceStats == null) return FitnessRating.unknown;

    try {
      final statsData = json.decode(raceStats.statisticsJson) as Map<String, dynamic>;
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
      if (gateShowRate > avgShowRate * 1.5) return FitnessRating.excellent; // 平均の1.5倍以上
      if (gateShowRate > avgShowRate * 1.1) return FitnessRating.good; // 平均の1.1倍以上
      if (gateShowRate < avgShowRate * 0.9) return FitnessRating.poor; // 平均の0.9倍未満
      return FitnessRating.average;
    } catch (e) {
      print('Error parsing gate fit stats: $e');
      return FitnessRating.unknown;
    }
  }


  /// 様々なファクターを総合評価し、0〜100点の「総合適性スコア」を算出します。
  /// このメソッドが、各ファクター評価メソッドを呼び出す司令塔となります。
  static double calculateOverallAptitudeScore(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords, {
        Map<String, int>? customWeights,
      }) {
    // 各ファクターのスコアを0-100点で算出
    final legTypeScore = _evaluateLegTypeAndPaceFit(horse, raceData, pastRecords); // 1. 脚質・展開適性
    final courseFitScore = _evaluateCourseFit(horse, raceData, pastRecords); // 2. コース適性
    final trackConditionScore = _evaluateTrackConditionFit(horse, raceData, pastRecords); // 3. 馬場適性
    final humanFactorScore = _evaluateHumanFactors(horse, pastRecords); // 4. 人的要因
    final conditionScore = _evaluateCondition(horse, raceData, pastRecords); // 5. コンディション
    final earlySpeedScore = evaluateEarlySpeedFit(horse, raceData, pastRecords); // 6. 天のスピード
    final finishingKickScore = evaluateFinishingKickFit(horse, raceData, pastRecords); // 7. 末脚のキレ
    final staminaScore = evaluateStaminaFit(horse, raceData, pastRecords); // 8. スタミナ

    // カスタム設定が渡されなければ、デフォルトの重み付けを使用
    final weights = customWeights ?? _defaultWeights;

    // 重み付け加算して総合スコアを算出
    final totalScore = (legTypeScore * (weights['legType']! / 100)) +
        (courseFitScore * (weights['courseFit']! / 100)) +
        (trackConditionScore * (weights['trackCondition']! / 100)) +
        (humanFactorScore * (weights['humanFactor']! / 100)) +
        (conditionScore * (weights['condition']! / 100)) +
        (earlySpeedScore * (weights['earlySpeed']! / 100)) +
        (finishingKickScore * (weights['finishingKick']! / 100)) +
        (staminaScore * (weights['stamina']! / 100));

    final totalWeight = (weights['legType']! + weights['courseFit']! + weights['trackCondition']! + weights['humanFactor']! + weights['condition']! + weights['earlySpeed']! + weights['finishingKick']! + weights['stamina']!) / 100;

    if (totalWeight == 0) return 0;

    // 重みの合計で割ることで、スケールを0-100に正規化
    final normalizedScore = totalScore / totalWeight;

    return normalizedScore.clamp(0, 100); // 最終スコアを0-100の範囲に収める
  }

// 1. 脚質・展開適性評価
  static double _evaluateLegTypeAndPaceFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    // 予測ペースを特定（ハイ, ミドル, スローに正規化）
    final predictedPaceRaw = raceData.racePacePrediction?.predictedPace ?? 'ミドルペース';
    String predictedPace;
    if (predictedPaceRaw.contains('ハイ')) {
      predictedPace = 'ハイ';
    } else if (predictedPaceRaw.contains('スロー')) {
      predictedPace = 'スロー';
    } else {
      predictedPace = 'ミドル';
    }

    // 予測ペースに一致する過去レースを抽出
    final relevantRaces = pastRecords.where((record) {
      final pace = RaceDataParser.calculatePace(record.pace);
      return pace == predictedPace;
    }).toList();

    // 一致するレースがない場合は基準点を返す
    if (relevantRaces.isEmpty) {
      return 70.0;
    }

    // 抽出したレースでの複勝率を計算
    final totalCount = relevantRaces.length;
    final placeCount = relevantRaces.where((record) {
      final rank = int.tryParse(record.rank);
      return rank != null && rank <= 3;
    }).length;

    final placeRate = placeCount / totalCount;

    // 複勝率を50点から100点の範囲のスコアに変換して返す
    return 50.0 + (placeRate * 50.0);
  }

  // 2. コース適性評価
  static double _evaluateCourseFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    // 1. 現在のレース条件を解析
    final raceInfo = raceData.raceDetails1 ?? '';
    final venueName = raceData.venue;

    String trackType;
    if (raceInfo.startsWith('障')) {
      trackType = '障';
    } else if (raceInfo.startsWith('ダ')) {
      trackType = 'ダ';
    } else {
      trackType = '芝';
    }

    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    if (distanceMatch == null) {
      return 60.0; // 距離が不明な場合は平均点
    }
    final distance = distanceMatch.group(1)!;

    // 2. 同一コースの実績を抽出
    final relevantRaces = pastRecords.where((record) {
      final recordVenueMatch = record.venue.contains(venueName);
      final recordDistance = record.distance.replaceAll(RegExp(r'[^0-9]'), '');

      String recordTrackType;
      if (record.distance.startsWith('障')) {
        recordTrackType = '障';
      } else if (record.distance.startsWith('ダ')) {
        recordTrackType = 'ダ';
      } else {
        recordTrackType = '芝';
      }

      return recordVenueMatch && recordDistance == distance && recordTrackType == trackType;
    }).toList();

    // 3. スコアリング
    if (relevantRaces.isEmpty) {
      return 60.0; // 同コースでの出走経験がない場合は平均点
    }

    int topThreeFinishes = 0;
    for (final race in relevantRaces) {
      final rank = int.tryParse(race.rank);
      if (rank != null && rank <= 3) {
        topThreeFinishes++;
      }
    }

    final placeRate = topThreeFinishes / relevantRaces.length;

    // 複勝率をベースにスコアリング
    if (placeRate >= 0.5) {
      return 100.0;
    } else if (placeRate >= 0.3) {
      return 80.0;
    } else if (placeRate > 0) {
      return 70.0;
    } else {
      return 50.0; // 出走経験はあるが3着以内がない場合
    }
  }

  // 3. 馬場適性評価
  static double _evaluateTrackConditionFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    // 1. 現在のレースの馬場状態を取得
    final raceInfo = raceData.raceDetails1 ?? '';
    final raceInfoParts = raceInfo.split('/');
    String currentCondition = '良'; // デフォルトは良馬場
    if (raceInfoParts.length > 2) {
      final conditionPart = raceInfoParts[2].trim();
      if (conditionPart.contains('稍重')) {
        currentCondition = '稍重';
      } else if (conditionPart.contains('重')) {
        currentCondition = '重';
      } else if (conditionPart.contains('不良')) {
        currentCondition = '不良';
      }
    }

    // 2. 過去の道悪実績を抽出
    final heavyTrackRaces = pastRecords.where((record) {
      return record.trackCondition == '稍重' || record.trackCondition == '重' || record.trackCondition == '不良';
    }).toList();

    // 3. スコアリング
    if (currentCondition == '良') {
      // 良馬場の場合、道悪実績が悪ければ減点
      if (heavyTrackRaces.isNotEmpty) {
        final avgRankInHeavy = heavyTrackRaces.map((r) => int.tryParse(r.rank) ?? 18).reduce((a,b) => a+b) / heavyTrackRaces.length;
        if (avgRankInHeavy > 10) return 50.0; // 道悪で大敗している場合
      }
      return 80.0; // 良馬場なら基本高評価
    } else {
      // 道悪の場合
      if (heavyTrackRaces.isEmpty) {
        return 60.0; // 道悪未経験の場合は平均点
      }

      int topThreeFinishes = 0;
      for (final race in heavyTrackRaces) {
        final rank = int.tryParse(race.rank);
        if (rank != null && rank <= 3) {
          topThreeFinishes++;
        }
      }
      final placeRateInHeavy = topThreeFinishes / heavyTrackRaces.length;

      if (placeRateInHeavy >= 0.5) return 100.0; // 道悪巧者
      if (placeRateInHeavy > 0) return 85.0; // 道悪実績あり
      return 40.0; // 道悪実績で掲示板外のみ
    }
  }

  // 4. 人的要因評価
  static double _evaluateHumanFactors(PredictionHorseDetail horse, List<HorseRaceRecord> pastRecords) {
    // 1. 今回と同じ騎手が騎乗した過去レースを抽出
    final sameJockeyRaces = pastRecords.where((record) => record.jockeyId == horse.jockeyId).toList();

    if (sameJockeyRaces.isEmpty) {
      return 75.0; // コンビ実績がない場合は中立的な点数
    }

    // 2. コンビでの複勝率を計算
    int topThreeFinishes = 0;
    for (final race in sameJockeyRaces) {
      final rank = int.tryParse(race.rank);
      if (rank != null && rank <= 3) {
        topThreeFinishes++;
      }
    }
    final placeRate = topThreeFinishes / sameJockeyRaces.length;

    // 3. スコアリング
    if (placeRate >= 0.8) {
      return 100.0; // ゴールデンコンビ
    } else if (placeRate >= 0.5) {
      return 90.0; // 好相性
    } else if (placeRate > 0) {
      return 75.0; // 実績あり
    } else {
      return 60.0; // 相性が良くない可能性
    }
  }

  // 5. コンディション評価
  static double _evaluateCondition(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    double score = 70.0; // ベーススコア

    // 1. 馬体重増減の評価
    final weightChangeMatch = RegExp(r'\(([\+\-]\d+)\)').firstMatch(horse.horseWeight ?? "");
    if (weightChangeMatch != null) {
      final change = int.tryParse(weightChangeMatch.group(1)!) ?? 0;
      // 増減が少ないほど高評価
      score += (10 - change.abs()).clamp(0, 10); // max 10点
    }

    // 2. レース間隔の評価
    if (pastRecords.isNotEmpty) {
      try {
        final currentRaceDate = DateTime.parse(raceData.raceDate.replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', ''));
        final lastRaceDate = DateTime.parse(pastRecords.first.date.replaceAll('/', '-'));
        final interval = currentRaceDate.difference(lastRaceDate).inDays;

        if (interval > 180) { // 半年以上の休み明け
          score -= 20;
        } else if (interval < 14) { // 連闘・連闘に近い
          score -= 10;
        } else if (interval > 28 && interval < 90) { // いわゆる「叩き2走目」や理想的な間隔
          score += 15;
        }
      } catch (e) {
        // 日付のパースに失敗した場合は何もしない
      }
    }

    return score.clamp(0, 100);
  }


  // 6. 天のスピード評価
  static double evaluateEarlySpeedFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    if (pastRecords.isEmpty) return 60.0;
    // 直近5走の2コーナー通過順位率の平均を計算
    double totalPositionRate = 0;
    int count = 0;
    for (final record in pastRecords.take(5)) {
      final horseCount = int.tryParse(record.numberOfHorses);
      final positions = record.cornerPassage.split('-').map((p) => int.tryParse(p)).toList();
      if (horseCount != null && horseCount > 0 && positions.length >= 2 && positions[1] != null) {
        totalPositionRate += positions[1]! / horseCount;
        count++;
      }
    }
    if (count == 0) return 60.0;
    final avgPositionRate = totalPositionRate / count;
    // 先行力があるほど高スコア
    return ((1 - avgPositionRate) * 100).clamp(0, 100);
  }

  // 7. 末脚のキレ評価
  static double evaluateFinishingKickFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    if (pastRecords.isEmpty) return 60.0;
    // 直近5走の上がり3ハロンタイムの平均を計算
    double totalAgari = 0;
    int count = 0;
    for (final record in pastRecords.take(5)) {
      final agari = double.tryParse(record.agari);
      if (agari != null && agari > 0) {
        totalAgari += agari;
        count++;
      }
    }
    if (count == 0) return 60.0;
    final avgAgari = totalAgari / count;
    // 上がりタイムが速いほど高スコア (例: 33秒なら高評価, 38秒なら低評価)
    final score = (100 - (avgAgari - 34.0) * 10).clamp(0, 100).toDouble();
    return score;
  }

  // 8. スタミナ評価
  static double evaluateStaminaFit(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords,
      ) {
    if (pastRecords.isEmpty) return 60.0;
    // 今回のレース距離を取得
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceData.raceDetails1 ?? '');
    if (distanceMatch == null) return 60.0;
    final currentDistance = int.parse(distanceMatch.group(1)!);

    // 過去に今回より長い距離で3着以内に入ったことがあるか
    final hasLongDistanceRecord = pastRecords.any((record) {
      final recordDistance = int.tryParse(record.distance.replaceAll(RegExp(r'[^0-9]'), ''));
      final rank = int.tryParse(record.rank);
      return recordDistance != null && rank != null && recordDistance > currentDistance && rank <= 3;
    });

    return hasLongDistanceRecord ? 95.0 : 70.0;
  }

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
      final style = getRunningStyle(allPastRecords[horse.horseId] ?? []);
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
      ..sort((a, b) => (overallScores[b.horseId] ?? 0.0).compareTo(overallScores[a.horseId] ?? 0.0));

    if (sortedHorses.isNotEmpty) {
      final topHorse = sortedHorses.first;
      final topHorseRecords = allPastRecords[topHorse.horseId] ?? [];

      final scores = {
        '先行力': evaluateEarlySpeedFit(topHorse, raceData, topHorseRecords),
        '瞬発力': evaluateFinishingKickFit(topHorse, raceData, topHorseRecords),
        'スタミナ': evaluateStaminaFit(topHorse, raceData, topHorseRecords),
      };

      final topAbility = scores.entries.reduce((a, b) => a.value > b.value ? a : b);

      sentences.add('総合評価1位の「${topHorse.horseName}」は、特に「${topAbility.key}」のスコアが高い。');
    }

    return sentences.join(' ');
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
        case '逃げ': initialPositionScore = 1.0; break;
        case '先行': initialPositionScore = 2.0; break;
        case '差し': initialPositionScore = 3.0; break;
        case '追込': initialPositionScore = 4.0; break;
        default: initialPositionScore = 2.5;
      }
      // 内枠ほど前に出やすいと仮定し、スコアを微調整
      initialPositionScore -= (horse.gateNumber * 0.05);

      return _SimHorse(
        detail: horse,
        positionScore: initialPositionScore,
        staminaScore: evaluateStaminaFit(horse, raceData, pastRecords),
        finishingKickScore: evaluateFinishingKickFit(horse, raceData, pastRecords),
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
        final prevHorse = simHorses[i-1];
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
      for (int i = 0; i < group.length; ) {
        if (i + 1 < group.length && (group[i+1].detail.gateNumber - group[i].detail.gateNumber) <= 2) {
          parallelGroups.add('(${group[i].detail.horseNumber},${group[i+1].detail.horseNumber})');
          i += 2;
        } else {
          parallelGroups.add(group[i].detail.horseNumber.toString());
          i += 1;
        }
      }
      return parallelGroups.join(',');
    }).join('-');
  }


  // 内部ヘルパー：脚質を判定する
  static String getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) return "自在";

    List<double> avgPositionRates = [];
    final recentRaces = records.where((r) => !r.cornerPassage.contains('(') && r.cornerPassage.contains('-')).take(5);

    if (recentRaces.isEmpty) return "自在";

    for (var record in recentRaces) {
      final horseCount = int.tryParse(record.numberOfHorses);
      final positions = record.cornerPassage.split('-').map((p) => int.tryParse(p) ?? -1).where((p) => p != -1).toList();

      if (horseCount == null || horseCount == 0 || positions.length < 2) continue;

      // 2コーナーまたはそれに相当する位置の通過順位率を計算
      final positionRate = positions[1] / horseCount;
      avgPositionRates.add(positionRate);
    }

    if (avgPositionRates.isEmpty) return "自在";

    final avgRate = avgPositionRates.reduce((a, b) => a + b) / avgPositionRates.length;

    if (avgRate <= 0.15) return "逃げ";
    if (avgRate <= 0.40) return "先行";
    if (avgRate <= 0.80) return "差し";
    return "追込";
  }

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
      finalPrediction = paceCounts['ハイ']! > paceCounts['スロー']! ? 'ハイペース' : 'ミドルからハイ';
    } else if (nigeCount == 0 && frontRunners <= 2) {
      finalPrediction = paceCounts['スロー']! > paceCounts['ハイ']! ? 'スローペース' : 'スローからミドル';
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

  /// コース・距離・馬場状態の3要素が完全に一致する過去レースを分析する
  static ComplexAptitudeStats analyzeComplexAptitude({
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
  }) {
    // 1. 今回のレース条件を解析
    final raceInfo = raceData.raceDetails1 ?? '';
    if (raceInfo.isEmpty) return ComplexAptitudeStats();

    // コース種別 (芝/ダート/障害)
    final String currentTrackType = raceInfo.startsWith('障') ? '障' : (raceInfo.startsWith('ダ') ? 'ダ' : '芝');
    // 距離
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    final String currentDistance = distanceMatch?.group(1) ?? '';
    // 馬場状態
    String currentTrackCondition = '良'; // デフォルト
    if (raceInfo.contains('稍重')) currentTrackCondition = '稍重';
    else if (raceInfo.contains('重')) currentTrackCondition = '重';
    else if (raceInfo.contains('不良')) currentTrackCondition = '不良';

    if (currentDistance.isEmpty) return ComplexAptitudeStats();

    // 2. 条件に完全一致する過去レースをフィルタリング
    final List<HorseRaceRecord> filteredRecords = pastRecords.where((record) {
      // 過去レースのコース種別
      final String recordTrackType = record.distance.startsWith('障') ? '障' : (record.distance.startsWith('ダ') ? 'ダ' : '芝');
      // 過去レースの距離
      final String recordDistance = record.distance.replaceAll(RegExp(r'[^0-9]'), '');

      return recordTrackType == currentTrackType &&
          recordDistance == currentDistance &&
          record.trackCondition == currentTrackCondition;
    }).toList();

    // 3. 成績を集計
    if (filteredRecords.isEmpty) {
      return ComplexAptitudeStats();
    }

    int winCount = 0;
    int placeCount = 0;
    int showCount = 0;

    for (final record in filteredRecords) {
      final rank = int.tryParse(record.rank);
      if (rank == null) continue;
      if (rank == 1) winCount++;
      if (rank <= 2) placeCount++;
      if (rank <= 3) showCount++;
    }

    final raceCount = filteredRecords.length;
    final otherCount = raceCount - showCount;

    return ComplexAptitudeStats(
      raceCount: raceCount,
      winCount: winCount,
      placeCount: placeCount,
      showCount: showCount,
      recordString: '$winCount-${placeCount - winCount}-${showCount - placeCount}-$otherCount',
    );
  }

  /// タイム文字列（例: "1:58.2"）を秒数（例: 118.2）に変換する
  static double? _parseTimeToSeconds(String timeStr) {
    if (timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    try {
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = double.parse(parts[1]);
        return (minutes * 60) + seconds;
      } else if (parts.length == 1) {
        return double.parse(parts[0]);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// 今回のレースと同一競馬場・同一距離の過去レースから持ち時計（ベストタイム）を算出する
  static BestTimeStats? analyzeBestTime({
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
  }) {
    // 1. 今回のレース条件を特定
    final venueName = raceData.venue;
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceData.raceDetails1 ?? '');
    if (distanceMatch == null) return null;
    final currentDistance = distanceMatch.group(1)!;

    // 2. 条件に一致する過去レースをフィルタリング
    final relevantRecords = pastRecords.where((record) {
      final recordVenueMatch = record.venue.contains(venueName);
      final recordDistance = record.distance.replaceAll(RegExp(r'[^0-9]'), '');
      return recordVenueMatch && recordDistance == currentDistance;
    }).toList();

    if (relevantRecords.isEmpty) return null;

    // 3. 最速タイムを持つレコードを特定
    HorseRaceRecord? bestTimeRecord;
    double minTimeInSeconds = double.infinity;

    for (final record in relevantRecords) {
      final timeInSeconds = _parseTimeToSeconds(record.time);
      if (timeInSeconds != null && timeInSeconds < minTimeInSeconds) {
        minTimeInSeconds = timeInSeconds;
        bestTimeRecord = record;
      }
    }

    if (bestTimeRecord == null) return null;

    // 4. 結果をBestTimeStatsモデルに格納して返す
    return BestTimeStats(
      timeInSeconds: minTimeInSeconds,
      formattedTime: bestTimeRecord.time,
      trackCondition: bestTimeRecord.trackCondition,
      raceName: bestTimeRecord.raceName,
      date: bestTimeRecord.date,
    );
  }

  /// 過去レースから最速の上がり3ハロンタイムを分析する
  static FastestAgariStats? analyzeFastestAgari({
    required List<HorseRaceRecord> pastRecords,
  }) {
    if (pastRecords.isEmpty) return null;

    HorseRaceRecord? bestAgariRecord;
    double fastestAgari = double.infinity;

    for (final record in pastRecords) {
      final agariTime = double.tryParse(record.agari);
      if (agariTime != null && agariTime > 0 && agariTime < fastestAgari) {
        fastestAgari = agariTime;
        bestAgariRecord = record;
      }
    }

    if (bestAgariRecord == null) return null;

    return FastestAgariStats(
      agariInSeconds: fastestAgari,
      formattedAgari: bestAgariRecord.agari,
      trackCondition: bestAgariRecord.trackCondition,
      raceName: bestAgariRecord.raceName,
      date: bestAgariRecord.date,
    );
  }
}