// lib/logic/ai/historical_match_engine_factors/popularity_factor.dart

import 'dart:math';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

class PopularityFactorResult {
  final double valueIndex; // 実力スコア
  final double score;      // 今回の人気・波乱度を加味した最終スコア(0-100)
  final String diag;
  final String reasoning;

  PopularityFactorResult({
    required this.valueIndex,
    required this.score,
    required this.diag,
    required this.reasoning,
  });
}

class PopularityFactor {
  // ★引数に currentRaceName と pastRaceVolatility（波乱度）を追加
  PopularityFactorResult analyze(PredictionHorseDetail horse, List<HorseRaceRecord> history, String currentRaceName, double pastRaceVolatility) {
    double totalRaceScore = 0.0;
    double totalWeight = 0.0;
    bool hasHitWall = false;

    // 1. 今回のレース格（モノサシ）を取得
    double currentClassVal = _getClassValue(currentRaceName);

    // 直近6走に絞る
    final targetHistory = history.take(6).toList();

    for (int i = 0; i < targetHistory.length; i++) {
      final rec = targetHistory[i];
      int hPop = int.tryParse(rec.popularity) ?? 0;
      int hRank = int.tryParse(rec.rank) ?? 0;
      if (hPop == 0 || hRank == 0) continue;

      double pastClassVal = _getClassValue(rec.raceName);

      // --- A. 絶対評価（着順基本点） ---
      double absolutePoints = 0.0;
      if (hRank == 1) absolutePoints = 4.0;
      else if (hRank == 2) absolutePoints = 2.0;
      else if (hRank == 3) absolutePoints = 1.0;
      else if (hRank == 4 || hRank == 5) absolutePoints = 0.0;
      else absolutePoints = -1.0;

      // --- B. 相対評価（Gap妙味点） ---
      double rawGap = (hPop - hRank).toDouble();
      double gapPoints = 0.0;

      if (hRank <= 5) {
        gapPoints = rawGap > 0 ? min(rawGap, 5.0) : rawGap; // 5着以内はプラスを評価
      } else {
        gapPoints = rawGap < 0 ? rawGap : 0.0; // 6着以下はノイズ排除（マイナスGapのみペナルティ）
      }

      // --- C. クラスの壁検知 ---
      // 今回と同等か上のクラスで6着以下に大敗している場合は「壁」とみなす
      if (hRank >= 6 && pastClassVal >= currentClassVal - 0.1) {
        hasHitWall = true;
      }

      // --- D. 1レースの実力スコア ---
      double raceScore = (absolutePoints + gapPoints) * pastClassVal;

      // --- E. 時系列の重み ---
      double recencyWeight = 1.0;
      if (i == 0) recencyWeight = 0.7;      // 前走
      else if (i == 1) recencyWeight = 1.3; // 2走前
      else if (i == 2) recencyWeight = 1.1; // 3走前
      else if (i == 3) recencyWeight = 0.9; // 4走前
      else recencyWeight = 0.7;             // 5〜6走前

      totalRaceScore += (raceScore * recencyWeight);
      totalWeight += recencyWeight;
    }

    // 平均実力スコアの算出
    double avgValueIndex = 0.0;
    if (totalWeight > 0) {
      avgValueIndex = totalRaceScore / totalWeight;
    }

    // クラスの壁に当たっている場合は実力値を大きくディスカウント
    if (hasHitWall && avgValueIndex > 0) {
      avgValueIndex *= 0.4;
    }

    // =======================================================
    // --- F. 「今回の人気」と「レース波乱度」を掛け合わせて妙味を算出 ---
    // =======================================================
    int currPop = int.tryParse(horse.popularity?.toString() ?? '') ?? 0;
    if (currPop == 0) currPop = 6;

    double popScore = 50.0;

    // 1. 実力基礎点
    popScore += (avgValueIndex * 10.0);

    // 2. 妙味ボーナスと波乱傾向（荒れやすさ）のリンク
    bool isVolatileRace = pastRaceVolatility >= 4.5; // 過去の平均人気が4.5以上なら「荒れるレース」
    bool isSolidRace = pastRaceVolatility <= 3.0;    // 3.0以下なら「堅いレース」

    if (avgValueIndex >= 1.0) {
      // 実力がある穴馬への加点
      double popBonus = (currPop - 3) * 3.0;

      // ★レースが荒れる傾向なら、穴馬へのボーナスを1.5倍にブースト！
      if (isVolatileRace && currPop >= 6) {
        popBonus *= 1.5;
      }
      // ★レースが堅い傾向なら、穴馬へのボーナスを抑える
      else if (isSolidRace && currPop >= 6) {
        popBonus *= 0.5;
      }
      popScore += popBonus;

    } else if (avgValueIndex < 0) {
      // 実力がないのに上位人気（過剰人気）のペナルティ
      if (currPop <= 5) {
        popScore -= ((6 - currPop) * 5.0);
      }
    }

    // 0〜100に収める
    popScore = max(0.0, min(100.0, popScore));

    // --- G. 最終診断と理由 ---
    String popDiag = '適正';
    String reasoning = '';

    if (popScore >= 85.0) {
      popDiag = 'S:お宝馬';
      reasoning = '実力スコア(+${avgValueIndex.toStringAsFixed(1)})に対し、今回の人気(${currPop}人)は市場の盲点です。';
      if (isVolatileRace) reasoning += 'さらに、このレースは過去に波乱傾向が強く、穴馬の激走確率が非常に高い絶好の狙い目です。';
    } else if (popScore >= 70.0) {
      popDiag = 'A:狙い目';
      reasoning = '実力は十分あり(+${avgValueIndex.toStringAsFixed(1)})、今回のオッズにも妙味があります。堅実に馬券圏内を狙える存在です。';
    } else if (popScore >= 50.0) {
      if (currPop <= 3 && avgValueIndex > 1.0) {
        popDiag = 'B:妥当';
        reasoning = '実力通り高く評価されており妙味は薄いですが、能力は確かです。大崩れはしにくいでしょう。';
      } else {
        popDiag = 'C:標準';
        reasoning = '特筆すべき妙味や能力の突出は見られません。展開次第での浮上が鍵です。';
      }
    } else {
      if (currPop <= 4) {
        popDiag = 'C:危険';
        reasoning = '実力値(${avgValueIndex.toStringAsFixed(1)})が低調であるにもかかわらず、今回過剰に支持されています。危険な人気馬の可能性が高いです。';
      } else {
        popDiag = 'D:苦戦';
        reasoning = 'クラスの壁に当たっている可能性が高く、今回の人気も低いため苦戦が予想されます。';
      }
    }

    return PopularityFactorResult(
      valueIndex: avgValueIndex,
      score: popScore,
      diag: popDiag,
      reasoning: reasoning,
    );
  }

  double _getClassValue(String raceName) {
    if (raceName.contains('G1') || raceName.contains('GI')) return 2.0;
    if (raceName.contains('G2') || raceName.contains('GII')) return 1.7;
    if (raceName.contains('G3') || raceName.contains('GIII')) return 1.4;
    if (raceName.contains('OP') || raceName.contains('(L)') || raceName.contains('リステッド')) return 1.2;
    if (raceName.contains('3勝') || raceName.contains('1600万')) return 1.0;
    if (raceName.contains('2勝') || raceName.contains('1000万')) return 0.8;
    if (raceName.contains('1勝') || raceName.contains('500万')) return 0.6;
    return 0.4;
  }
}