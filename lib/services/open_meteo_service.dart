// lib/services/open_meteo_service.dart

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class OpenMeteoService {
  static const Map<String, Map<String, double>> _venueCoords = {
    '札幌': {'lat': 43.0762, 'lon': 141.3218}, '函館': {'lat': 41.7850, 'lon': 140.7686},
    '福島': {'lat': 37.7711, 'lon': 140.4578}, '新潟': {'lat': 37.9525, 'lon': 139.1825},
    '東京': {'lat': 35.6627, 'lon': 139.4851}, '中山': {'lat': 35.7259, 'lon': 139.9575},
    '中京': {'lat': 35.0683, 'lon': 136.9897}, '京都': {'lat': 34.9077, 'lon': 135.7225},
    '阪神': {'lat': 34.7797, 'lon': 135.3621}, '小倉': {'lat': 33.8406, 'lon': 130.8753},
  };

  static const Map<String, double> _homestretchHeadings = {
    '札幌': 0, '函館': 0, '福島': 180, '新潟': 225, '東京': 270, '中山': 90,
    '中京': 0, '京都': 90, '阪神': 90, '小倉': 0,
  };

  static String _getWindDirectionText(double degrees) {
    const directions = ['北', '北北東', '北東', '東北東', '東', '東南東', '南東', '南南東', '南', '南南西', '南西', '西南西', '西', '西北西', '北西', '北北西'];
    int val = ((degrees / 22.5) + 0.5).floor();
    return directions[val % 16];
  }

  static String _analyzeWindEffect(String venue, double windDir) {
    final heading = _homestretchHeadings[venue];
    if (heading == null) return '風向きデータなし';
    double relAngle = (windDir - heading) % 360;
    if (relAngle < 0) relAngle += 360;

    // [修正] レース情報ヘッダー整理 Step3: 文の先頭の絵文字を外した（下の横風の3つも同じ） (v.2026.10.15+26101511)
    if (relAngle <= 45 || relAngle >= 315) {
      return '直線は【向かい風】の傾向（逃げ馬に厳しく、差し馬有利）';
    } else if (relAngle >= 135 && relAngle <= 225) {
      return '直線は【追い風】の傾向（逃げ・先行馬が止まりにくい）';
    } else {
      bool isRightWind = (relAngle > 45 && relAngle < 135);
      bool isLeftWind = (relAngle > 225 && relAngle < 315);
      bool isRightTurn = ['札幌', '函館', '福島', '中山', '京都', '阪神', '小倉'].contains(venue);
      bool fromStand = false;
      bool fromInfield = false;

      if (isRightWind) {
        if (isRightTurn) fromInfield = true; else fromStand = true;
      } else if (isLeftWind) {
        if (isRightTurn) fromStand = true; else fromInfield = true;
      }

      if (fromStand) return '直線は【スタンド側から内馬場】への横風';
      else if (fromInfield) return '直線は【内馬場からスタンド側】への横風';
      return '直線は【横風】の傾向';
    }
  }

  // [追加] 取得先の予備とタイムアウト。通常のホストが応答しないとき（2026-11 日本向けサーバーの障害）は予備のホストに切り替える (v.2026.11.17+26111703)
  static const String _primaryHost = 'api.open-meteo.com';
  static const String _fallbackHost = 'previous-runs-api.open-meteo.com';
  static const Duration _primaryTimeout = Duration(seconds: 8);
  static const Duration _fallbackTimeout = Duration(seconds: 20);
  // [追加] 通常のホストで失敗したら、この間は予備のホストを先に試す（毎回8秒待たないように） (v.2026.11.17+26111703)
  static const Duration _preferFallbackDuration = Duration(minutes: 30);
  static DateTime? _preferFallbackUntil;
  // [追加] 馬場予測の天気材料の見直し Step2: 保存したピンポイント天気の有効期限（発走から1時間を過ぎていないレースだけ）。過ぎたら取り直し、取り直せなければ保存分を返す (v.2026.11.18+26111802)
  static const Duration _cacheTtl = Duration(hours: 1);

  // [追加] 通常→予備（または予備→通常）の順に取得し、最初に200が返ったものを使う。どちらもだめなら null (v.2026.11.17+26111703)
  static Future<http.Response?> _getWithFallback(double lat, double lon) async {
    final preferFallback = _preferFallbackUntil != null && DateTime.now().isBefore(_preferFallbackUntil!);
    final hosts = preferFallback ? [_fallbackHost, _primaryHost] : [_primaryHost, _fallbackHost];

    for (final host in hosts) {
      final isPrimary = host == _primaryHost;
      final url = Uri.parse(generateOpenMeteoUrl(latitude: lat, longitude: lon, host: host));
      try {
        final response = await http.get(url).timeout(isPrimary ? _primaryTimeout : _fallbackTimeout);
        if (response.statusCode == 200) {
          if (isPrimary) _preferFallbackUntil = null;
          return response;
        }
        debugPrint('Open-Meteo($host) 応答エラー: ${response.statusCode}');
      } catch (e) {
        debugPrint('Open-Meteo($host) 取得エラー: $e');
      }
      if (isPrimary) _preferFallbackUntil = DateTime.now().add(_preferFallbackDuration);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchDetailedWeather(String venue, String targetDateStr, String startTimeStr, String raceId, {bool forceRefresh = false, bool isPastRace = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'open_meteo_$raceId';

    // [修正] 馬場予測の天気材料の見直し Step2: 保存分は、発走から1時間を過ぎたレースならそのまま、そうでなければ取得から1時間以内のときだけ使う。古い保存分（取得時刻なし）は取り直す。取り直せなかったときは古い保存分を返す (v.2026.11.18+26111802)
    Map<String, dynamic>? staleCache;
    if (!forceRefresh) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final decoded = Map<String, dynamic>.from(json.decode(cachedData) as Map);
        if (isPastRace) return decoded;
        final fetchedAtMs = decoded['fetchedAtMs'];
        final isFresh = fetchedAtMs is int &&
            DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(fetchedAtMs)) < _cacheTtl;
        if (isFresh) return decoded;
        staleCache = decoded;
      }
    }
    if (isPastRace) return null;

    final coords = _venueCoords[venue];
    if (coords == null) return staleCache;

    final lat = coords['lat']!;
    final lon = coords['lon']!;

    try {
      // [修正] 通常のホストが応答しないときは予備のホストから取る（タイムアウトつき） (v.2026.11.17+26111703)
      final response = await _getWithFallback(lat, lon);
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);

        final current = data['current'];
        String currentTimeStr = current['time'] ?? '';
        if (currentTimeStr.isNotEmpty) {
          final dt = DateTime.parse(currentTimeStr);
          currentTimeStr = '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          final now = DateTime.now();
          currentTimeStr = '${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        }

        final currentData = {
          'time': currentTimeStr,
          'temp': (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
          'humidity': (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
          'precipitation': (current['precipitation'] as num?)?.toDouble() ?? 0.0,
          'windSpeed': (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
          'windDirText': _getWindDirectionText((current['wind_direction_10m'] as num?)?.toDouble() ?? 0.0),
          'weatherCode': (current['weather_code'] as num?)?.toInt() ?? 0,
        };

        DateTime? raceDate;
        final dateMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(targetDateStr);
        if (dateMatch != null) {
          raceDate = DateTime(int.parse(dateMatch.group(1)!), int.parse(dateMatch.group(2)!), int.parse(dateMatch.group(3)!));
        } else {
          raceDate = DateTime.tryParse(targetDateStr.replaceAll('/', '-'));
        }
        raceDate ??= DateTime.now();

        int targetHour = 15;
        if (startTimeStr.contains(':')) {
          targetHour = int.tryParse(startTimeStr.split(':')[0]) ?? 15;
        }

        final hourly = data['hourly'];
        final times = List<String>.from(hourly['time']);

        List<Map<String, dynamic>> timeline = [];
        Map<String, dynamic>? raceTimeData;
        // [追加] 馬場予測の天気材料の見直し Step2: 馬場予測に使う1時間ごとの雨（取得した全部の時間。時刻はその1時間の終わり） (v.2026.11.18+26111802)
        List<Map<String, dynamic>> hourlyPrecip = [];

        for (int i = 0; i < times.length; i++) {
          final timeStr = times[i];
          final dt = DateTime.parse(timeStr);
          final hour = dt.hour;
          // [追加] 馬場予測の天気材料の見直し Step2: 1時間ごとの雨を全部の時間ぶん持つ (v.2026.11.18+26111802)
          final precipValue = hourly['precipitation'][i];
          if (precipValue is num) {
            hourlyPrecip.add({'time': timeStr, 'mm': precipValue.toDouble()});
          }

          if (dt.year == raceDate.year && dt.month == raceDate.month && dt.day == raceDate.day) {
            if (hour == targetHour && raceTimeData == null) {
              raceTimeData = {
                'temp': (hourly['temperature_2m'][i] as num?)?.toDouble() ?? 0.0,
                'humidity': (hourly['relative_humidity_2m'][i] as num?)?.toInt() ?? 0,
                'pop': (hourly['precipitation_probability'][i] as num?)?.toInt() ?? 0,
                'precipitation': (hourly['precipitation'][i] as num?)?.toDouble() ?? 0.0,
                'windSpeed': (hourly['wind_speed_10m'][i] as num?)?.toDouble() ?? 0.0,
                'windDir': (hourly['wind_direction_10m'][i] as num?)?.toDouble() ?? 0.0,
                'weatherCode': (hourly['weather_code'][i] as num?)?.toInt() ?? 0,
                'apparentTemp': (hourly['apparent_temperature'][i] as num?)?.toDouble() ?? 0.0,
                'radiation': (hourly['shortwave_radiation'][i] as num?)?.toDouble() ?? 0.0,
                'evap': (hourly['et0_fao_evapotranspiration'][i] as num?)?.toDouble() ?? 0.0,
                'gusts': (hourly['wind_gusts_10m'][i] as num?)?.toDouble() ?? 0.0,
                'visibility': ((hourly['visibility'][i] as num?)?.toDouble() ?? 0.0) / 1000.0,
                'soilMoisture': (hourly['soil_moisture_0_to_1cm'][i] as num?)?.toDouble() ?? 0.0,
              };
            }

            if (hour >= 12 && hour <= 17 && timeline.length < 6) {
              timeline.add({
                'time': '$hour:00',
                'temp': (hourly['temperature_2m'][i] as num?)?.toDouble() ?? 0.0,
                'pop': (hourly['precipitation_probability'][i] as num?)?.toInt() ?? 0,
                'precipitation': (hourly['precipitation'][i] as num?)?.toDouble() ?? 0.0,
                'windSpeed': (hourly['wind_speed_10m'][i] as num?)?.toDouble() ?? 0.0,
                'weatherCode': (hourly['weather_code'][i] as num?)?.toInt() ?? 0,
              });
            }
          }
        }

        // [修正] 馬場予測の天気材料の見直し Step2: 取れなかったときは古い保存分を返す（無ければ null） (v.2026.11.18+26111802)
        if (raceTimeData == null) return staleCache;

        // [追加] 日次(週間)データのパース (v.3.0)
        final daily = data['daily'];
        List<Map<String, dynamic>> dailyData = [];
        if (daily != null) {
          final dailyTimes = List<String>.from(daily['time']);
          for (int i = 0; i < dailyTimes.length; i++) {
            dailyData.add({
              'date': dailyTimes[i],
              'weatherCode': (daily['weather_code'][i] as num?)?.toInt() ?? 0,
              'tempMax': (daily['temperature_2m_max'][i] as num?)?.toDouble() ?? 0.0,
              'tempMin': (daily['temperature_2m_min'][i] as num?)?.toDouble() ?? 0.0,
              'precipitationSum': (daily['precipitation_sum'][i] as num?)?.toDouble() ?? 0.0,
              'evapoTranspiration': (daily['et0_fao_evapotranspiration'][i] as num?)?.toDouble() ?? 0.0,
            });
          }
        }

        final result = {
          'current': currentData,
          'raceTime': raceTimeData,
          'timeline': timeline,
          'daily': dailyData,
          'windAnalysis': _analyzeWindEffect(venue, raceTimeData['windDir']),
          'windDirText': _getWindDirectionText(raceTimeData['windDir']),
          // [追加] 馬場予測の天気材料の見直し Step2: 1時間ごとの雨と取得時刻（保存の有効期限に使う） (v.2026.11.18+26111802)
          'hourlyPrecip': hourlyPrecip,
          'fetchedAtMs': DateTime.now().millisecondsSinceEpoch,
        };

        await prefs.setString(cacheKey, json.encode(result));
        return result;
      }
    } catch (e) {
      debugPrint('Open-Meteo取得エラー: $e');
    }
    // [修正] 馬場予測の天気材料の見直し Step2: 取れなかったときは古い保存分を返す（無ければ null） (v.2026.11.18+26111802)
    return staleCache;
  }
}