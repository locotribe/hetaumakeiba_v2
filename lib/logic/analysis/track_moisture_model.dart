// lib/logic/analysis/track_moisture_model.dart

// [追加] 馬場予測の天気材料の見直し Step1: 起点の測定から予測時刻までの1時間ごとの雨で、含水率（芝・ダートのゴール前）とクッション値を予測する式。係数は 2018〜2026年の測定3,370組と気象庁の時間別の雨で決めた（Project「馬場予測_係数の決め直し_結果」）。DB・画面・通信には触れない (v.2026.11.18+26111801)

import 'dart:math' as math;

/// 1時間ぶんの雨。[end] はその1時間の終わりの時刻（15:00 なら 14:00〜15:00 の雨）。
/// 時刻はすべて日本時間の壁時計の値（タイムゾーンなしの DateTime）で持つ。
class HourlyRain {
  final DateTime end;
  final double mm;

  /// true: アメダスの実測 / false: Open-Meteo の値（先の予報、または実測が欠けた時間の穴埋め）
  final bool observed;

  const HourlyRain({required this.end, required this.mm, required this.observed});

  Map<String, dynamic> toJson() => {
        'end': end.toIso8601String(),
        'mm': mm,
        'obs': observed,
      };

  factory HourlyRain.fromJson(Map<String, dynamic> json) => HourlyRain(
        end: DateTime.parse(json['end'] as String),
        mm: (json['mm'] as num).toDouble(),
        observed: json['obs'] == true,
      );
}

/// 予測する値の種類。
enum TrackMeasureKind { turfMoisture, dirtMoisture, cushion }

/// 式の係数。変化 = a × (1 − exp(−Reff ÷ r0)) + d × 日数 + k × 日数 × (起点の値 − 場のふだんの値)。
/// Reff = Σ（1時間ごとの雨 × exp(−その雨から予測時刻までの時間 ÷ tau)）。
class TrackModelCoefficients {
  final double a;
  final double r0;
  final double tau;
  final double d;
  final double k;

  /// 場のふだんの値（競馬場コード '01'〜'10' → 全期間の測定の平均）
  final Map<String, double> mean;

  const TrackModelCoefficients({
    required this.a,
    required this.r0,
    required this.tau,
    required this.d,
    required this.k,
    required this.mean,
  });
}

/// 予測の結果と内訳。
class TrackPrediction {
  /// 予測の値（含水率 % またはクッション値）
  final double value;

  /// 雨による変化
  final double rainEffect;

  /// 時間による変化（乾き・ふだんの値へ戻る分）
  final double timeEffect;

  /// 起点から予測時刻までに数えた雨の合計（mm）
  final double rainMm;

  const TrackPrediction({
    required this.value,
    required this.rainEffect,
    required this.timeEffect,
    required this.rainMm,
  });
}

class TrackMoistureModel {
  /// 芝 ゴール前の含水率
  static const TrackModelCoefficients turf = TrackModelCoefficients(
    a: 3.83,
    r0: 12.2,
    tau: 13.0,
    d: -0.109,
    k: -0.168,
    mean: {
      '01': 12.8, '02': 14.5, '03': 11.9, '04': 12.5, '05': 14.9,
      '06': 11.9, '07': 13.0, '08': 9.9, '09': 10.8, '10': 9.3,
    },
  );

  /// ダート ゴール前の含水率
  static const TrackModelCoefficients dirt = TrackModelCoefficients(
    a: 10.54,
    r0: 13.2,
    tau: 57.0,
    d: -0.691,
    k: -0.172,
    mean: {
      '01': 6.0, '02': 6.3, '03': 6.8, '04': 6.4, '05': 6.3,
      '06': 6.3, '07': 6.5, '08': 5.9, '09': 7.2, '10': 7.8,
    },
  );

  /// 芝のクッション値
  static const TrackModelCoefficients cushion = TrackModelCoefficients(
    a: -1.60,
    r0: 6.1,
    tau: 5.0,
    d: 0.034,
    k: -0.140,
    mean: {
      '01': 7.5, '02': 7.3, '03': 8.9, '04': 9.4, '05': 9.3,
      '06': 9.6, '07': 9.6, '08': 10.0, '09': 9.4, '10': 9.1,
    },
  );

  /// 時間による変化を数える日数の上限（係数を決めた範囲が6日以内のため）
  static const double maxDays = 6.0;

  /// 予測時刻のあとに終わる雨をどこまで数えるか（係数を決めたときと同じ30分）
  static const Duration targetSlack = Duration(minutes: 30);

