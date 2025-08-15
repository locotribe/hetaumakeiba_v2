// lib/logic/prediction_analyzer.dart
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'dart:math';

class PredictionAnalyzer {

  static const Map<String, double> _defaultWeights = {
    'legType': 30.0, 'courseFit': 25.0, 'trackCondition': 20.0, 'humanFactor': 15.0, 'condition': 10.0,
  };

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

    // カスタム設定が渡されなければ、デフォルトの重み付けを使用
    final weights = customWeights ?? _defaultWeights;

    // 重み付け加算して総合スコアを算出
    final totalScore = (legTypeScore * (weights['legType']! / 100)) +
        (courseFitScore * (weights['courseFit']! / 100)) +
        (trackConditionScore * (weights['trackCondition']! / 100)) +
        (humanFactorScore * (weights['humanFactor']! / 100)) +
        (conditionScore * (weights['condition']! / 100));

    final totalWeight = (weights['legType']! + weights['courseFit']! + weights['trackCondition']! + weights['humanFactor']! + weights['condition']!) / 100;

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
      if (conditionPart.contains('稍重')) currentCondition = '稍重';
      else if (conditionPart.contains('重')) currentCondition = '重';
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