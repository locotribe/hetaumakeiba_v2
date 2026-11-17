// lib/logic/analysis/track_rain_timeline.dart

// [追加] 馬場予測の天気材料の見直し Step1: 馬場予測に使う「起点の測定から発走までの1時間ごとの雨」を組み立てる純粋ロジック。今までの雨はアメダスの実測（10分値を1時間にまとめる・欠けは予備の地点で埋める）、その先と実測の欠けは Open-Meteo の時間別の値を使う。DB・画面・通信には触れない (v.2026.11.18+26111801)

import 'package:hetaumakeiba_v2/logic/analysis/track_moisture_model.dart';

/// レースの日付（'2026年11月15日' / '2026/11/15' など）と発走時刻（'15:40'）から発走の日時を作る。
/// 発走時刻が読めなければ 15:00。日付が読めなければ null。
DateTime? parseRaceStartDateTime(String raceDate, String? startTime) {
  final match = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raceDate);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  int hour = 15;
  int minute = 0;
  final parts = (startTime ?? '').split(':');
  if (parts.length >= 2) {
    hour = int.tryParse(parts[0].trim()) ?? 15;
    minute = int.tryParse(parts[1].trim()) ?? 0;
  }
  return DateTime(year, month, day, hour, minute);
}

/// アメダスの最新時刻（latest_time.txt の '2026-11-17T22:40:00+09:00'）を日本時間の壁時計の値で読む。読めなければ null。
DateTime? parseAmedasLatestTime(String text) {
  final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})').firstMatch(text.trim());
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
  );
}

/// アメダスの1ファイル（3時間ぶんの10分値。キー 'yyyyMMddHHmmss'）から10分ごとの雨を読む。
/// 値は「その時刻までの10分間の雨（mm）」。欠測・品質の印が0以外・雨を測らない地点は null。
Map<DateTime, double?> parseAmedasTenMinutePrecip(Map<String, dynamic> json) {
  final out = <DateTime, double?>{};
  json.forEach((key, value) {
    if (key.length != 14 || int.tryParse(key) == null) return;
    final time = DateTime(
      int.parse(key.substring(0, 4)),
      int.parse(key.substring(4, 6)),
      int.parse(key.substring(6, 8)),
      int.parse(key.substring(8, 10)),
      int.parse(key.substring(10, 12)),
    );
    double? mm;
    if (value is Map) {
      final p = value['precipitation10m'];
      if (p is List && p.length >= 2 && p[0] is num && p[1] == 0) {
        mm = (p[0] as num).toDouble();
      }
    }
    out[time] = mm;
  });
  return out;
}

/// 時刻を時の単位に切り捨てる。
DateTime floorToHour(DateTime t) => DateTime(t.year, t.month, t.day, t.hour);

/// 10分値を1時間ごとにまとめた結果。
class AmedasHourly {
  /// 1時間の終わりの時刻 → その1時間の雨（mm）。10分値が1つでも欠け、予備でも埋まらなければ null。
  final Map<DateTime, double?> hours;

  /// 予備の地点で埋めた10分の数
  final int backupSlots;

  const AmedasHourly({required this.hours, required this.backupSlots});
}

/// [from] の後に終わり、[observedUntil] までに終わる1時間ごとに、10分値6つを合計する。
/// 10分値は第1の地点 [primary] を使い、欠けたところは予備の地点 [backup] で埋める。
AmedasHourly hourlyFromTenMinute({
  required Map<DateTime, double?> primary,
  Map<DateTime, double?> backup = const {},
  required DateTime from,
  required DateTime observedUntil,
}) {
  final hours = <DateTime, double?>{};
  int backupSlots = 0;
  var end = floorToHour(from).add(const Duration(hours: 1));
  while (!end.isAfter(observedUntil)) {
    double sum = 0;
    bool missing = false;
    for (int i = 5; i >= 0; i--) {
      final slot = end.subtract(Duration(minutes: 10 * i));
      final p = primary[slot];
      if (p != null) {
        sum += p;
        continue;
      }
      final b = backup[slot];
      if (b != null) {
        sum += b;
        backupSlots++;
        continue;
      }
      missing = true;
    }
    hours[end] = missing ? null : double.parse(sum.toStringAsFixed(1));
    end = end.add(const Duration(hours: 1));
  }
  return AmedasHourly(hours: hours, backupSlots: backupSlots);
}

