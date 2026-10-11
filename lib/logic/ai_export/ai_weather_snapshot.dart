// lib/logic/ai_export/ai_weather_snapshot.dart

// [追加] AI分析データ 天気・コース追加 Step2: ピンポイント天気（OpenMeteoService.fetchDetailedWeather の戻り値）と馬場の測定から、AI分析用データに書く天気・馬場予測の要約を作る純粋ロジック。馬場予測はレース情報タブと同じ WeatherAnalyzer の計算を同じ引数で呼ぶ（前回予測との比較は使わない）。風速・突風は Open-Meteo の既定単位 km/h のまま持ち、m/s に換算した値も出す。DB・画面・通信には触れない (v.2026.10.11+26101102)

import 'package:hetaumakeiba_v2/logic/analysis/weather_analyzer.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

/// 発走から1時間を過ぎたか（天気を取り直さない時刻か）。
/// 出馬表ページ（shutuba_table_page.dart の _isWeatherLocked）と同じ規則。日付が読めないときは true。
bool isAiWeatherLocked({
  required String raceDate,
  String? startTime,
  required DateTime now,
}) {
  try {
    final dateMatch =
        RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raceDate);
    if (dateMatch == null) return true;
    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);

    final timeParts = (startTime ?? '15:00').split(':');
    int hour = 15;
    int minute = 0;
    if (timeParts.length >= 2) {
      hour = int.tryParse(timeParts[0]) ?? 15;
      minute = int.tryParse(timeParts[1]) ?? 0;
    }
    final raceDateTime = DateTime(year, month, day, hour, minute);
    final lockTime = raceDateTime.add(const Duration(hours: 1));
    return now.isAfter(lockTime);
  } catch (_) {
    return true;
  }
}

/// km/h を m/s にする。
double aiKmhToMs(double kmh) => kmh / 3.6;

/// 絵文字を取り除く（「➡」は「→」にする）。各行の前後の空白も取る。改行は残す。
String aiStripEmoji(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune == 0x27A1) {
      buffer.write('→');
      continue;
    }
    final isEmoji = rune > 0xFFFF ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        rune == 0xFE0F ||
        rune == 0x200D;
    if (!isEmoji) buffer.writeCharCode(rune);
  }
  return buffer
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .trim();
}

double? _toDouble(dynamic value) => value is num ? value.toDouble() : null;

int? _toInt(dynamic value) => value is num ? value.round() : null;

/// 発走時刻の予報。
class AiRaceTimeWeather {
  final String weatherText;
  final double? temperature;
  final int? humidity;
  final int? precipitationProbability;
  final double? precipitation;

  /// 風速（km/h。Open-Meteo の既定単位）
  final double? windSpeedKmh;
  final String? windDirectionText;

  /// 突風（km/h）
  final double? gustsKmh;
  final double? apparentTemperature;

  /// 日射（W/m²）
  final double? radiation;

  /// 蒸発散量（mm）
  final double? evapotranspiration;

  /// 視程（km）
  final double? visibilityKm;

  /// 地表付近の土壌水分（m³/m³）
  final double? soilMoisture;

  const AiRaceTimeWeather({
    required this.weatherText,
    required this.temperature,
    required this.humidity,
    required this.precipitationProbability,
    required this.precipitation,
    required this.windSpeedKmh,
    required this.windDirectionText,
    required this.gustsKmh,
    required this.apparentTemperature,
    required this.radiation,
    required this.evapotranspiration,
    required this.visibilityKm,
    required this.soilMoisture,
  });

  /// 風速（m/s）
  double? get windSpeedMs =>
      windSpeedKmh == null ? null : aiKmhToMs(windSpeedKmh!);

  /// 突風（m/s）
  double? get gustsMs => gustsKmh == null ? null : aiKmhToMs(gustsKmh!);
}

/// 時間ごとの予報（午後の時系列）。
class AiWeatherHour {
  final String time;
  final String weatherText;
  final double? temperature;
  final int? precipitationProbability;
  final double? precipitation;

  /// 風速（km/h）
  final double? windSpeedKmh;

