// lib/logic/analysis/jockey_factor_calculator.dart

import 'package:hetaumakeiba_v2/logic/horse_stats_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 展開シミュ騎手要素Step1: 騎手の強さ・相性・乗り替わり方向を、展開シミュの直線に加える小さなバイアスと棒グラフ用の値にする (v.2026.9.29+26092901)

/// 今回の騎乗の種類。
enum JockeyRideType {
  /// 前走と同じ騎手（継続騎乗）
  continued,

  /// 乗り替わり（この馬に過去に乗ったことがある騎手）
  changed,

  /// 初騎乗（この馬に乗るのが初めて）
  firstRide,

  /// 過去走なし（新馬等）・騎手ID不明など、判断できない
  unknown,
}

/// 1頭ぶんの騎手要素。棒グラフの表示と、展開シミュの動きの両方に同じ値を使う。
class HorseJockeyFactor {
  /// 騎手の強さ（0〜1。相対評価の「騎手」点÷50）
  final double strengthRatio;

  /// 騎手の統計があるか
  final bool hasStrength;

  /// 騎手の強さの算出に使ったレース数
  final int strengthSampleCount;

  /// 相性（0〜1。相対評価の「相性」点÷50。初騎乗は0）
  final double comboRatio;

  /// 相性の評価対象か（過去走が無い馬は対象外）
  final bool hasCombo;

  /// この馬とのコンビでの騎乗回数（初騎乗は0）
  final int comboRideCount;

  final JockeyRideType rideType;

  /// 乗り替わりの方向（-1〜+1）。+は前走騎手より実績が高い、-は低い。判断できないときは null
  final double? changeDirection;

  /// 直線の positionScore に加算する値。負なら前進（有利）、正なら後退（不利）
  final double positionBias;

  const HorseJockeyFactor({
    required this.strengthRatio,
    required this.hasStrength,
    required this.strengthSampleCount,
    required this.comboRatio,
    required this.hasCombo,
    required this.comboRideCount,
    required this.rideType,
    required this.changeDirection,
    required this.positionBias,
  });

  /// 騎手の棒を薄く表示すべきか（統計なし・サンプルが少ない）
  bool get strengthIsLowSample =>
      !hasStrength ||
      strengthSampleCount < JockeyFactorCalculator.lowSampleStrength;

  /// 相性の棒を薄く表示すべきか（評価対象外・コンビ騎乗が少ない）。初騎乗は「0であること」自体が情報なので薄くしない
  bool get comboIsLowSample =>
      !hasCombo ||
      (rideType != JockeyRideType.firstRide &&
          comboRideCount < JockeyFactorCalculator.lowSampleCombo);
}

class _Strength {
  final double score;
  final int count;
  const _Strength(this.score, this.count);
}

class _Draft {
  final int horseNumber;
  final bool hasStrength;
  final double strengthRatio;
  final int strengthSampleCount;
  final bool hasCombo;
  final double comboRatio;
  final int comboRideCount;
  final JockeyRideType rideType;
  final double? changeDirection;

  const _Draft({
    required this.horseNumber,
    required this.hasStrength,
    required this.strengthRatio,
    required this.strengthSampleCount,
    required this.hasCombo,
    required this.comboRatio,
    required this.comboRideCount,
    required this.rideType,
    required this.changeDirection,
  });
}

/// 騎手の強さ・相性・乗り替わり方向を計算する純粋ロジック（DB・画面に依存しない）。
class JockeyFactorCalculator {
  /// 騎手の強さの最大寄与（positionScore。1点≒16m なので約2m）
  static const double strengthMaxBias = 0.12;

  /// 相性の最大寄与（約3m）
  static const double comboMaxBias = 0.19;

  /// 乗り替わり方向の最大寄与（約2m）
  static const double changeMaxBias = 0.12;

  /// 3つの合計の上限（約5m）
  static const double totalMaxBias = 0.31;

  /// 騎手の強さ（比率）の平均との差が、この値で最大寄与になる
  static const double strengthDevScale = 0.25;

  /// 相性（比率）の平均との差が、この値で最大寄与になる
  static const double comboDevScale = 0.30;

  /// 前走騎手との強さ点の差が、この値（点）で方向が±1になる
  static const double changeDiffScale = 20.0;

  /// 騎手の統計がこの件数未満なら「サンプル少」
  static const int lowSampleStrength = 5;

  /// コンビ騎乗がこの回数未満なら「サンプル少」
  static const int lowSampleCombo = 2;

