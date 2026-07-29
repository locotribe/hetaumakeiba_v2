// lib/logic/analysis/speed_index_calculator.dart

import 'dart:math' as math;

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_constants.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_parser.dart';

/// HorseRaceRecord のリストから HorseSpeedIndex を算出するクラス。
/// 基準タイムは tools/speed_index_fit.py が生成した SpeedIndexConstants の
/// 固定定数を用いたオフライン重回帰方式(案C)。DB蓄積量に依存せず、
/// 新規・既存ユーザーで同一の指数になる。
class SpeedIndexCalculator {
  /// 指定馬の過去成績レコードから HorseSpeedIndex を算出して返す。
  static HorseSpeedIndex calculate(
    String horseId,
    List<HorseRaceRecord> records,
  ) {
    final entries = <_RaceIndexEntry>[];
    for (final record in records) {
      final index = _calcSingleRaceIndex(record);
      if (index == null) continue;
      final raceDate = _parseRecordDate(record.date);
      if (raceDate == null) continue;
      entries.add(_RaceIndexEntry(date: raceDate, index: index));
    }

    if (entries.isEmpty) {
      return HorseSpeedIndex(
        horseId: horseId,
        bestIndex: 0.0,
        recentAvgIndex: 0.0,
        trend: 0.0,
        confidence: 0.0,
        sampleCount: 0,
        calculatedAt: DateTime.now().toIso8601String(),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date)); // 日付降順(新しい順)

    final bestIndex =
        entries.map((e) => e.index).reduce((a, b) => a > b ? a : b);
    final recentAvgIndex = _weightedRecentAverage(entries);

    double trend;
    if (entries.length <= 3) {
      trend = 0.0;
    } else {
      final recent3Avg = _average(entries.sublist(0, 3).map((e) => e.index));
      final restAvg = _average(entries.sublist(3).map((e) => e.index));
      trend = recent3Avg - restAvg;
    }

    return HorseSpeedIndex(
      horseId: horseId,
      bestIndex: bestIndex,
      recentAvgIndex: recentAvgIndex,
      trend: trend,
      // [一時] confidenceは暫定固定値。本実装はフェーズ4で対応予定 (v.2026.7.28+26072811)
      confidence: 0.5,
      sampleCount: entries.length,
      calculatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// 1走分のレース記録からスピード指数を算出する。
  /// 障害・距離パース不能・タイムパース不能・日付パース不能・未知競馬場の走は
  /// null を返しスキップする。
  static double? _calcSingleRaceIndex(HorseRaceRecord record) {
    final distanceResult = parseDistance(record.distance);
    if (distanceResult == null || distanceResult.surface == '障') return null;

    final timeSeconds = parseRaceTime(record.time);
    if (timeSeconds == null) return null;

    if (record.date.length < 4) return null;
    final year = int.tryParse(record.date.substring(0, 4));
    if (year == null) return null;

    final meters = distanceResult.meters;
    final distanceDelta = (meters - 1800) / 100.0;
    final venueName = parseVenue(record.venue)?.track;
    final normalizedCondition =
        _normalizeTrackCondition(record.trackCondition);

    final resolved = _resolveSurfaceParams(
      surface: distanceResult.surface,
      meters: meters,
      distanceDelta: distanceDelta,
      year: year,
      venueName: venueName,
      normalizedCondition: normalizedCondition,
    );
    if (resolved == null) return null;

    return (resolved.baseTime - timeSeconds) * resolved.distanceCoefficient +
        SpeedIndexConstants.kBaseIndex;
  }

  /// 馬場種別に応じた回帰定数群から基準タイムと距離係数を算出する。
  /// [修正] 競馬場名がVenueOffsetマップに無い(またはvenueNameがnull)場合は
  /// 東京基準(0.0)を代用せず無効走としてnullを返す。地方・海外開催などJRA外の
  /// コースを東京基準で計算すると外れ値になり集約値を汚染するため (v.2026.7.28+26072811)
  /// 馬場状態補正はマップに該当キーが無い場合0.0として継続する。
  static ({double baseTime, double distanceCoefficient})?
      _resolveSurfaceParams({
    required String surface,
    required int meters,
    required double distanceDelta,
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

    // [修正] 未知競馬場(VenueOffsetマップに無い名称)は無効走としてスキップする。
    // 東京は0.0という有効値としてマップに含まれるため除外されない (v.2026.7.28+26072811)
    if (venueName == null || !venueOffsetTable.containsKey(venueName)) {
      return null;
    }
    final venueOffset = venueOffsetTable[venueName]!;
    final condOffset = _lookupOffset(condOffsetTable, normalizedCondition);

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

  /// 馬場状態の略記("良""稍""重""不")を正規化する。既に全形("稍重""不良")ならそのまま返す。
  static String _normalizeTrackCondition(String raw) {
    final trimmed = raw.trim();
    switch (trimmed) {
      case '良':
        return '良';
      case '稍':
        return '稍重';
      case '重':
        return '重';
      case '不':
        return '不良';
      case '稍重':
        return '稍重';
      case '不良':
        return '不良';
      default:
        return trimmed;
    }
  }

  /// "YYYY/MM/DD" 形式の日付文字列を DateTime へ変換する。変換不能な場合は null を返す。
  static DateTime? _parseRecordDate(String date) {
    final parts = date.split('/');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// 直近5走(不足時はその数)を新しいほど重く(公比0.8の等比減衰)加重平均する。
  static double _weightedRecentAverage(List<_RaceIndexEntry> sortedEntries) {
    const decayRatio = 0.8;
    final windowSize = sortedEntries.length < 5 ? sortedEntries.length : 5;
    double weightedSum = 0.0;
    double weightTotal = 0.0;
    for (int i = 0; i < windowSize; i++) {
      final weight = math.pow(decayRatio, i).toDouble();
      weightedSum += sortedEntries[i].index * weight;
      weightTotal += weight;
    }
    return weightedSum / weightTotal;
  }

  static double _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}

/// 日付付き1走分の指数を保持する内部データクラス。
class _RaceIndexEntry {
  final DateTime date;
  final double index;
  _RaceIndexEntry({required this.date, required this.index});
}
