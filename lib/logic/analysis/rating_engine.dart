// lib/logic/analysis/rating_engine.dart
import 'dart:math';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 1戦ごとの分析結果
class RatingAnalyzedResult {
  final HorseRaceRecord record;
  final double raceRating;
  final double trendRating;
  final String levelGrade; // High / Mid / Low
  final double baseWeight;
  final String prevOdds;
  final String prevPop;

  RatingAnalyzedResult({
    required this.record,
    required this.raceRating,
    required this.trendRating,
    required this.levelGrade,
    required this.baseWeight,
    required this.prevOdds,
    required this.prevPop,
  });
}

/// 馬ごとの全体評価プロファイル（今回拡張された指標）
class HorseRatingProfile {
  final String horseId;
  final List<RatingAnalyzedResult> history;
  final double latestTrend;
  final String stabilityRank; // A:安定, B:普通, C:ムラ
  final String momentumStatus; // 上昇期, 反動警戒など
  final bool isClassCleared; // 今回のクラス基準点を超えた実績があるか
  final double bestRatingWeight; // 過去最高Rtを出した時の斤量
  final int bestRatingMonth; // 過去最高Rtを出した時の月

  HorseRatingProfile({
    required this.horseId,
    required this.history,
    required this.latestTrend,
    required this.stabilityRank,
    required this.momentumStatus,
    required this.isClassCleared,
    required this.bestRatingWeight,
    required this.bestRatingMonth,
  });
}

/// 基準斤量算出ロジック
class WeightAllowanceCalculator {
  static double calculateBaseWeight(int age, String gender, int raceMonth) {
    double baseWeight = 58.0;
    if (age <= 2) {
      baseWeight = (raceMonth <= 9) ? 55.0 : 56.0;
    } else if (age == 3) {
      if (raceMonth <= 5) baseWeight = 56.0;
      else if (raceMonth <= 9) baseWeight = 56.0;
      else baseWeight = 57.0;
    }
    if (gender == '牝' || gender == 'セ') baseWeight -= 2.0;
    return baseWeight;
  }
}

/// 高度レーティング計算エンジン
class AdvancedRatingEngine {
  static const double wClass  = 0.70;
  static const double wPerf   = 0.25;
  static const double wWeight = 0.05;

  static double getBaseRating(String raceName) {
    if (raceName.contains('(GI)') || raceName.contains('J.GI')) return 115.0;
    if (raceName.contains('(GII)') || raceName.contains('J.GII')) return 112.0;
    if (raceName.contains('(GIII)') || raceName.contains('J.GIII')) return 109.0;
    if (raceName.contains('(OP)') || raceName.contains('L)')) return 106.0;
    if (raceName.contains('3勝') || raceName.contains('1600万')) return 102.0;
    if (raceName.contains('2勝') || raceName.contains('1000万')) return 97.0;
    if (raceName.contains('1勝') || raceName.contains('500万')) return 92.0;
    if (raceName.contains('新馬') || raceName.contains('未勝利')) return 87.0;
    return 80.0;
  }

