// lib/logic/ai/historical_match_engine.dart

import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class HistoricalMatchEngine {

  Map<String, dynamic> analyze({
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

    // 2. 傾向データ算出
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

    // 3. 各馬のマッチング計算
    final List<HistoricalMatchModel> results = [];

    for (final horse in currentHorses) {
      final history = currentHorseHistory[horse.horseId] ?? [];
      final prevRecord = history.isNotEmpty ? history.first : null;

      // --- A. 馬体重分析 ---
      double? weight;
      bool isCurrent = false;
      String displayStr = '--';

      final currentWeightVal = _parseWeight(horse.horseWeight);
      if (currentWeightVal != null) {
        weight = currentWeightVal;
        isCurrent = true;
        displayStr = horse.horseWeight ?? '--';
      } else if (prevRecord != null) {
        final prevWeightVal = _parseWeight(prevRecord.horseWeight);
        if (prevWeightVal != null) {
          weight = prevWeightVal;
          isCurrent = false;
          displayStr = "${prevRecord.horseWeight} (前走)";
        }
      }

      double weightScore = 0.0;
      double diff = 0.0;
      if (weight != null && medianWeight > 0) {
        diff = (weight - medianWeight).abs();
        weightScore = 100.0 - (diff * 2.0);
        if (weightScore < 0) weightScore = 0;
      }

      // --- B. 枠順分析 ---
      double frameScore = 0.0;
      final int gate = horse.gateNumber;
      final int total = currentHorses.length;
      double relativePos = 0.0;
      String zone = '-';
      bool isGateFixed = gate > 0;

      if (isGateFixed) {
        relativePos = (total > 1) ? (gate - 1) / (total - 1) : 0.0;
        zone = _getZone(relativePos);
        if (maxRate > 0) {
          final rate = zoneWinRates[zone] ?? 0.0;
          frameScore = (rate / maxRate) * 100.0;
        }
      }

      // --- C. 人気妙味分析 (累積指数ロジック) ---
      // 1. 累積妙味指数 (Value Index) の計算
      double valueIndex = 0.0;
      // 直近5走程度を特に重視して計算
      int raceCount = 0;
      double performanceInHighClass = 0.0; // 重賞での加点分

      for (final rec in history) {
        if (raceCount >= 10) break; // 最大10走前まで

        int hPop = int.tryParse(rec.popularity) ?? 0;
        int hRank = int.tryParse(rec.rank) ?? 0;
        if (hPop == 0 || hRank == 0) continue;

        // a. 基礎ズレ (人気 - 着順)
        double baseGap = (hPop - hRank).toDouble();

        // b. 着順ボーナス
        if (hRank == 1) baseGap += 3.0;
        else if (hRank <= 3) baseGap += 1.0;

        // c. クラス係数 (レース名から推定)
        double classWeight = 1.0;
        if (rec.raceName.contains('G1') || rec.raceName.contains('GI')) classWeight = 2.0;
        else if (rec.raceName.contains('G2') || rec.raceName.contains('GII')) classWeight = 1.5;
        else if (rec.raceName.contains('G3') || rec.raceName.contains('GIII')) classWeight = 1.5;
        else if (rec.raceName.contains('OP') || rec.raceName.contains('(L)')) classWeight = 1.2;
        else if (rec.raceName.contains('新馬') || rec.raceName.contains('未勝利')) classWeight = 0.7;
        else if (rec.raceName.contains('1勝')) classWeight = 0.8;
        else if (rec.raceName.contains('2勝')) classWeight = 0.9;

        // 重賞でプラスが出ているかチェック（解説生成用）
        if (classWeight >= 1.5 && baseGap > 0) {
          performanceInHighClass += baseGap;
        }

        // d. 累積加算
        valueIndex += (baseGap * classWeight);
        raceCount++;
      }

      // 2. 評価と解説の生成
      double popScore = 50.0;
      String popDiag = '適正';
      String reasoning = '';
      int currPop = int.tryParse(horse.popularity?.toString() ?? '') ?? 0;

      // 妙味指数の判定基準
      if (valueIndex >= 10.0) {
        // 大幅プラス (過小評価傾向)
        if (currPop >= 4) {
          popScore = 98.0;
          popDiag = 'S:お宝馬';
          reasoning = '累積妙味指数が+${valueIndex.toStringAsFixed(1)}と非常に高く、実力に対し評価が追いついていません。特に重賞クラスでの好走実績が光り、今回は絶好の狙い目です。';
        } else {
          popScore = 85.0;
          popDiag = 'A:充実期';
          reasoning = '期待以上の走りを続けており充実期に入っています。人気サイドですが、信頼度は非常に高いと言えます。';
        }
      } else if (valueIndex >= 3.0) {
        // プラス (良好)
        if (currPop >= 6) {
          popScore = 90.0;
          popDiag = 'A:狙い目';
          reasoning = 'これまでの戦績に対し、今回の人気は低すぎます。不当に評価を落としている可能性が高く、馬券的妙味があります。';
        } else {
          popScore = 70.0;
          popDiag = 'B:妥当';
          reasoning = '人気と実力のバランスが取れています。大きく裏切る可能性は低いでしょう。';
        }
      } else if (valueIndex <= -10.0) {
        // 大幅マイナス (過大評価傾向)
        if (currPop <= 3) {
          popScore = 30.0;
          popDiag = 'C:危険';
          reasoning = '人気を裏切るケースが多く、累積指数は${valueIndex.toStringAsFixed(1)}と低調です。過剰人気の懸念があり、疑ってかかるべきです。';
        } else {
          popScore = 40.0;
          popDiag = 'D:苦戦';
          reasoning = '期待値に対し結果が出ていない状況が続いています。能力的に厳しい可能性があります。';
        }
      } else {
        // フラット
        popScore = 50.0;
        popDiag = 'C:標準';
        reasoning = '人気通りの走りをすることが多いタイプです。展開や枠順次第での浮上が鍵となります。';
      }

      // 前走人気 (表示用)
      int prevPop = 0;
      if (prevRecord != null) {
        prevPop = int.tryParse(prevRecord.popularity) ?? 0;
      }

      // --- D. ローテ・格分析 ---
      double rotScore = 40.0;
      String rotDiag = '';
      String prevRaceName = prevRecord?.raceName ?? '-';

      if (prevRaceName != '-') {
        bool isFavorable = favorableRotations.any((r) => prevRaceName.contains(r));
        bool isHighGrade = prevRaceName.contains('G1') || prevRaceName.contains('GI') ||
            prevRaceName.contains('G2') || prevRaceName.contains('GII');
        if (isFavorable) {
          rotScore = 95.0;
          rotDiag = '王道';
        } else if (isHighGrade) {
          rotScore = 80.0;
          rotDiag = '格上';
        } else {
          rotScore = 50.0;
          rotDiag = '標準';
        }
      }

      // --- E. 総合スコア ---
      double totalScore;
      if (isGateFixed) {
        totalScore = (weightScore * 0.25) + (frameScore * 0.25) + (popScore * 0.25) + (rotScore * 0.25);
      } else {
        totalScore = (weightScore * 0.33) + (popScore * 0.33) + (rotScore * 0.33);
      }

      results.add(HistoricalMatchModel(
        horseId: horse.horseId,
        horseName: horse.horseName,
        totalScore: totalScore,
        weightScore: weightScore,
        usedWeight: weight,
        weightDiff: diff,
        isWeightCurrent: isCurrent,
        weightStr: displayStr,
        frameScore: frameScore,
        gateNumber: gate,
        totalHorses: total,
        relativePos: relativePos,
        positionZone: zone,
        popularityScore: popScore,
        valueIndex: valueIndex,    // 追加
        currentPopStr: currPop > 0 ? '$currPop人' : '-',
        prevPopStr: prevPop > 0 ? '$prevPop人' : '-',
        popDiagnosis: popDiag,
        valueReasoning: reasoning, // 追加
        rotationScore: rotScore,
        prevRaceName: prevRaceName,
        rotDiagnosis: rotDiag,
        recentHistory: history,
      ));
    }

    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return {
      'results': results,
      'summary': summary,
    };
  }

  // (以下Helper Methodsは変更なし)
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
    for (final c in horses) { final w = _parseWeight(c.horse.horseWeight); if (w != null) weights.add(w); }
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
        final zone = _getZone(pos);
        if (zone == '内') inner++; else if (zone == '中') mid++; else if (zone == '外') outer++;
        valid++;
      }
    }
    if (valid == 0) return {'内': 0.0, '中': 0.0, '外': 0.0};
    return {'内': inner / valid, '中': mid / valid, '外': outer / valid};
  }
  String _getZone(double p) => p <= 0.33 ? '内' : p <= 0.66 ? '中' : '外';
  double? _parseWeight(String? s) {
    if (s == null || s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
    try { return double.tryParse(s.split('(')[0].replaceAll(RegExp(r'[^0-9.]'), '')); } catch (e) { return null; }
  }
}
class _HorseContext { final HorseResult horse; final int totalHorses; _HorseContext(this.horse, this.totalHorses); }