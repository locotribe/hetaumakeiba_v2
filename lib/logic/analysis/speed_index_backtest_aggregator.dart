// lib/logic/analysis/speed_index_backtest_aggregator.dart

// [追加] フェーズ6 スピード指数バックテスト・ハーネス §9 集計ロジック（UI非依存）。
// SpeedIndexBacktestRunner.runBatch の結果リストから、全体／距離帯別／ペース別／
// confidence帯別のΔρを算出する。UIからも実DBコピー検証スクリプトからも同じ関数を使う (v.2026.9.4)

import 'package:hetaumakeiba_v2/logic/analysis/speed_index_backtest_runner.dart';

/// confidence帯（<0.3 / 0.3-0.6 / >0.6）のラベルを返す。
String confidenceBandLabel(double meanConfidence) {
  if (meanConfidence < 0.3) return '<0.3';
  if (meanConfidence <= 0.6) return '0.3-0.6';
  return '>0.6';
}

/// 1つのグループ(全体・距離帯別・ペース別・confidence帯別の各層)についての集計値。
class SpeedIndexBacktestGroupStats {
  final String label;
  final int raceCount; // このグループに属するレース数(ρ算出可否に関わらず全数)
  final int rhoCount; // 主指標ρ(dRhoRaw)が算出できた(n>=5)レース数
  final double? meanRhoWithRaw;
  final double? meanRhoNoneRaw;
  final double? meanDRhoRaw;
  final double? positiveDRhoRawRatio; // Δρ(生スコア)>0のレース比率(rhoCount中)
  final double tairetsuDiffRatio; // 直線隊列が「あり/なし」で変化したレースの比率(raceCount中)

  SpeedIndexBacktestGroupStats({
    required this.label,
    required this.raceCount,
    required this.rhoCount,
    required this.meanRhoWithRaw,
    required this.meanRhoNoneRaw,
    required this.meanDRhoRaw,
    required this.positiveDRhoRawRatio,
    required this.tairetsuDiffRatio,
  });
}

/// 全体・距離帯別・ペース別・confidence帯別の集計結果一式。
class SpeedIndexBacktestAggregate {
  final SpeedIndexBacktestGroupStats overall;
  final Map<String, SpeedIndexBacktestGroupStats> byDistanceBand; // key: '芝 ~1400' 等
  final Map<String, SpeedIndexBacktestGroupStats> byPace; // key: 'ハイペース' 等
  final Map<String, SpeedIndexBacktestGroupStats> byConfidenceBand; // key: '<0.3' 等

  SpeedIndexBacktestAggregate({
    required this.overall,
    required this.byDistanceBand,
    required this.byPace,
    required this.byConfidenceBand,
  });
}

class SpeedIndexBacktestAggregator {
  SpeedIndexBacktestAggregator._();

  static SpeedIndexBacktestAggregate aggregate(
      List<SpeedIndexBacktestSingleRaceResult> results) {
    final overall = _statsFor('全体', results);

    final byDistanceBand = <String, List<SpeedIndexBacktestSingleRaceResult>>{};
    final byPace = <String, List<SpeedIndexBacktestSingleRaceResult>>{};
    final byConfidenceBand = <String, List<SpeedIndexBacktestSingleRaceResult>>{};

    for (final r in results) {
      final distKey = '${r.surface} ${r.distanceBand}';
      byDistanceBand.putIfAbsent(distKey, () => []).add(r);
      byPace.putIfAbsent(r.pace, () => []).add(r);
      final confKey = confidenceBandLabel(r.meanConfidence);
      byConfidenceBand.putIfAbsent(confKey, () => []).add(r);
    }

    return SpeedIndexBacktestAggregate(
      overall: overall,
      byDistanceBand: byDistanceBand
          .map((key, list) => MapEntry(key, _statsFor(key, list))),
      byPace: byPace.map((key, list) => MapEntry(key, _statsFor(key, list))),
      byConfidenceBand: byConfidenceBand
          .map((key, list) => MapEntry(key, _statsFor(key, list))),
    );
  }

  static SpeedIndexBacktestGroupStats _statsFor(
      String label, List<SpeedIndexBacktestSingleRaceResult> results) {
    final withRho = results
        .map((r) => r.dRhoRaw != null ? r : null)
        .whereType<SpeedIndexBacktestSingleRaceResult>()
        .toList();

    double? meanOf(Iterable<double> values) {
      final list = values.toList();
      if (list.isEmpty) return null;
      return list.reduce((a, b) => a + b) / list.length;
    }

    final meanRhoWithRaw = meanOf(withRho.map((r) => r.rhoWithRaw.rho!));
    final meanRhoNoneRaw = meanOf(withRho.map((r) => r.rhoNoneRaw.rho!));
    final meanDRhoRaw = meanOf(withRho.map((r) => r.dRhoRaw!));
    final positiveDRhoRawRatio = withRho.isEmpty
        ? null
        : withRho.where((r) => r.dRhoRaw! > 0).length / withRho.length;
    final tairetsuDiffRatio = results.isEmpty
        ? 0.0
        : results.where((r) => r.tairetsuDiffers).length / results.length;

    return SpeedIndexBacktestGroupStats(
      label: label,
      raceCount: results.length,
      rhoCount: withRho.length,
      meanRhoWithRaw: meanRhoWithRaw,
      meanRhoNoneRaw: meanRhoNoneRaw,
      meanDRhoRaw: meanDRhoRaw,
      positiveDRhoRawRatio: positiveDRhoRawRatio,
      tairetsuDiffRatio: tairetsuDiffRatio,
    );
  }
}