  /// 出走馬全員ぶんを計算する。キーは horseNumber.toString()。
  static Map<String, HorseJockeyFactor> calculate({
    required List<PredictionHorseDetail> horses,
    required Map<String, List<HorseRaceRecord>> allPastRecords,
    required Map<String, JockeyStats> jockeyStats,
  }) {
    final drafts = <_Draft>[];
    for (final horse in horses) {
      drafts.add(_buildDraft(
        horse,
        allPastRecords[horse.horseId] ?? const <HorseRaceRecord>[],
        jockeyStats,
      ));
    }

    final strengthMean = _mean(
        drafts.where((d) => d.hasStrength).map((d) => d.strengthRatio));
    final comboMean =
        _mean(drafts.where((d) => d.hasCombo).map((d) => d.comboRatio));

    final result = <String, HorseJockeyFactor>{};
    for (final d in drafts) {
      double sum = 0.0;
      if (d.hasStrength) {
        final double dev = (d.strengthRatio - strengthMean) / strengthDevScale;
        sum += dev.clamp(-1.0, 1.0).toDouble() * strengthMaxBias;
      }
      if (d.hasCombo) {
        final double dev = (d.comboRatio - comboMean) / comboDevScale;
        sum += dev.clamp(-1.0, 1.0).toDouble() * comboMaxBias;
      }
      final double? direction = d.changeDirection;
      if (direction != null) {
        sum += direction * changeMaxBias;
      }
      final double total =
          sum.clamp(-totalMaxBias, totalMaxBias).toDouble();

      result[d.horseNumber.toString()] = HorseJockeyFactor(
        strengthRatio: d.strengthRatio,
        hasStrength: d.hasStrength,
        strengthSampleCount: d.strengthSampleCount,
        comboRatio: d.comboRatio,
        hasCombo: d.hasCombo,
        comboRideCount: d.comboRideCount,
        rideType: d.rideType,
        changeDirection: d.changeDirection,
        // 有利(合計がプラス)=前進=positionScoreをマイナス方向へ
        positionBias: -total,
      );
    }
    return result;
  }

  static double _mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static _Draft _buildDraft(
    PredictionHorseDetail horse,
    List<HorseRaceRecord> records,
    Map<String, JockeyStats> jockeyStats,
  ) {
    final String currentId = horse.jockeyId;
    final _Strength? strength =
        currentId.isEmpty ? null : _strengthOf(jockeyStats[currentId]);

    JockeyRideType rideType = JockeyRideType.unknown;
    bool hasCombo = false;
    double comboScore = 0.0;
    int comboRideCount = 0;
    double? changeDirection;

    if (records.isNotEmpty && currentId.isNotEmpty) {
      final JockeyComboStats combo = HorseStatsAnalyzer.analyzeJockeyCombo(
        currentJockeyId: currentId,
        performanceRecords: records,
        raceResults: const {},
      );
      hasCombo = true;
      comboScore = _comboScoreOf(combo);
      comboRideCount = combo.isFirstRide ? 0 : combo.rideCount;

      // 前走騎手ID。出馬表側に無ければ過去成績の先頭（直近）走から取る
      String prevId = horse.previousJockeyId ?? '';
      if (prevId.isEmpty) {
        prevId = records.first.jockeyId;
      }

      if (prevId.isNotEmpty && prevId == currentId) {
        rideType = JockeyRideType.continued;
      } else if (combo.isFirstRide) {
        rideType = JockeyRideType.firstRide;
      } else if (prevId.isNotEmpty) {
        rideType = JockeyRideType.changed;
      } else {
        rideType = JockeyRideType.unknown;
      }

      if ((rideType == JockeyRideType.changed ||
              rideType == JockeyRideType.firstRide) &&
          prevId.isNotEmpty &&
          strength != null) {
        final _Strength? prevStrength = _strengthOf(jockeyStats[prevId]);
        if (prevStrength != null) {
          changeDirection = ((strength.score - prevStrength.score) /
                  changeDiffScale)
              .clamp(-1.0, 1.0)
              .toDouble();
        }
      }
    }

    return _Draft(
      horseNumber: horse.horseNumber,
      hasStrength: strength != null,
      strengthRatio: strength == null ? 0.0 : strength.score / 50.0,
      strengthSampleCount: strength == null ? 0 : strength.count,
      hasCombo: hasCombo,
      comboRatio: comboScore / 50.0,
      comboRideCount: comboRideCount,
      rideType: rideType,
      changeDirection: changeDirection,
    );
  }

  /// 騎手の強さ（0〜50点）。相対評価タブの「騎手」と同じ式（複製。両者は独立に保守する）。
  /// FactorStats.winRate は常に百分率なので、常に /100 して比率にする。
  static _Strength? _strengthOf(JockeyStats? stats) {
    if (stats == null) return null;
    final bool useCourse =
        stats.courseStats != null && stats.courseStats!.raceCount > 0;
    final FactorStats target =
        useCourse ? stats.courseStats! : stats.overallStats;
    if (target.raceCount <= 0) return null;

    final double winRateRatio = target.winRate / 100.0;
    final double confidence =
        0.5 + (target.raceCount / 20.0).clamp(0.0, 0.5).toDouble();
    double score = winRateRatio * 100.0 * confidence;

    if (useCourse && target.raceCount >= 5) {
      if (target.placeRate >= 30.0) {
        score += 10.0;
      } else if (target.placeRate >= 20.0) {
        score += 5.0;
      }
    }
    if (score > 50.0) score = 50.0;
    return _Strength(score, target.raceCount);
  }

  /// 相性（0〜50点）。相対評価タブの「相性」と同じ式（複製）。初騎乗は0点。
  static double _comboScoreOf(JockeyComboStats combo) {
    if (combo.isFirstRide) return 0.0;
    final double winRateRatio = combo.winRate / 100.0;
    final double winScore = winRateRatio * 40.0;
    final double countBonus =
        (combo.rideCount * 1.5).clamp(0.0, 15.0).toDouble();
    final double confidence =
        (combo.rideCount / 5.0).clamp(0.5, 1.0).toDouble();
    double score = (winScore * confidence) + countBonus;
    if (score > 50.0) score = 50.0;
    return score;
  }
}