  /// 過去戦績を分析し、高度なプロフィールを作成する
  static HorseRatingProfile analyze(List<HorseRaceRecord> history, String horseId, String gender, String currentRaceName) {
    if (history.isEmpty) {
      return HorseRatingProfile(horseId: horseId, history: [], latestTrend: 0, stabilityRank: 'C', momentumStatus: 'データなし', isClassCleared: false, bestRatingWeight: 0, bestRatingMonth: 0);
    }

    List<RatingAnalyzedResult> results = [];
    List<double> rollingRatings = [];

    // 時系列順（古い順）にソート
    final sortedHistory = List<HorseRaceRecord>.from(history);
    sortedHistory.sort((a, b) => a.date.compareTo(b.date));

    int birthYear = 2020;
    if (horseId.length >= 4) {
      birthYear = int.tryParse(horseId.substring(0, 4)) ?? 2020;
    }

    double maxRt = -999.0;
    double bestWeight = 0.0;
    int bestMonth = 1;

    for (var record in sortedHistory) {
      double base = getBaseRating(record.raceName);
      int rank = int.tryParse(record.rank) ?? 10;
      int total = int.tryParse(record.numberOfHorses) ?? 12;

      double relPerf = 1.0;
      if (total > 1) {
        relPerf = (1.0 - (rank - 1) / (total - 1)).clamp(0.0, 1.0);
        relPerf = relPerf * relPerf;
      }

      int raceYear = birthYear + 3;
      int raceMonth = 1;
      final dateParts = record.date.split(RegExp(r'[/\-年月日]'));
      if (dateParts.isNotEmpty) {
        raceYear = int.tryParse(dateParts[0]) ?? raceYear;
        if (dateParts.length >= 2) raceMonth = int.tryParse(dateParts[1]) ?? 1;
      }
      int age = raceYear - birthYear;
      if (age < 2) age = 2;

      double baseWeight = WeightAllowanceCalculator.calculateBaseWeight(age, gender, raceMonth);
      double actualWeight = double.tryParse(record.carriedWeight) ?? baseWeight;
      double wCorrection = (actualWeight - baseWeight) * 2.0;

      double raceRating = (base * wClass) + (base * (0.9 + 0.2 * relPerf) * wPerf) + (wCorrection * wWeight);
      double trend = rollingRatings.isEmpty ? raceRating : rollingRatings.reduce((a, b) => a + b) / rollingRatings.length;

      String level = "Mid";
      if (rollingRatings.isNotEmpty) {
        if (raceRating > trend + 2.0) level = "High";
        else if (raceRating < trend - 2.0) level = "Low";
      }

      // 最高レーティング時の記録を更新
      if (raceRating > maxRt) {
        maxRt = raceRating;
        bestWeight = actualWeight;
        bestMonth = raceMonth;
      }

      results.add(RatingAnalyzedResult(record: record, raceRating: raceRating, trendRating: trend, levelGrade: level, baseWeight: baseWeight, prevOdds: record.odds, prevPop: record.popularity));

      rollingRatings.add(raceRating);
      if (rollingRatings.length > 3) rollingRatings.removeAt(0);
    }

    // --- 高度な分析指標の計算 ---
    final currentBaseRating = getBaseRating(currentRaceName);
    bool isClassCleared = maxRt >= currentBaseRating;

    double latestTrend = results.last.trendRating;

    // 安定度計算 (標準偏差)
    String stabilityRank = 'C';
    if (results.length >= 3) {
      final recentRts = results.sublist(max(0, results.length - 5)).map((e) => e.raceRating).toList();
      double mean = recentRts.reduce((a, b) => a + b) / recentRts.length;
      double variance = recentRts.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / recentRts.length;
      double sd = sqrt(variance);
      if (sd <= 3.0) stabilityRank = 'A';
      else if (sd <= 6.0) stabilityRank = 'B';
    } else {
      stabilityRank = 'データ不足';
    }

    // 状態サイクル (モメンタム) の判定
    String momentumStatus = '平行線';
    if (results.length >= 2) {
      final last = results.last;
      final prev = results[results.length - 2];
      if (last.levelGrade == 'High') {
        momentumStatus = '反動警戒';
      } else if (last.levelGrade == 'Low' && prev.levelGrade == 'Low' && maxRt >= latestTrend + 2.0) {
        momentumStatus = '叩き一変注意';
      } else if (last.raceRating > prev.raceRating && prev.raceRating > (results.length >= 3 ? results[results.length - 3].raceRating : 0)) {
        momentumStatus = '上昇期';
      }
    }

    return HorseRatingProfile(
      horseId: horseId,
      history: results,
      latestTrend: latestTrend,
      stabilityRank: stabilityRank,
      momentumStatus: momentumStatus,
      isClassCleared: isClassCleared,
      bestRatingWeight: bestWeight,
      bestRatingMonth: bestMonth,
    );
  }
}