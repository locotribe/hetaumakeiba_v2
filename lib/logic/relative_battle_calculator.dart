// lib/logic/relative_battle_calculator.dart

import 'dart:math';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
// [追加] 調教タブ改修Step7: netkeiba の調教・評価 (v.2026.9.23+26092305)
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/horse_stats_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/stats_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/historical_match_engine_factors/training_factor.dart';
import '../models/relative_evaluation_model.dart';

/// 相対評価シミュレーションを実行する計算クラス
class RelativeBattleCalculator {
  // [修正] 出走馬データ読み込み統一 Step1: 乱数の種（seed）を渡せるようにした。同じ種・同じ入力なら、数字も短評も毎回同じになる。
  // 種を渡さないときは今までどおり毎回違う乱数になる (v.2026.10.16+26101618)
  final Random _random;

  RelativeBattleCalculator({int? seed})
      : _random = seed == null ? Random() : Random(seed);

  /// メインメソッド
  List<RelativeEvaluationResult> runSimulation(
      List<PredictionHorseDetail> horses, {
        int iterations = 100,
        Map<String, JockeyStats>? jockeyStats,
        Map<String, List<HorseRaceRecord>>? horsePerformanceMap,
        Map<String, List<TrainingTimeModel>>? trainingDataMap,
        // [追加] 調教タブ改修Step7: netkeiba の調教・評価（渡されないときは従来どおり pakara だけで計算） (v.2026.9.23+26092305)
        Map<String, List<NetkeibaTrainingSession>>? netkeibaTrainingMap,
        Map<String, NetkeibaTrainingReview>? netkeibaReviews,
        String? raceId,
      }) {
    if (horses.length < 2) return [];

    int totalHorses = horses.length;

    final List<_HorseStaticData> staticDataList = horses
        .map((h) => _prepareStaticData(h, totalHorses, jockeyStats, horsePerformanceMap, trainingDataMap,
            netkeibaTrainingMap, netkeibaReviews, raceId))
        .toList();

    // 各シナリオを実行
    final overallResult = _runScenario(staticDataList, iterations, null);
    final slowResult = _runScenario(staticDataList, iterations, RacePace.slow);
    final middleResult = _runScenario(staticDataList, iterations, RacePace.middle);
    final highResult = _runScenario(staticDataList, iterations, RacePace.high);

    List<RelativeEvaluationResult> results = [];
    overallResult.sort((a, b) => b.winRate.compareTo(a.winRate));

    for (int i = 0; i < overallResult.length; i++) {
      final baseRes = overallResult[i];
      final aiRank = i + 1;

      final slowRes = slowResult.firstWhere((r) => r.horseId == baseRes.horseId);
      final middleRes = middleResult.firstWhere((r) => r.horseId == baseRes.horseId);
      final highRes = highResult.firstWhere((r) => r.horseId == baseRes.horseId);

      final Map<RacePace, double> scenarioWinRates = {
        RacePace.slow: slowRes.winRate,
        RacePace.middle: middleRes.winRate,
        RacePace.high: highRes.winRate,
      };

      final Map<RacePace, int> scenarioRanks = {
        RacePace.slow: slowRes.rank,
        RacePace.middle: middleRes.rank,
        RacePace.high: highRes.rank,
      };

      final staticData = staticDataList.firstWhere((d) => d.horseId == baseRes.horseId);

      double maxScenarioWinRate = [slowRes.winRate, middleRes.winRate, highRes.winRate].reduce(max);
      double reversalScore = (maxScenarioWinRate - baseRes.winRate) * 100;
      if (reversalScore < 0) reversalScore = 0;

      // [削除] 好走条件・個別成績・相対評価の移動 Step4: 評価短評を廃止したので、短評だけに使っていた bestPace を消した (v.2026.10.17+26101709)

      double valueScore = 0.0;
      double winRate = baseRes.winRate;
      double odds = staticData.currentOdds ?? 0.0;
      int popularity = staticData.popularity ?? 99;

      if (winRate >= 0.03 && odds > 0) {
        double roi = winRate * odds;
        double gapBonus = (popularity - aiRank) * 5.0;
        valueScore = (roi * 100) + gapBonus;
      }

      // [削除] 好走条件・個別成績・相対評価の移動 Step4: 評価短評の生成（_generateRichComment）の呼び出しを消した。
      // 短評はペース別のシミュレーションがすべて終わった後に作っていたので、乱数の順番が変わっても勝率などの数字は変わらない (v.2026.10.17+26101709)

      results.add(RelativeEvaluationResult(
        horseId: baseRes.horseId,
        horseName: baseRes.horseName,
        popularity: baseRes.popularity,
        odds: odds,
        winRate: baseRes.winRate,
        rank: aiRank,
        reversalScore: reversalScore,
        confidence: baseRes.confidence,
        factorScores: {
          ...baseRes.factorScores,
          'value': valueScore,
        },
        jockeyDetails: staticData.jockeyDetails,
        compatibilityDetails: staticData.compatibilityDetails,
        gateDetails: staticData.gateDetails,
        trainingDetails: staticData.trainingDetails,
        scenarioWinRates: scenarioWinRates,
        scenarioRanks: scenarioRanks,
      ));
    }

    results.sort((a, b) => a.rank.compareTo(b.rank));
    return results;
  }