  const AiWeatherHour({
    required this.time,
    required this.weatherText,
    required this.temperature,
    required this.precipitationProbability,
    required this.precipitation,
    required this.windSpeedKmh,
  });

  /// 風速（m/s）
  double? get windSpeedMs =>
      windSpeedKmh == null ? null : aiKmhToMs(windSpeedKmh!);
}

/// 日ごとの天気（開催週の推移）。
class AiDailyWeather {
  final String date;
  final String weatherText;
  final double? tempMax;
  final double? tempMin;
  final double? precipitationSum;

  const AiDailyWeather({
    required this.date,
    required this.weatherText,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationSum,
  });
}

/// 馬場・展開インサイト1つ（レース情報タブの表示から色を除いたもの）。
class AiWeatherInsight {
  final String label;
  final String value;

  /// 説明の本文（根拠の式より前）
  final String summary;

  /// 予測シミュレーションの根拠（無ければ null）
  final String? basis;

  const AiWeatherInsight({
    required this.label,
    required this.value,
    required this.summary,
    required this.basis,
  });
}

/// AI分析用データに書く天気・馬場予測の要約。
class AiWeatherSnapshot {
  /// 天気を取得した時刻（「10/10 12:15」の形）
  final String fetchedAt;
  final AiRaceTimeWeather raceTime;

  /// 直線の風の影響（絵文字なし）
  final String? windAnalysis;
  final List<AiWeatherHour> timeline;
  final List<AiDailyWeather> daily;

  /// 馬場予測の起点にした測定（無ければ null）
  final TrackConditionRecord? baseline;

  /// 予測含水率（%）
  final double? predictedMoisture;

  /// 予測クッション値（ダートでも起点の値が入る。出力側で芝だけに使う）
  final double? predictedCushion;

  /// JRA基準での予測（'良' など）
  final String? jraCondition;

  /// 予測の寄り（'(稍重寄り)' など。無ければ空）
  final String? jraLeaning;
  final List<AiWeatherInsight> insights;

  const AiWeatherSnapshot({
    required this.fetchedAt,
    required this.raceTime,
    required this.windAnalysis,
    required this.timeline,
    required this.daily,
    required this.baseline,
    required this.predictedMoisture,
    required this.predictedCushion,
    required this.jraCondition,
    required this.jraLeaning,
    required this.insights,
  });
}

AiWeatherInsight _toAiInsight(WeatherInsight insight) {
  final description = insight.description;
  final splitAt = description.indexOf('\n\n');
  final summary =
      splitAt < 0 ? description : description.substring(0, splitAt);
  final basis = splitAt < 0 ? null : description.substring(splitAt + 2);
  return AiWeatherInsight(
    label: aiStripEmoji(insight.label),
    value: aiStripEmoji(insight.value),
    summary: aiStripEmoji(summary),
    basis: basis == null ? null : aiStripEmoji(basis),
  );
}

