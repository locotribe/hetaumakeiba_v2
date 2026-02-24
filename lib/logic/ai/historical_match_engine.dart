// lib/logic/ai/historical_match_engine.dart

import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

// 各ファクターをインポート
import 'historical_match_engine_factors/weight_factor.dart';
import 'historical_match_engine_factors/frame_factor.dart';
import 'historical_match_engine_factors/popularity_factor.dart';
import 'historical_match_engine_factors/rotation_factor.dart';

class HistoricalMatchEngine {
  // 各ファクターのインスタンス化
  final WeightFactor _weightFactor = WeightFactor();
  final FrameFactor _frameFactor = FrameFactor();
  final PopularityFactor _popularityFactor = PopularityFactor();
  final RotationFactor _rotationFactor = RotationFactor();

  Map<String, dynamic> analyze({
    required String currentRaceName, // ←★これを追加
    required List<PredictionHorseDetail> currentHorses,
    required List<RaceResult> pastRaces,
    required Map<String, List<HorseRaceRecord>> currentHorseHistory,
    required Map<String, List<HorseRaceRecord>> pastTopHorseRecords,
  }) {
    // 1. 過去の上位馬抽出
    final topHorses = _extractTopHorses(pastRaces);

    if (topHorses.isEmpty) {
      return {'results': <HistoricalMatchModel>[], 'summary': null};
    }

    // 2. 傾向データ算出 (マクロ分析)
    final double medianWeight = _calculateMedianWeight(topHorses);
    final Map<String, double> zoneWinRates = _calculateZoneWinRates(topHorses);

    String bestZone = '中';
    double maxRate = -1.0;
    zoneWinRates.forEach((key, value) {
      if (value > maxRate) {
        maxRate = value;
        bestZone = key;
      }
    });

    final prevDataAnalysis = _analyzePrevRaceTrends(topHorses, pastRaces, pastTopHorseRecords);
    final List<String> favorableRotations = (prevDataAnalysis['rotations'] as List).cast<String>();
    final double avgPrevPop = prevDataAnalysis['avgPop'] as double;

    final summary = TrendSummary(
      medianWeight: medianWeight,
      bestZone: bestZone,
      bestRotation: favorableRotations.isNotEmpty ? favorableRotations.first : 'なし',
      bestPrevPop: '${avgPrevPop.toStringAsFixed(1)}番人気以内',
    );

// ★波乱度（過去の上位馬の平均人気）の算出
    double totalTopPop = 0.0;
    int topPopCount = 0;
    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        int pop = int.tryParse(h.popularity ?? '') ?? 0;
        if (rank >= 1 && rank <= 3 && pop > 0) {
          totalTopPop += pop;
          topPopCount++;
        }
      }
    }
    // 過去1〜3着馬の平均人気（例：3.0なら堅い、6.0なら荒れる）
    double pastRaceVolatility = topPopCount > 0 ? totalTopPop / topPopCount : 3.5;

    // 3. 各馬のマッチング計算 (ファクター呼び出し)
    final List<HistoricalMatchModel> results = [];

    for (final horse in currentHorses) {
      final history = currentHorseHistory[horse.horseId] ?? [];
      final prevRecord = history.isNotEmpty ? history.first : null;

      // 各ファクターに分析を委譲
      final weightRes = _weightFactor.analyze(horse, prevRecord, medianWeight);
      final frameRes = _frameFactor.analyze(horse.gateNumber, currentHorses.length, zoneWinRates, maxRate);
      // ★第3引数(レース名)、第4引数(波乱度)を追加
      final popRes = _popularityFactor.analyze(horse, history, currentRaceName, pastRaceVolatility);
      final rotRes = _rotationFactor.analyze(prevRecord, favorableRotations);

      // 総合スコアの算出
      double totalScore;
      if (frameRes.isGateFixed) {
        totalScore = (weightRes.score * 0.25) + (frameRes.score * 0.25) + (popRes.score * 0.25) + (rotRes.score * 0.25);
      } else {
        totalScore = (weightRes.score * 0.33) + (popRes.score * 0.33) + (rotRes.score * 0.33);
      }

      int prevPop = 0;
      if (prevRecord != null) {
        prevPop = int.tryParse(prevRecord.popularity) ?? 0;
      }
      int currPop = int.tryParse(horse.popularity?.toString() ?? '') ?? 0;

      results.add(HistoricalMatchModel(
        horseId: horse.horseId,
        horseName: horse.horseName,
        totalScore: totalScore,
        weightScore: weightRes.score,
        usedWeight: weightRes.usedWeight,
        weightDiff: weightRes.diff,
        isWeightCurrent: weightRes.isCurrent,
        weightStr: weightRes.displayStr,
        frameScore: frameRes.score,
        gateNumber: horse.gateNumber,
        totalHorses: currentHorses.length,
        relativePos: frameRes.relativePos,
        positionZone: frameRes.zone,
        popularityScore: popRes.score,
        valueIndex: popRes.valueIndex,
        currentPopStr: currPop > 0 ? '$currPop人' : '-',
        prevPopStr: prevPop > 0 ? '$prevPop人' : '-',
        popDiagnosis: popRes.diag,
        valueReasoning: popRes.reasoning,
        rotationScore: rotRes.score,
        prevRaceName: rotRes.prevRaceName,
        rotDiagnosis: rotRes.diag,
        recentHistory: history,
      ));
    }

    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return {
      'results': results,
      'summary': summary,
    };
  }

  // --- ヘルパーメソッド群 (変更なし) ---
  Map<String, dynamic> _analyzePrevRaceTrends(List<_HorseContext> topHorses, List<RaceResult> pastRaces, Map<String, List<HorseRaceRecord>> pastRecords) {
    final Map<String, int> rotationCounts = {};
    int totalPop = 0;
    int popCount = 0;
    for (final ctx in topHorses) {
      final records = pastRecords[ctx.horse.horseId];
      if (records == null || records.isEmpty) continue;
      final targetRace = pastRaces.firstWhere((r) => r.horseResults.any((h) => h.horseId == ctx.horse.horseId), orElse: () => pastRaces.first);
      HorseRaceRecord? prevRace;
      for (final rec in records) {
        if (rec.raceId != targetRace.raceId) {
          prevRace = rec;
          break;
        }
      }
      if (prevRace != null) {
        String raceName = prevRace.raceName.replaceAll(RegExp(r'\(.*\)'), '').trim();
        if (raceName.isNotEmpty) rotationCounts[raceName] = (rotationCounts[raceName] ?? 0) + 1;
        int pop = int.tryParse(prevRace.popularity) ?? 0;
        if (pop > 0) { totalPop += pop; popCount++; }
      }
    }
    final sortedRotations = rotationCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {'rotations': sortedRotations.take(3).map((e) => e.key).toList(), 'avgPop': popCount > 0 ? totalPop / popCount : 0.0};
  }

  List<_HorseContext> _extractTopHorses(List<RaceResult> races) {
    final List<_HorseContext> targets = [];
    for (final race in races) {
      final int totalHorses = race.horseResults.length;
      for (final horse in race.horseResults) {
        final rank = int.tryParse(horse.rank ?? '');
        if (rank != null && rank <= 3) targets.add(_HorseContext(horse, totalHorses));
      }
    }
    return targets;
  }

  double _calculateMedianWeight(List<_HorseContext> horses) {
    final weights = <double>[];
    for (final c in horses) {
      final w = WeightFactor.parseWeight(c.horse.horseWeight);
      if (w != null) weights.add(w);
    }
    if (weights.isEmpty) return 0.0;
    weights.sort();
    final middle = weights.length ~/ 2;
    return (weights.length % 2 == 1) ? weights[middle] : (weights[middle - 1] + weights[middle]) / 2.0;
  }

  Map<String, double> _calculateZoneWinRates(List<_HorseContext> horses) {
    int inner = 0, mid = 0, outer = 0, valid = 0;
    for (final c in horses) {
      final gate = int.tryParse(c.horse.horseNumber) ?? 0;
      final total = c.totalHorses;
      if (gate > 0 && total > 0) {
        final pos = (total > 1) ? (gate - 1) / (total - 1) : 0.0;
        final zone = FrameFactor.getZone(pos);
        if (zone == '内') inner++; else if (zone == '中') mid++; else if (zone == '外') outer++;
        valid++;
      }
    }
    if (valid == 0) return {'内': 0.0, '中': 0.0, '外': 0.0};
    return {'内': inner / valid, '中': mid / valid, '外': outer / valid};
  }
}

class _HorseContext {
  final HorseResult horse;
  final int totalHorses;
  _HorseContext(this.horse, this.totalHorses);
}