  // [削除] 好走条件・個別成績・相対評価の移動 Step4: 評価短評の生成（_generateRichComment・言い回しの選び方・言い回しの一覧）を消した (v.2026.10.17+26101709)

  // --- メイン処理 ---

  // [追加] 50点満点のスコアに対するランク文字列判定ヘルパー
  String _getRankFor50PointScale(double score) {
    if (score >= 45) return 'SS';
    if (score >= 35) return 'S';
    if (score >= 25) return 'A';
    if (score >= 15) return 'B';
    return 'C';
  }

  List<RelativeEvaluationResult> _runScenario(
      List<_HorseStaticData> staticDataList,
      int iterations,
      RacePace? forcedPace,
      ) {
    final winCounts = {for (var h in staticDataList) h.horseId: 0};
    final scoreAccumulator = {
      for (var h in staticDataList)
        h.horseId: {
          'base': 0.0,
          'style': 0.0,
          'pace': 0.0,
          'aptitude': 0.0,
          'jockey': 0.0,
          'compatibility': 0.0,
          'gate': 0.0,
          'training': 0.0,
        }
    };

    for (int i = 0; i < iterations; i++) {
      _runSingleIteration(staticDataList, winCounts, scoreAccumulator, forcedPace);
    }

    List<RelativeEvaluationResult> results = [];
    var sortedEntries = winCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int maxWinsPerIteration = staticDataList.length - 1;
    final int totalMatchups = iterations * maxWinsPerIteration;

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final horseId = entry.key;
      final winCount = entry.value;
      final staticData = staticDataList.firstWhere((d) => d.horseId == horseId);

      final winRate = totalMatchups > 0 ? winCount / totalMatchups : 0.0;
      final acc = scoreAccumulator[horseId]!;

      final factorScores = {
        'base': acc['base']! / iterations,
        'style': acc['style']! / iterations,
        'pace': acc['pace']! / iterations,
        'aptitude': acc['aptitude']! / iterations,
        'jockey': acc['jockey']! / iterations,
        'compatibility': acc['compatibility']! / iterations,
        'gate': acc['gate']! / iterations,
        'training': acc['training']! / iterations,
      };

      results.add(RelativeEvaluationResult(
        horseId: horseId,
        horseName: staticData.horseName,
        popularity: staticData.popularity,
        odds: staticData.currentOdds ?? 0.0,
        winRate: winRate,
        rank: i + 1,
        reversalScore: 0.0,
        confidence: _calculateConfidence(winRate, iterations),
        factorScores: factorScores,
        jockeyDetails: staticData.jockeyDetails,
        compatibilityDetails: staticData.compatibilityDetails,
        gateDetails: staticData.gateDetails,
        trainingDetails: staticData.trainingDetails,
        scenarioWinRates: {},
        scenarioRanks: {},
      ));
    }
    return results;
  }

  _HorseStaticData _prepareStaticData(
      PredictionHorseDetail horse,
      int totalHorses,
      Map<String, JockeyStats>? jockeyStats,
      Map<String, List<HorseRaceRecord>>? horsePerformanceMap,
      Map<String, List<TrainingTimeModel>>? trainingDataMap,
      [Map<String, List<NetkeibaTrainingSession>>? netkeibaTrainingMap,
      Map<String, NetkeibaTrainingReview>? netkeibaReviews,
      String? raceId]
      ) {
    double baseAbility = 50.0;
    if (horse.overallScore != null) {
      baseAbility = horse.overallScore!;
    } else if (horse.effectiveOdds != null) {
      double? odds = double.tryParse(horse.effectiveOdds!);
      if (odds != null) {
        baseAbility = 100.0 - (odds * 2.0).clamp(0, 80);
      }
    } else if (horse.odds != null) {
      baseAbility = 100.0 - (horse.odds! * 2.0).clamp(0, 80);
    }

    double aptitudeScore = 0.0;
    if (horse.distanceCourseAptitudeStats != null) {
      final stats = horse.distanceCourseAptitudeStats!;
      double winRate = 0.0;
      if (stats.raceCount > 0) {
        winRate = stats.winCount / stats.raceCount;
      }
      aptitudeScore += (winRate * 30.0);
    }

    // --- 騎手評価 ---
    double jockeyScore = 0.0;
    Map<String, dynamic> jDetails = {
      'jockeyName': horse.jockey,
      'source': 'データなし',
      'raceCount': 0,
      'winRate': 0.0,
      'score': 0,
      'bonus': 'なし',
      'rank': 'C', // [追加] 初期値
    };

    if (jockeyStats != null && jockeyStats.containsKey(horse.jockeyId)) {
      final stats = jockeyStats[horse.jockeyId]!;
      // [修正] ボーナス判定のためにuseCourseStatsの基準を調整。足切りN数はボーナス付与側で個別に判定する。
      final bool useCourseStats = (stats.courseStats != null && stats.courseStats!.raceCount > 0);
      final FactorStats targetStats = useCourseStats ? stats.courseStats! : stats.overallStats;

      if (targetStats.raceCount > 0) {
        double rawWinRate = targetStats.winRate;
        double winRateRatio = (rawWinRate > 1.0) ? rawWinRate / 100.0 : rawWinRate;
        double baseScore = winRateRatio * 100.0;
        double confidence = 0.5 + ((targetStats.raceCount / 20.0).clamp(0.0, 0.5));
        jockeyScore = baseScore * confidence;

        // [追加] 段階的ボーナス評価 (コース連対率とN数で判定)
        int bonusScore = 0;
        String bonusLabel = 'なし';

        if (useCourseStats && targetStats.raceCount >= 5) {
          if (targetStats.placeRate >= 30.0) {
            bonusScore = 10;
            bonusLabel = 'コース連対率30%超 (+10)';
          } else if (targetStats.placeRate >= 20.0) {
            bonusScore = 5;
            bonusLabel = 'コース連対率20%超 (+5)';
          }
        }

        jockeyScore += bonusScore;
        if (jockeyScore > 50.0) jockeyScore = 50.0;

        jDetails = {
          'jockeyName': horse.jockey,
          'source': useCourseStats ? 'コース実績' : '通算実績',
          'raceCount': targetStats.raceCount,
          'winRate': winRateRatio,
          'score': jockeyScore.round(),
          'bonus': bonusLabel,
          'rank': _getRankFor50PointScale(jockeyScore),
        };
      }
    }

    // --- コンビ相性評価 ---
    double compatibilityScore = 0.0;
    Map<String, dynamic> cDetails = {
      'isFirstRide': true,
      'rideCount': 0,
      'winRate': 0.0,
      'placeRate': 0.0,
      'score': 0,
      'rank': 'C',
    };

    // --- 枠順評価 & 傾向データ取得 ---
    double gateScore = 0.0;
    Map<String, dynamic> gDetails = {
      'gateNumber': horse.horseNumber,
      'isDetermined': false,
      'tendency': <String, dynamic>{}, // 過去の内中外傾向
      'score': 0,
      'rank': 'C',
    };
    Map<String, Map<String, double>> gateTendency = {}; // 生データ

    if (horsePerformanceMap != null && horsePerformanceMap.containsKey(horse.horseId)) {
      final records = horsePerformanceMap[horse.horseId]!;

      // 1. コンビ評価
      final comboStats = HorseStatsAnalyzer.analyzeJockeyCombo(
        currentJockeyId: horse.jockeyId,
        performanceRecords: records,
        raceResults: {},
      );

      if (!comboStats.isFirstRide) {
        double rawWinRate = comboStats.winRate;
        double winRateRatio = (rawWinRate > 1.0) ? rawWinRate / 100.0 : rawWinRate;
        double winScore = winRateRatio * 40.0;
        double countBonus = (comboStats.rideCount * 1.5).clamp(0.0, 15.0);
        double confidence = (comboStats.rideCount / 5.0).clamp(0.5, 1.0);
        compatibilityScore = (winScore * confidence) + countBonus;
        if (compatibilityScore > 50.0) compatibilityScore = 50.0;

        cDetails = {
          'isFirstRide': false,
          'rideCount': comboStats.rideCount,
          'winRate': winRateRatio,
          'placeRate': comboStats.placeRate,
          'score': compatibilityScore.round(),
          'rank': _getRankFor50PointScale(compatibilityScore),
        };
      }

      // 2. 枠順傾向の取得
      gateTendency = StatsAnalyzer.analyzeGateTendency(pastRecords: records);

      // 今回の馬番が決まっている場合のみスコア計算
      if (horse.horseNumber > 0 && totalHorses > 0) {
        double posRatio = horse.horseNumber / totalHorses;
        String zone = 'outer';
        if (posRatio <= 0.33) zone = 'inner';
        else if (posRatio <= 0.66) zone = 'middle';

        // 該当ゾーンの勝率を取得
        double zoneWinRate = gateTendency[zone]?['winRate'] ?? 0.0;
        double zoneCount = gateTendency[zone]?['count'] ?? 0.0;

        // スコアリング (勝率ベース + 信頼度)
        double baseGateScore = zoneWinRate * 50.0; // 勝率40%なら20点
        double confidence = (zoneCount / 5.0).clamp(0.0, 1.0); // 5戦以上で信頼
        gateScore = baseGateScore * confidence;

        gDetails = {
          'gateNumber': horse.horseNumber,
          'isDetermined': true,
          'zone': zone, // 'inner', 'middle', 'outer'
          'tendency': gateTendency,
          'score': gateScore.round(),
          'rank': _getRankFor50PointScale(gateScore),
        };
      }
    }

    // --- 調教評価 ---
    // [修正] 調教タブ改修Step7: netkeiba の調教・最終追切の評価も渡す (v.2026.9.23+26092305)
    final tf = TrainingFactor();
    final netkeibaSessions = netkeibaTrainingMap?[horse.horseId] ?? const <NetkeibaTrainingSession>[];
    NetkeibaTrainingSession? finalSession;
    if (raceId != null && raceId.isNotEmpty) {
      for (final session in netkeibaSessions) {
        if (session.raceId != raceId) continue;
        if (session.laps.any((l) => l != null)) {
          finalSession = session;
          break;
        }
        finalSession ??= session;
      }
    }
    final netkeibaReview = netkeibaReviews?[horse.horseId];
    final tResult = tf.evaluate(
      horse.horseId,
      trainingDataMap ?? {},
      horse.sexAndAge,
      netkeibaTrainingMap: netkeibaTrainingMap ?? const {},
      review: netkeibaReview,
      finalSession: finalSession,
    );

    double trainingScore = tResult.score;
    final partnerText = finalSession?.partners
        ?.map((p) => p.fullText)
        .join(' / ');
    Map<String, dynamic> tDetails = {
      'rank': tResult.rank,
      'score': tResult.score,
      'diagnosis': tResult.diagnosis,
      // [追加] 調教タブ改修Step7: ダイアログ表示用 (v.2026.9.23+26092305)
      'netkeibaRank': netkeibaReview?.rank ?? finalSession?.rank,
      'netkeibaCritic': netkeibaReview?.critic ?? finalSession?.critic,
      'partner': (partnerText == null || partnerText.isEmpty) ? null : partnerText,
      'isBestTime': finalSession?.isBestTime == true,
      'course': tResult.course,
      'timeStr': tResult.timeStr,
      'lapStr': tResult.lapStr,
    };

    double? currentOdds;
    if (horse.effectiveOdds != null) {
      currentOdds = double.tryParse(horse.effectiveOdds!);
    } else {
      currentOdds = horse.odds;
    }

    return _HorseStaticData(
      horseId: horse.horseId,
      horseNumber: horse.horseNumber,
      horseName: horse.horseName,
      popularity: horse.popularity,
      baseAbility: baseAbility,
      aptitudeScore: aptitudeScore,
      jockeyScore: jockeyScore,
      compatibilityScore: compatibilityScore,
      gateScore: gateScore,
      trainingScore: trainingScore,
      jockeyDetails: jDetails,
      compatibilityDetails: cDetails,
      gateDetails: gDetails,
      trainingDetails: tDetails,
      gateTendency: gateTendency,
      currentOdds: currentOdds,
      legStyleProfile: horse.legStyleProfile,
    );
  }

  void _runSingleIteration(
      List<_HorseStaticData> staticDataList,
      Map<String, int> winCounts,
      Map<String, Map<String, double>> scoreAccumulator,
      RacePace? forcedPace,
      ) {
    final Map<String, String> currentStyles = {};
    int nigeCount = 0;

    for (var horse in staticDataList) {
      String selectedStyle = '自在';
      if (horse.legStyleProfile != null) {
        double rand = _random.nextDouble();
        double cumulative = 0.0;
        bool determined = false;
        final dist = horse.legStyleProfile!.styleDistribution;
        for (var style in ['逃げ', '先行', '差し', '追込']) {
          cumulative += (dist[style] ?? 0.0);
          if (rand <= cumulative) {
            selectedStyle = style;
            determined = true;
            break;
          }
        }
        if (!determined) selectedStyle = horse.legStyleProfile!.primaryStyle;
      }
      currentStyles[horse.horseId] = selectedStyle;
      if (selectedStyle == '逃げ') nigeCount++;
    }

    RacePace pace;
    if (forcedPace != null) {
      pace = forcedPace;
    } else {
      pace = RacePace.middle;
      if (nigeCount <= 1) pace = RacePace.slow;
      else if (nigeCount >= 3) pace = RacePace.high;
    }

    final Map<String, double> currentStrengths = {};

    for (var horse in staticDataList) {
      // 基礎スコア合計
      double score = horse.baseAbility + horse.aptitudeScore +
          horse.jockeyScore + horse.compatibilityScore + horse.gateScore + horse.trainingScore;

      double styleQualityBonus = 0.0;
      final style = currentStyles[horse.horseId]!;
      if (horse.legStyleProfile != null) {
        double winRate = horse.legStyleProfile!.styleWinRates[style] ?? 0.0;
        styleQualityBonus = winRate * 50.0;
      }
      score += styleQualityBonus;

      double paceBonus = 0.0;
      if (pace == RacePace.slow) {
        if (style == '逃げ') paceBonus += 15.0;
        else if (style == '先行') paceBonus += 5.0;
        else if (style == '追込') paceBonus -= 5.0;
      } else if (pace == RacePace.high) {
        if (style == '逃げ') paceBonus -= 10.0;
        else if (style == '差し') paceBonus += 5.0;
        else if (style == '追込') paceBonus += 10.0;
      }
      score += paceBonus;
      score += (_random.nextDouble() - 0.5) * 10.0;

      currentStrengths[horse.horseId] = score;

      scoreAccumulator[horse.horseId]!['base'] = scoreAccumulator[horse.horseId]!['base']! + horse.baseAbility;
      scoreAccumulator[horse.horseId]!['style'] = scoreAccumulator[horse.horseId]!['style']! + styleQualityBonus;
      scoreAccumulator[horse.horseId]!['pace'] = scoreAccumulator[horse.horseId]!['pace']! + paceBonus;
      scoreAccumulator[horse.horseId]!['aptitude'] = scoreAccumulator[horse.horseId]!['aptitude']! + horse.aptitudeScore;
      scoreAccumulator[horse.horseId]!['jockey'] = scoreAccumulator[horse.horseId]!['jockey']! + horse.jockeyScore;
      scoreAccumulator[horse.horseId]!['compatibility'] = scoreAccumulator[horse.horseId]!['compatibility']! + horse.compatibilityScore;
      scoreAccumulator[horse.horseId]!['gate'] = scoreAccumulator[horse.horseId]!['gate']! + horse.gateScore;
      scoreAccumulator[horse.horseId]!['training'] = scoreAccumulator[horse.horseId]!['training']! + horse.trainingScore;
    }

    // 総当たり戦
    for (int i = 0; i < staticDataList.length; i++) {
      for (int j = i + 1; j < staticDataList.length; j++) {
        var horseA = staticDataList[i];
        var horseB = staticDataList[j];

        double strA = currentStrengths[horseA.horseId]!;
        double strB = currentStrengths[horseB.horseId]!;

        // 相対位置補正 (Relative Position Logic)
        if (horseA.horseNumber > 0 && horseB.horseNumber > 0) {
          if (horseA.horseNumber < horseB.horseNumber) {
            double innerWinRate = horseA.gateTendency['inner']?['winRate'] ?? 0.0;
            if (innerWinRate > 0.2) strA += (innerWinRate * 5.0);

            double outerWinRate = horseB.gateTendency['outer']?['winRate'] ?? 0.0;
            if (outerWinRate < 0.1) strB -= 2.0;
          }
          else {
            double outerWinRate = horseA.gateTendency['outer']?['winRate'] ?? 0.0;
            if (outerWinRate > 0.2) strA += (outerWinRate * 5.0);

            double innerWinRate = horseB.gateTendency['inner']?['winRate'] ?? 0.0;
            if (innerWinRate < 0.1) strB -= 2.0;
          }
        }

        double probA = 1 / (1 + exp(-(strA - strB) / 15.0));

        if (_random.nextDouble() < probA) {
          winCounts[horseA.horseId] = (winCounts[horseA.horseId] ?? 0) + 1;
        } else {
          winCounts[horseB.horseId] = (winCounts[horseB.horseId] ?? 0) + 1;
        }
      }
    }
  }

  double _calculateConfidence(double winRate, int iterations) {
    if (winRate == 0 || winRate == 1) return 1.0;
    return 1.0 - (sqrt(winRate * (1 - winRate) / iterations));
  }
}

class _HorseStaticData {
  final String horseId;
  final int horseNumber;
  final String horseName;
  final int? popularity;
  final double baseAbility;
  final double aptitudeScore;
  final double jockeyScore;
  final double compatibilityScore;
  final double gateScore;
  final double trainingScore;
  final Map<String, dynamic> jockeyDetails;
  final Map<String, dynamic> compatibilityDetails;
  final Map<String, dynamic> gateDetails;
  final Map<String, dynamic> trainingDetails;
  final Map<String, Map<String, double>> gateTendency;
  final double? currentOdds;
  final LegStyleProfile? legStyleProfile;

  _HorseStaticData({
    required this.horseId,
    required this.horseNumber,
    required this.horseName,
    this.popularity,
    required this.baseAbility,
    required this.aptitudeScore,
    required this.jockeyScore,
    required this.compatibilityScore,
    required this.gateScore,
    required this.trainingScore,
    required this.jockeyDetails,
    required this.compatibilityDetails,
    required this.gateDetails,
    required this.trainingDetails,
    required this.gateTendency,
    this.currentOdds,
    this.legStyleProfile,
  });
}