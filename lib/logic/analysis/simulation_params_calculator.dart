// lib/logic/analysis/simulation_params_calculator.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';

/// HorseRaceRecord のリストから HorseSimulationParams を算出するクラス。
/// スクレイピング変更不要で既存DBから即時計算できる指数のみを扱う。
class SimulationParamsCalculator {
  /// 指定馬の過去成績レコードから各シミュレーション指数を算出して返す。
  static HorseSimulationParams calculate(
    String horseId,
    List<HorseRaceRecord> records,
  ) {
    final legStyle = LegStyleAnalyzer.getRunningStyle(records).primaryStyle;
    final tenAccelIndex = _calcTenAccelIndex(records);
    final finishingPower = _calcFinishingPower(records);
    final staminaIndex = _calcStaminaIndex(records);

    return HorseSimulationParams(
      horseId: horseId,
      tenAccelIndex: tenAccelIndex,
      finishingPower: finishingPower,
      staminaIndex: staminaIndex,
      legStyle: legStyle,
      calculatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// テン加速指数: 1コーナー通過順位率（位置/頭数）の逆数の平均。
  /// 値が大きいほどスタート後すぐ前に出る馬。
  static double _calcTenAccelIndex(List<HorseRaceRecord> records) {
    final validRates = <double>[];
    for (final r in records) {
      final positions = r.cornerPassage
          .split('-')
          .map((p) => int.tryParse(p))
          .toList();
      final horseCount = int.tryParse(r.numberOfHorses);
      if (horseCount == null ||
          horseCount == 0 ||
          positions.isEmpty ||
          positions[0] == null) {
        continue;
      }
      validRates.add(positions[0]! / horseCount);
    }
    if (validRates.isEmpty) return 0.5;
    final avgRate = validRates.reduce((a, b) => a + b) / validRates.length;
    // 前にいるほど (rate小) index高
    return (1.0 - avgRate).clamp(0.0, 1.0);
  }

  /// 終い瞬発力: 最終コーナー通過順位から着順への改善量（頭数正規化）の平均。
  /// 値が大きいほど直線で順位を上げる馬。
  static double _calcFinishingPower(List<HorseRaceRecord> records) {
    final validGains = <double>[];
    for (final r in records) {
      final positions = r.cornerPassage
          .split('-')
          .map((p) => int.tryParse(p))
          .toList();
      final horseCount = int.tryParse(r.numberOfHorses);
      final rank = int.tryParse(r.rank);
      if (horseCount == null ||
          horseCount == 0 ||
          positions.isEmpty ||
          positions.last == null ||
          rank == null) {
        continue;
      }
      // (最終コーナー順位 - 着順) / 頭数: 正の値ほど直線で順位を上げた
      final gain = (positions.last! - rank) / horseCount;
      validGains.add(gain);
    }
    if (validGains.isEmpty) return 0.5;
    final avgGain =
        validGains.reduce((a, b) => a + b) / validGains.length;
    // avgGain の範囲 [-1, 1] を [0, 1] へ線形変換
    return ((avgGain + 1.0) / 2.0).clamp(0.0, 1.0);
  }

  /// スタミナ指数: 長距離(2000m以上)での複勝率を重視した合成指数。
  /// 長距離出走がない場合は全体複勝率をベースに中間値を返す。
  static double _calcStaminaIndex(List<HorseRaceRecord> records) {
    int totalCount = 0;
    int totalPlace = 0;
    int longDistCount = 0;
    int longDistPlace = 0;

    for (final r in records) {
      final rank = int.tryParse(r.rank);
      if (rank == null) continue;
      final dist = _extractDistance(r.distance);
      if (dist == null) continue;

      totalCount++;
      if (rank <= 3) totalPlace++;

      if (dist >= 2000) {
        longDistCount++;
        if (rank <= 3) longDistPlace++;
      }
    }

    if (totalCount == 0) return 0.5;

    final overallPlaceRate = totalPlace / totalCount;
    if (longDistCount == 0) {
      // 長距離出走なし: 全体複勝率から [0.25, 0.75] の中間値を返す
      return (overallPlaceRate * 0.5 + 0.25).clamp(0.0, 1.0);
    }

    final longPlaceRate = longDistPlace / longDistCount;
    return (longPlaceRate * 0.7 + overallPlaceRate * 0.3).clamp(0.0, 1.0);
  }

  /// 距離文字列から数値部分を抽出する。(例: "芝1800" → 1800, "障3380" → 3380)
  static int? _extractDistance(String distanceStr) {
    final match = RegExp(r'\d+').firstMatch(distanceStr);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }
}