/// ピンポイント天気と馬場の測定から要約を作る。
/// [pinpoint] が null、または発走時刻の予報（raceTime）が無いときは null。
/// [baseline] は馬場予測の起点（レース情報タブと同じく、その競馬場の最新の測定）。
/// [trackType] は出馬表の表記（'芝' / 'ダ'）。null なら芝として扱う（レース情報タブと同じ）。
AiWeatherSnapshot? buildAiWeatherSnapshot({
  required Map<String, dynamic>? pinpoint,
  required TrackConditionRecord? baseline,
  required String venueCode,
  required String? trackType,
  required String raceDate,
}) {
  if (pinpoint == null) return null;
  final raceTimeRaw = pinpoint['raceTime'];
  if (raceTimeRaw is! Map) return null;

  final current = pinpoint['current'];
  final fetchedAt = current is Map ? (current['time']?.toString() ?? '') : '';

  final raceTime = AiRaceTimeWeather(
    weatherText:
        WeatherAnalyzer.getWeatherText(_toInt(raceTimeRaw['weatherCode']) ?? 0),
    temperature: _toDouble(raceTimeRaw['temp']),
    humidity: _toInt(raceTimeRaw['humidity']),
    precipitationProbability: _toInt(raceTimeRaw['pop']),
    precipitation: _toDouble(raceTimeRaw['precipitation']),
    windSpeedKmh: _toDouble(raceTimeRaw['windSpeed']),
    windDirectionText: pinpoint['windDirText']?.toString(),
    gustsKmh: _toDouble(raceTimeRaw['gusts']),
    apparentTemperature: _toDouble(raceTimeRaw['apparentTemp']),
    radiation: _toDouble(raceTimeRaw['radiation']),
    evapotranspiration: _toDouble(raceTimeRaw['evap']),
    visibilityKm: _toDouble(raceTimeRaw['visibility']),
    soilMoisture: _toDouble(raceTimeRaw['soilMoisture']),
  );

  final timeline = <AiWeatherHour>[];
  final timelineRaw = pinpoint['timeline'];
  if (timelineRaw is List) {
    for (final t in timelineRaw) {
      if (t is! Map) continue;
      timeline.add(AiWeatherHour(
        time: t['time']?.toString() ?? '',
        weatherText: WeatherAnalyzer.getWeatherText(_toInt(t['weatherCode']) ?? 0),
        temperature: _toDouble(t['temp']),
        precipitationProbability: _toInt(t['pop']),
        precipitation: _toDouble(t['precipitation']),
        windSpeedKmh: _toDouble(t['windSpeed']),
      ));
    }
  }

  final dailyRaw = pinpoint['daily'];
  final dailyList = dailyRaw is List ? dailyRaw : const <dynamic>[];
  final daily = <AiDailyWeather>[];
  for (final d in dailyList) {
    if (d is! Map) continue;
    daily.add(AiDailyWeather(
      date: d['date']?.toString() ?? '',
      weatherText: WeatherAnalyzer.getWeatherText(_toInt(d['weatherCode']) ?? 0),
      tempMax: _toDouble(d['tempMax']),
      tempMin: _toDouble(d['tempMin']),
      precipitationSum: _toDouble(d['precipitationSum']),
    ));
  }

  // レース情報タブ（race_info_tab.dart の「馬場・展開インサイト」）と同じ引数で呼ぶ。前回予測（cachedRecord）は使わない。
  final analysis = WeatherAnalyzer.analyzeTrackConditionInsights(
    venueCode: venueCode,
    trackType: trackType ?? '芝',
    currentRecord: baseline,
    cachedRecord: null,
    expectedPrecipitation: raceTime.precipitation ?? 0.0,
    expectedRadiation: raceTime.radiation ?? 0.0,
    expectedSoilMoisture: raceTime.soilMoisture,
    dailyWeather: dailyList,
    raceDateStr: raceDate,
  );

  final rawInsights = <WeatherInsight>[
    WeatherAnalyzer.analyzeTrackRecovery(
        raceTime.radiation ?? 0.0, raceTime.evapotranspiration ?? 0.0),
    WeatherAnalyzer.analyzeHorseStamina(
        raceTime.apparentTemperature ?? 0.0, (raceTime.humidity ?? 0).toDouble()),
    WeatherAnalyzer.analyzeRaceRisk(
        (raceTime.gustsKmh ?? 0.0) / 3.6, raceTime.visibilityKm ?? 20.0),
    ...analysis.insights,
  ];

  final windAnalysisRaw = pinpoint['windAnalysis'];

  return AiWeatherSnapshot(
    fetchedAt: fetchedAt,
    raceTime: raceTime,
    windAnalysis:
        windAnalysisRaw is String ? aiStripEmoji(windAnalysisRaw) : null,
    timeline: timeline,
    daily: daily,
    baseline: baseline,
    predictedMoisture: analysis.predictedMoisture,
    predictedCushion: analysis.predictedCushion,
    jraCondition: analysis.jraPrediction?.conditionText,
    jraLeaning: analysis.jraPrediction?.leaningText,
    insights: [for (final insight in rawInsights) _toAiInsight(insight)],
  );
}
