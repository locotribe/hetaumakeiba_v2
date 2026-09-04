// lib/logic/analysis/speed_index_calculator.dart

import 'dart:math' as math;

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_base_time.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_constants.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_parser.dart';

/// HorseRaceRecord のリストから HorseSpeedIndex を算出するクラス。
/// 基準タイムは tools/speed_index_fit.py が生成した SpeedIndexConstants の
/// 固定定数を用いたオフライン重回帰方式(案C)。DB蓄積量に依存せず、
/// 新規・既存ユーザーで同一の指数になる。
class SpeedIndexCalculator {
  // ---- confidence算出用の調整可能な定数 (フェーズ4) ----
  // confidence = sampleFactor * recencyFactor * consistencyFactor の3因子積。
  // 各floor/閾値の調整はここでのみ行えばよい。
  static const double kSampleKappa = 2.5;
  static const int kFreshDays = 90;
  static const int kStaleDays = 365;
  static const double kRecencyFloor = 0.6;
  static const double kTightSd = 5.0;
  static const double kWideSd = 25.0;
  static const double kConsistencyFloor = 0.7;

  /// 指定馬の過去成績レコードから HorseSpeedIndex を算出して返す。
  /// [asOf] は予想対象レースの日付(久々判定の基準)。null なら久々factorは
  /// 中立(1.0)として扱う。
  static HorseSpeedIndex calculate(
    String horseId,
    List<HorseRaceRecord> records, {
    DateTime? asOf,
  }) {
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

    final sampleFactor = _sampleFactor(entries.length);
    final recencyFactor = _recencyFactor(entries.first.date, asOf);
    final consistencyFactor =
        _consistencyFactor(entries.map((e) => e.index).toList());
    final confidence =
        (sampleFactor * recencyFactor * consistencyFactor).clamp(0.0, 1.0);

    return HorseSpeedIndex(
      horseId: horseId,
      bestIndex: bestIndex,
      recentAvgIndex: recentAvgIndex,
      trend: trend,
      confidence: confidence,
      sampleCount: entries.length,
      calculatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// sampleFactor: 有効走数が多いほど高い(信頼度算出の主ドライバ)。
  /// 1-exp(-n/kSampleKappa) (目安: 1走≈0.33, 2≈0.55, 3≈0.70, 5≈0.86, 8≈0.96)
  static double _sampleFactor(int sampleCount) {
    return 1.0 - math.exp(-sampleCount / kSampleKappa);
  }

  /// recencyFactor: asOfがnullなら中立1.0。直近有効走からの経過日数が
  /// kFreshDays以内なら1.0、kStaleDays以上ならkRecencyFloor、間は線形補間。
  static double _recencyFactor(DateTime latestRaceDate, DateTime? asOf) {
    if (asOf == null) return 1.0;
    final days = asOf.difference(latestRaceDate).inDays.abs();
    if (days <= kFreshDays) return 1.0;
    if (days >= kStaleDays) return kRecencyFloor;
    final ratio = (days - kFreshDays) / (kStaleDays - kFreshDays);
    return 1.0 - ratio * (1.0 - kRecencyFloor);
  }

  /// consistencyFactor: 1走指数の標準偏差(母集団SD)が小さいほど高い。
  /// 有効走2件未満はSD算出不可のため中立1.0を返す(sampleFactorが既に抑制)。
  /// spreadがkTightSd以下なら1.0、kWideSd以上ならkConsistencyFloor、間は線形補間。
  static double _consistencyFactor(List<double> indices) {
    if (indices.length < 2) return 1.0;
    final mean = _average(indices);
    final variance = indices
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        indices.length;
    final spread = math.sqrt(variance);
    if (spread <= kTightSd) return 1.0;
    if (spread >= kWideSd) return kConsistencyFloor;
    final ratio = (spread - kTightSd) / (kWideSd - kTightSd);
    return 1.0 - ratio * (1.0 - kConsistencyFloor);
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
    final venueName = parseVenue(record.venue)?.track;
    final normalizedCondition =
        _normalizeTrackCondition(record.trackCondition);

    final resolved = _resolveSurfaceParams(
      surface: distanceResult.surface,
      meters: meters,
      year: year,
      venueName: venueName,
      normalizedCondition: normalizedCondition,
    );
    if (resolved == null) return null;

    return (resolved.baseTime - timeSeconds) * resolved.distanceCoefficient +
        SpeedIndexConstants.kBaseIndex;
  }

  /// 馬場種別に応じた回帰定数群から基準タイムと距離係数を算出する。
  /// [修正] フェーズ7ステップ1: 算出ロジック本体は共有ヘルパー SpeedIndexBaseTime
  /// へ抽出し、ここでは委譲するのみ(数値・挙動は完全に不変) (v.2026.9.4)
  static ({double baseTime, double distanceCoefficient})?
      _resolveSurfaceParams({
    required String surface,
    required int meters,
    required int year,
    required String? venueName,
    required String normalizedCondition,
  }) {
    return SpeedIndexBaseTime.resolve(
      surface: surface,
      meters: meters,
      year: year,
      venueName: venueName,
      normalizedCondition: normalizedCondition,
    );
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