  /// 含水率の測定時刻（JRA の一覧の代表値）。[前日（金曜など）, 開催日]
  static const Map<String, List<String>> moistureTimes = {
    '01': ['10:00', '04:00'],
    '02': ['09:20', '05:40'],
    '03': ['10:00', '06:00'],
    '04': ['10:30', '05:30'],
    '05': ['08:30', '05:30'],
    '06': ['10:30', '06:00'],
    '07': ['09:30', '05:30'],
    '08': ['10:30', '06:00'],
    '09': ['10:00', '05:00'],
    '10': ['10:30', '05:00'],
  };

  /// クッション値の測定時刻（JRA の一覧の代表値）。[前日（金曜など）, 開催日]
  static const Map<String, List<String>> cushionTimes = {
    '01': ['09:30', '08:20'],
    '02': ['09:20', '08:20'],
    '03': ['10:00', '07:00'],
    '04': ['10:30', '07:00'],
    '05': ['09:00', '07:00'],
    '06': ['10:30', '07:00'],
    '07': ['09:30', '06:30'],
    '08': ['10:30', '07:00'],
    '09': ['10:00', '07:30'],
    '10': ['10:30', '08:00'],
  };

  static TrackModelCoefficients coefficientsOf(TrackMeasureKind kind) {
    switch (kind) {
      case TrackMeasureKind.turfMoisture:
        return turf;
      case TrackMeasureKind.dirtMoisture:
        return dirt;
      case TrackMeasureKind.cushion:
        return cushion;
    }
  }

  /// 馬場の測定のID（YYYYCCKKDDNN）から、開催日の測定かを返す（日次 DD が 00 以外なら開催日）。
  static bool isRaceDayRecord(int trackConditionId) {
    final s = trackConditionId.toString();
    if (s.length < 10) return false;
    return s.substring(8, 10) != '00';
  }

  /// 測定の時刻。[date] は 'YYYY-MM-DD'。表に無い競馬場は 前日 10:00・開催日 06:00（クッション値は 前日 10:00・開催日 07:00）。
  /// 日付が読めなければ null。
  static DateTime? measurementTime({
    required String venueCode,
    required String date,
    required bool isRaceDay,
    bool cushion = false,
  }) {
    final day = DateTime.tryParse(date);
    if (day == null) return null;
    final table = cushion ? cushionTimes : moistureTimes;
    final fallback = cushion
        ? (isRaceDay ? '07:00' : '10:00')
        : (isRaceDay ? '06:00' : '10:00');
    final time = table[venueCode]?[isRaceDay ? 1 : 0] ?? fallback;
    final parts = time.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// [rains] のうち、起点の時刻より後に終わり、予測時刻＋30分までに終わる時間だけを返す。
  static List<HourlyRain> rainsInWindow(List<HourlyRain> rains, DateTime baseTime, DateTime target) {
    final last = target.add(targetSlack);
    return rains.where((r) => r.end.isAfter(baseTime) && !r.end.isAfter(last)).toList();
  }

  /// 起点の値 [base]（測定時刻 [baseTime]）から、予測時刻 [target] の値を出す。
  /// [venueCode] は '01'〜'10'。表に無ければ「場のふだんの値」は起点の値として扱う（戻る分は0）。
  static TrackPrediction predict({
    required TrackMeasureKind kind,
    required String venueCode,
    required double base,
    required DateTime baseTime,
    required DateTime target,
    required List<HourlyRain> rains,
  }) {
    final c = coefficientsOf(kind);
    final used = rainsInWindow(rains, baseTime, target);

    double rainMm = 0;
    double reff = 0;
    for (final r in used) {
      rainMm += r.mm;
      final ageHours = math.max(0.0, target.difference(r.end).inMinutes / 60.0);
      reff += r.mm * math.exp(-ageHours / c.tau);
    }

    final hours = target.difference(baseTime).inMinutes / 60.0;
    final days = (hours / 24.0).clamp(0.0, maxDays).toDouble();
    final mean = c.mean[venueCode] ?? base;

    final rainEffect = c.a * (1 - math.exp(-reff / c.r0));
    final timeEffect = c.d * days + c.k * days * (base - mean);
    final value = math.max(0.0, base + rainEffect + timeEffect);

    return TrackPrediction(
      value: value,
      rainEffect: rainEffect,
      timeEffect: timeEffect,
      rainMm: rainMm,
    );
  }
}
