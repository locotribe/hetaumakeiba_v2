// lib/logic/ai/aptitude_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';

class AptitudeAnalyzer {
  static const Map<String, int> _defaultWeights = {
    'legType': 20,
    'courseFit': 20,
    'trackCondition': 15,
    'humanFactor': 15,
    'condition': 10,
    'earlySpeed': 5,
    'finishingKick': 10,
    'stamina': 5,
  };

  /// 様々なファクターを総合評価し、0〜100点の「総合適性スコア」を算出します。
  /// このメソッドが、各ファクター評価メソッドを呼び出す司令塔となります。
  static double calculateOverallAptitudeScore(
      PredictionHorseDetail horse,
      PredictionRaceData raceData,
      List<HorseRaceRecord> pastRecords, {
        Map<String, int>? customWeights,
      }) {
    // 各ファクターのスコアを0-100点で算出
    final legTypeScore =
    _evaluateLegTypeAndPaceFit(horse, raceData, pastRecords); // 1. 脚質・展開適性
    final courseFitScore =
    _evaluateCourseFit(horse, raceData, pastRecords); // 2. コース適性
    final trackConditionScore =
    _evaluateTrackConditionFit(horse, raceData, pastRecords); // 3. 馬場適性
    final humanFactorScore = _evaluateHumanFactors(horse, pastRecords); // 4. 人的要因
    final conditionScore =
    _evaluateCondition(horse, raceData, pastRecords); // 5. コンディション
    final earlySpeedScore =
    evaluateEarlySpeedFit(horse, raceData, pastRecords); // 6. 天のスピード
    final finishingKickScore =
    evaluateFinishingKickFit(horse, raceData, pastRecords); // 7. 末脚のキレ
    final staminaScore =
    evaluateStaminaFit(horse, raceData, pastRecords); // 8. スタミナ

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

    final totalWeight = (weights['legType']! +
        weights['courseFit']! +
        weights['trackCondition']! +
        weights['humanFactor']! +
        weights['condition']! +
        weights['earlySpeed']! +
        weights['finishingKick']! +
        weights['stamina']!) /
        100;

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
    final predictedPaceRaw =
        raceData.racePacePrediction?.predictedPace ?? 'ミドルペース';
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

      return recordVenueMatch &&
          recordDistance == distance &&
          recordTrackType == trackType;
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
      return record.trackCondition == '稍重' ||
          record.trackCondition == '重' ||
          record.trackCondition == '不良';
    }).toList();

    // 3. スコアリング
    if (currentCondition == '良') {
      // 良馬場の場合、道悪実績が悪ければ減点
      if (heavyTrackRaces.isNotEmpty) {
        final avgRankInHeavy = heavyTrackRaces
            .map((r) => int.tryParse(r.rank) ?? 18)
            .reduce((a, b) => a + b) /
            heavyTrackRaces.length;
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
  static double _evaluateHumanFactors(
      PredictionHorseDetail horse, List<HorseRaceRecord> pastRecords) {
    // 1. 今回と同じ騎手が騎乗した過去レースを抽出
    final sameJockeyRaces =
    pastRecords.where((record) => record.jockeyId == horse.jockeyId).toList();

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
    final weightChangeMatch =
    RegExp(r'\(([\+\-]\d+)\)').firstMatch(horse.horseWeight ?? "");
    if (weightChangeMatch != null) {
      final change = int.tryParse(weightChangeMatch.group(1)!) ?? 0;
      // 増減が少ないほど高評価
      score += (10 - change.abs()).clamp(0, 10); // max 10点
    }

    // 2. レース間隔の評価
    if (pastRecords.isNotEmpty) {
      try {
        final currentRaceDate = DateTime.parse(
            raceData.raceDate.replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', ''));
        final lastRaceDate =
        DateTime.parse(pastRecords.first.date.replaceAll('/', '-'));
        final interval = currentRaceDate.difference(lastRaceDate).inDays;

        if (interval > 180) {
          // 半年以上の休み明け
          score -= 20;
        } else if (interval < 14) {
          // 連闘・連闘に近い
          score -= 10;
        } else if (interval > 28 && interval < 90) {
          // いわゆる「叩き2走目」や理想的な間隔
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
      final positions =
      record.cornerPassage.split('-').map((p) => int.tryParse(p)).toList();
      if (horseCount != null &&
          horseCount > 0 &&
          positions.length >= 2 &&
          positions[1] != null) {
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
      final recordDistance =
      int.tryParse(record.distance.replaceAll(RegExp(r'[^0-9]'), ''));
      final rank = int.tryParse(record.rank);
      return recordDistance != null &&
          rank != null &&
          recordDistance > currentDistance &&
          rank <= 3;
    });

    return hasLongDistanceRecord ? 95.0 : 70.0;
  }
}