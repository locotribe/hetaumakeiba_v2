// lib/logic/analysis/early_position_calculator.dart
// [追加] 展開シミュ骨格整理Step1: 「前に行く力」を、過去走の最初のコーナーの
// 通過順位率から連続値1本で求める純粋ロジック。DB / I/O / UI に触れない (v.2026.10.9+26100905)

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 1頭分の「前に行く力」。
class HorseEarlyPosition {
  /// 展開シミュのテン位置のスコア(小さいほど前)。1.0(先頭)〜4.5(最後方)。
  final double score;

  /// [score] を 0.0(先頭)〜1.0(最後方) に直した値。
  final double rate;

  /// 0.0〜1.0。有効な過去走が少ないほど小さい。
  final double confidence;

  /// 計算に使えた過去走の数。
  final int sampleCount;

  const HorseEarlyPosition({
    required this.score,
    required this.rate,
    required this.confidence,
    required this.sampleCount,
  });

  /// 棒グラフ「テン」の値(0.0〜1.0。前に行く馬ほど大きい)。
  double get barValue => (1.0 - rate).clamp(0.0, 1.0).toDouble();
}

class EarlyPositionCalculator {
  EarlyPositionCalculator._();

  /// 計算に使う最大走数。
  static const int maxRecords = 5;

  /// 近走の重み減衰(末脚・着差ベースの力と同じ)。
  static const double recencyDecay = 0.8;

  /// 信頼度が1.0になる有効走数。
  static const int fullSampleCount = 3;

  /// いちばん前(通過順位率0.0)のスコア。逃げの脚質スコアと同じ。
  static const double frontScore = 1.0;

  /// いちばん後ろ(通過順位率1.0)のスコア。追込の脚質スコアと同じ。
  static const double backScore = 4.5;

  /// 脚質が分からない馬のスコア。
  static const double unknownStyleScore = 2.5;

  /// 過去走(新しい順)と脚質から「前に行く力」を求める。
  /// 有効な過去走が少ないほど、脚質割合から作るスコアに近づける。
  static HorseEarlyPosition calculate(
    List<HorseRaceRecord> records, {
    Map<String, double> styleDistribution = const {},
    String? primaryStyle,
  }) {
    final double styleBased = styleScore(styleDistribution, primaryStyle);

    double totalWeighted = 0.0;
    double totalWeight = 0.0;
    double weight = 1.0;
    int used = 0;
    for (final record in records.take(maxRecords)) {
      final double? rate = record.distance.trim().startsWith('障')
          ? null
          : firstCornerRate(record.cornerPassage, record.numberOfHorses);
      if (rate == null) {
        weight *= recencyDecay;
        continue;
      }
      totalWeighted += rate * weight;
      totalWeight += weight;
      weight *= recencyDecay;
      used++;
    }

    if (used == 0 || totalWeight <= 0.0) {
      return HorseEarlyPosition(
        score: styleBased,
        rate: rateOfScore(styleBased),
        confidence: 0.0,
        sampleCount: 0,
      );
    }

    final double averageRate = totalWeighted / totalWeight;
    final double confidence =
        (used / fullSampleCount).clamp(0.0, 1.0).toDouble();
    final double recordScore =
        frontScore + (backScore - frontScore) * averageRate;
    final double score =
        confidence * recordScore + (1.0 - confidence) * styleBased;
    return HorseEarlyPosition(
      score: score,
      rate: rateOfScore(score),
      confidence: confidence,
      sampleCount: used,
    );
  }

  /// 最初のコーナーの通過順位率(0.0=先頭, 1.0=最後方)。取得できなければ null。
  /// [cornerPassage] は "3-3-2-1" 形式。最初の数字を使う。
  static double? firstCornerRate(String cornerPassage, String numberOfHorses) {
    final int? count = int.tryParse(numberOfHorses.trim());
    if (count == null || count < 2) return null;

    int? first;
    for (final part in cornerPassage.split('-')) {
      final int? value = int.tryParse(part.trim());
      if (value != null) {
        first = value;
        break;
      }
    }
    if (first == null || first <= 0) return null;

    return ((first - 1) / (count - 1)).clamp(0.0, 1.0).toDouble();
  }

  /// 脚質割合から作るスコア(従来の展開シミュの初期位置と同じ式)。
  /// 割合が無ければ主脚質から決める。
  static double styleScore(
    Map<String, double> styleDistribution,
    String? primaryStyle,
  ) {
    final double nigeRate = styleDistribution['逃げ'] ?? 0.0;
    final double senkoRate = styleDistribution['先行'] ?? 0.0;
    final double sashiRate = styleDistribution['差し'] ?? 0.0;
    final double oikomiRate = styleDistribution['追込'] ?? 0.0;

    if ((nigeRate + senkoRate + sashiRate + oikomiRate) > 0) {
      return (nigeRate * 1.0) +
          (senkoRate * 2.0) +
          (sashiRate * 3.5) +
          (oikomiRate * 4.5);
    }

    switch (primaryStyle) {
      case '逃げ':
        return 1.0;
      case '先行':
        return 2.0;
      case '差し':
        return 3.0;
      case '追込':
        return 4.0;
      default:
        return unknownStyleScore;
    }
  }

  /// スコアを 0.0(先頭)〜1.0(最後方) の率に直す。
  static double rateOfScore(double score) {
    return ((score - frontScore) / (backScore - frontScore))
        .clamp(0.0, 1.0)
        .toDouble();
  }
}