/// ピンポイント天気（OpenMeteoService の戻り値）の 'hourlyPrecip'（[{'time': '2026-11-15T15:00', 'mm': 0.6}, …]）を読む。
/// 時刻はその1時間の終わり（Open-Meteo の降水量は直前1時間の合計）。無ければ空。
Map<DateTime, double> parseOpenMeteoHourlyPrecip(dynamic raw) {
  final out = <DateTime, double>{};
  if (raw is! List) return out;
  for (final item in raw) {
    if (item is! Map) continue;
    final time = DateTime.tryParse('${item['time']}');
    final mm = item['mm'];
    if (time == null || mm is! num) continue;
    out[time] = mm.toDouble();
  }
  return out;
}

/// 馬場予測に渡す雨のまとめ（起点の測定1つと発走の日時ごと）。
class TrackRainInput {
  /// 起点にした馬場の測定のID（保存した分が同じ起点のものか確かめるため）
  final int baselineId;

  /// 予測時刻（発走）
  final DateTime target;

  /// 1時間ごとの雨（古い順）。実測も予報も無かった時間は入れない。
  final List<HourlyRain> hours;

  /// アメダスの実測がある最後の時刻（取れなければ null）
  final DateTime? observedUntil;

  /// Open-Meteo の時間別の雨があったか
  final bool forecastAvailable;

  /// 実測も予報も無く、0mm として扱った時間の数
  final int missingHours;

  const TrackRainInput({
    required this.baselineId,
    required this.target,
    required this.hours,
    required this.observedUntil,
    required this.forecastAvailable,
    required this.missingHours,
  });

  Map<String, dynamic> toJson() => {
        'baselineId': baselineId,
        'target': target.toIso8601String(),
        'hours': [for (final h in hours) h.toJson()],
        'observedUntil': observedUntil?.toIso8601String(),
        'forecastAvailable': forecastAvailable,
        'missingHours': missingHours,
      };

  factory TrackRainInput.fromJson(Map<String, dynamic> json) => TrackRainInput(
        baselineId: (json['baselineId'] as num).toInt(),
        target: DateTime.parse(json['target'] as String),
        hours: [
          for (final h in (json['hours'] as List? ?? const []))
            HourlyRain.fromJson(Map<String, dynamic>.from(h as Map)),
        ],
        observedUntil: json['observedUntil'] == null ? null : DateTime.parse(json['observedUntil'] as String),
        forecastAvailable: json['forecastAvailable'] == true,
        missingHours: (json['missingHours'] as num?)?.toInt() ?? 0,
      );
}

/// [from]（起点の測定のうち早いほうの時刻）の後に終わり、[target]＋30分までに終わる1時間ごとの雨を組み立てる。
/// [observedUntil] までの時間はアメダスの実測 [observed] を使い、実測が欠けた時間とその先は Open-Meteo の [forecast] を使う。
/// どちらも無い時間は入れず、[TrackRainInput.missingHours] に数える。
TrackRainInput buildTrackRainInput({
  required int baselineId,
  required DateTime from,
  required DateTime target,
  required Map<DateTime, double?> observed,
  required DateTime? observedUntil,
  required Map<DateTime, double> forecast,
}) {
  final hours = <HourlyRain>[];
  int missing = 0;
  final last = target.add(TrackMoistureModel.targetSlack);
  var end = floorToHour(from).add(const Duration(hours: 1));
  while (!end.isAfter(last)) {
    final inObserved = observedUntil != null && !end.isAfter(observedUntil);
    final obs = inObserved ? observed[end] : null;
    if (obs != null) {
      hours.add(HourlyRain(end: end, mm: obs, observed: true));
    } else if (forecast.containsKey(end)) {
      hours.add(HourlyRain(end: end, mm: forecast[end]!, observed: false));
    } else {
      missing++;
    }
    end = end.add(const Duration(hours: 1));
  }
  return TrackRainInput(
    baselineId: baselineId,
    target: target,
    hours: hours,
    observedUntil: observedUntil,
    forecastAvailable: forecast.isNotEmpty,
    missingHours: missing,
  );
}
