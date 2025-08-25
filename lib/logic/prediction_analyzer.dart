// lib/logic/prediction_analyzer.dart
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';

class PredictionAnalyzer {

  static const Map<String, double> _defaultWeights = {
    'legType': 20.0, 'courseFit': 20.0, 'trackCondition': 15.0, 'humanFactor': 15.0, 'condition': 10.0,
    'earlySpeed': 5.0, 'finishingKick': 10.0, 'stamina': 5.0,
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
        Map<String, double>? customWeights,
      }) {
    // 各ファクターのスコアを0-100点で算出
    final legTypeScore = _evaluateLegTypeAndPaceFit(horse, raceData, pastRecords); // 1. 脚質・展開適性
    final courseFitScore = _evaluateCourseFit(horse, raceData, pastRecords); // 2. コース適性
    final trackConditionScore = _evaluateTrackConditionFit(horse, raceData, pastRecords); // 3. 馬場適性
    final humanFactorScore = _evaluateHumanFactors(horse, pastRecords); // 4. 人的要因
    final conditionScore = _evaluateCondition(horse, raceData, pastRecords); // 5. コンディション
    // ▼▼▼【テスト用コード】▼▼▼
    final earlySpeedScore = evaluateEarlySpeedFit(horse, raceData, pastRecords); // 6. 天のスピード
    final finishingKickScore = evaluateFinishingKickFit(horse, raceData, pastRecords); // 7. 末脚のキレ
    final staminaScore = evaluateStaminaFit(horse, raceData, pastRecords); // 8. スタミナ
    // ▲▲▲【テスト用コード】▲▲▲

    // カスタム設定が渡されなければ、デフォルトの重み付けを使用
    final weights = customWeights ?? _defaultWeights;

    // ▼▼▼【テスト用コード】▼▼▼
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
    // ▲▲▲【テスト用コード】▲▲▲

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
    final predictedPace = raceData.racePacePrediction?.predictedPace ?? 'ミドル';
    final horseStyle = getRunningStyle(pastRecords);

    switch (predictedPace) {
      case 'ハイペース':
        if (horseStyle == '差し' || horseStyle == '追込') {
          return 95.0; // 展開が向く
        } else {
          return 60.0; // 展開が向かない
        }
      case 'スローペース':
        if (horseStyle == '逃げ' || horseStyle == '先行') {
          return 95.0; // 展開が向く
        } else {
          return 60.0; // 展開が向かない
        }
      case 'ミドルペース':
      default:
        return 80.0; // 平均的な評価
    }
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
      } else if (conditionPart.contains('重')) currentCondition = '重';
      else if (conditionPart.contains('不良')) currentCondition = '不良';
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
    final sameJockeyRaces = pastRecords.where((record) => record.jockey == horse.jockey).toList();

    if (sameJockeyRaces.isEmpty) {
      // トップジョッキーなら初騎乗でも高評価
      if (horse.jockey.contains('ルメール') || horse.jockey.contains('川田')) {
        return 85.0;
      }
      return 70.0; // コンビ実績がない場合は平均的な点数
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


  // ▼▼▼【テスト用コード】▼▼▼
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
    } else if (frontRunners >= raceData.horses.length / 2) sentences.add('先行馬が揃い、ペースは速くなる可能性がある。');
    else if (nigeCount > 1) sentences.add('逃げ馬が複数おり、先行争いが激化しそう。');

    // 2. 予測ペースと展開の言語化
    final pace = raceData.racePacePrediction?.predictedPace ?? 'ミドル';
    final advantageousStyle = raceData.racePacePrediction?.advantageousStyle ?? '展開次第';
    sentences.add('AIの予測ペースは「$pace」。$advantageousStyleと分析。');

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
  // ▲▲▲【テスト用コード】▲▲▲


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
      List<String> cornersToPredict,
      ) {
    // ▼▼▼【修正箇所】▼▼▼
    final positionScores = <PredictionHorseDetail, double>{};
    for(final horse in horses) {
      final style = legStyles[horse.horseId] ?? '不明';
      switch(style) {
        case '逃げ': positionScores[horse] = 1.0; break;
        case '先行': positionScores[horse] = 2.0; break;
        case '差し': positionScores[horse] = 3.0; break;
        case '追込': positionScores[horse] = 4.0; break;
        default: positionScores[horse] = 2.5; // 不明な場合は中団と仮定
      }
      // 内枠ほど前に出やすいと仮定し、スコアを微調整
      positionScores[horse] = positionScores[horse]! - (horse.gateNumber * 0.01);
    }

    final sortedHorses = horses.toList()
      ..sort((a, b) => positionScores[a]!.compareTo(positionScores[b]!));

    final List<List<PredictionHorseDetail>> groups = [];
    if (sortedHorses.isNotEmpty) {
      groups.add([sortedHorses.first]);
      for (int i = 1; i < sortedHorses.length; i++) {
        // 位置取りスコアの差が大きければ新しいグループを作成
        if ((positionScores[sortedHorses[i]]! - positionScores[sortedHorses[i-1]]!).abs() > 0.8) {
          groups.add([]);
        }
        groups.last.add(sortedHorses[i]);
      }
    }

    final cornerPrediction = groups.map((group) {
      // グループ内で枠番順にソートして内外を表現
      group.sort((a, b) => a.gateNumber.compareTo(b.gateNumber));

      // 並走グループを形成
      final parallelGroups = <String>[];
      for (int i = 0; i < group.length; ) {
        if (i + 1 < group.length && (group[i+1].gateNumber - group[i].gateNumber) <= 2) {
          parallelGroups.add('(${group[i].horseNumber},${group[i+1].horseNumber})');
          i += 2;
        } else {
          parallelGroups.add(group[i].horseNumber.toString());
          i += 1;
        }
      }
      return parallelGroups.join(',');
    }).join('-');

    final Map<String, String> development = {};
    for (final cornerName in cornersToPredict) {
      development[cornerName] = cornerPrediction;
    }
    return development;
    // ▲▲▲【修正箇所】▲▲▲
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
    int frontRunners = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = getRunningStyle(records);
      if (style == "逃げ" || style == "先行") {
        frontRunners++;
      }
    }

    String predictedPace;
    String advantageousStyle;

    // 逃げ・先行タイプの馬の数に応じてペースを予測
    if (frontRunners >= (horses.length / 3)) {
      predictedPace = "ハイペース";
      advantageousStyle = "差し・追込有利";
    } else if (frontRunners <= 1) {
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