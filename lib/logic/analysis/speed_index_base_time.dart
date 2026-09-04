// lib/logic/analysis/speed_index_base_time.dart

// [追加] フェーズ7 ステップ1: SpeedIndexCalculator._resolveSurfaceParams が
// 保持していた基準タイム・距離係数算出ロジックを共有ヘルパーへ抽出したもの。
// DailyTrackVariantResolver からも同一ロジックで基準タイムを算出するために使う。
// 数値・挙動は抽出前と完全に同一(純粋関数・DBアクセスなし) (v.2026.9.4)

import 'package:hetaumakeiba_v2/logic/analysis/speed_index_constants.dart';

/// 案C(オフライン重回帰)の固定定数から基準タイム・距離係数を算出する共有ヘルパー。
class SpeedIndexBaseTime {
  SpeedIndexBaseTime._();

  /// 馬場種別に応じた回帰定数群から基準タイムと距離係数を算出する。
  /// 未知サーフェス、または venueName が VenueOffset マップに無い場合は null を返す。
  static ({double baseTime, double distanceCoefficient})? resolve({
    required String surface,
    required int meters,
    required int year,
    required String? venueName,
    required String normalizedCondition,
  }) {
    final double baseConst;
    final double dc;
    final double dc2;
    final double yearTrend;
    final Map<String, double> venueOffsetTable;
    final Map<String, double> condOffsetTable;
    final List<List<num>> distCoefTable;

    if (surface == '芝') {
      baseConst = SpeedIndexConstants.turfConst;
      dc = SpeedIndexConstants.turfDc;
      dc2 = SpeedIndexConstants.turfDc2;
      yearTrend = SpeedIndexConstants.turfYearTrend;
      venueOffsetTable = SpeedIndexConstants.turfVenueOffset;
      condOffsetTable = SpeedIndexConstants.turfCondOffset;
      distCoefTable = SpeedIndexConstants.turfDistCoef;
    } else if (surface == 'ダ') {
      baseConst = SpeedIndexConstants.dirtConst;
      dc = SpeedIndexConstants.dirtDc;
      dc2 = SpeedIndexConstants.dirtDc2;
      yearTrend = SpeedIndexConstants.dirtYearTrend;
      venueOffsetTable = SpeedIndexConstants.dirtVenueOffset;
      condOffsetTable = SpeedIndexConstants.dirtCondOffset;
      distCoefTable = SpeedIndexConstants.dirtDistCoef;
    } else {
      return null;
    }

    // 未知競馬場(VenueOffsetマップに無い名称)は無効走としてnullを返す。
    // 東京は0.0という有効値としてマップに含まれるため除外されない (v.2026.7.28+26072811から継承)
    if (venueName == null || !venueOffsetTable.containsKey(venueName)) {
      return null;
    }
    final venueOffset = venueOffsetTable[venueName]!;
    final condOffset = _lookupOffset(condOffsetTable, normalizedCondition);

    final distanceDelta = (meters - 1800) / 100.0;
    final baseTime = baseConst +
        dc * distanceDelta +
        dc2 * distanceDelta * distanceDelta +
        yearTrend * (year - 2023) +
        venueOffset +
        condOffset;

    final distanceCoefficient = _distanceCoefficient(distCoefTable, meters);

    return (baseTime: baseTime, distanceCoefficient: distanceCoefficient);
  }

  /// マップに該当キーが無い場合は補正0.0を返す。
  static double _lookupOffset(Map<String, double> table, String? key) {
    if (key == null) return 0.0;
    return table[key] ?? 0.0;
  }

  /// distCoef([下限, 上限, 係数]のリスト)から、上限未満で一致する距離帯の係数を返す。
  static double _distanceCoefficient(List<List<num>> distCoef, int meters) {
    for (final band in distCoef) {
      final lower = band[0];
      final upper = band[1];
      if (meters >= lower && meters < upper) {
        return band[2].toDouble();
      }
    }
    // 定義範囲外(理論上到達しない: 最終帯の上限が9999のため)は末尾の係数を採用
    return distCoef.last[2].toDouble();
  }
}
