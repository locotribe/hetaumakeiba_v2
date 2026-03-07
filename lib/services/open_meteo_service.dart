// lib/services/open_meteo_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart'; // URL生成のインポートを追加

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

    if (relAngle <= 45 || relAngle >= 315) {
      return '⚠️ 直線は【向かい風】の傾向（逃げ馬に厳しく、差し馬有利）';
    } else if (relAngle >= 135 && relAngle <= 225) {
      return '💨 直線は【追い風】の傾向（逃げ・先行馬が止まりにくい）';
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

      if (fromStand) return '🍃 直線は【スタンド側から内馬場】への横風';
      else if (fromInfield) return '🍃 直線は【内馬場からスタンド側】への横風';
      return '🍃 直線は【横風】の傾向';
    }
  }

  static Future<Map<String, dynamic>?> fetchDetailedWeather(String venue, String targetDateStr, String startTimeStr, String raceId, {bool forceRefresh = false, bool isPastRace = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'open_meteo_$raceId';

    if (!forceRefresh) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) return json.decode(cachedData);
    }
    if (isPastRace) return null;

    final coords = _venueCoords[venue];
    if (coords == null) return null;

    final lat = coords['lat']!;
    final lon = coords['lon']!;

    // ▼ 修正: url_generator の共通関数を使用
    final url = Uri.parse(generateOpenMeteoUrl(latitude: lat, longitude: lon));

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
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
          // ▼ 追加: 現在の天気コード
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

        for (int i = 0; i < times.length; i++) {
          final timeStr = times[i];
          final dt = DateTime.parse(timeStr);
          final hour = dt.hour;

          if (dt.year == raceDate.year && dt.month == raceDate.month && dt.day == raceDate.day) {

            if (hour == targetHour && raceTimeData == null) {
              raceTimeData = {
                'temp': (hourly['temperature_2m'][i] as num?)?.toDouble() ?? 0.0,
                'humidity': (hourly['relative_humidity_2m'][i] as num?)?.toInt() ?? 0,
                'pop': (hourly['precipitation_probability'][i] as num?)?.toInt() ?? 0,
                'precipitation': (hourly['precipitation'][i] as num?)?.toDouble() ?? 0.0,
                'windSpeed': (hourly['wind_speed_10m'][i] as num?)?.toDouble() ?? 0.0,
                'windDir': (hourly['wind_direction_10m'][i] as num?)?.toDouble() ?? 0.0,
                // ▼ 追加: 解析 4 項目用のデータ
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
                // ▼ 追加: タイムライン用天気コード
                'weatherCode': (hourly['weather_code'][i] as num?)?.toInt() ?? 0,
              });
            }
          }
        }

        if (raceTimeData == null) return null;

        final result = {
          'current': currentData,
          'raceTime': raceTimeData,
          'timeline': timeline,
          'windAnalysis': _analyzeWindEffect(venue, raceTimeData['windDir']),
          'windDirText': _getWindDirectionText(raceTimeData['windDir']),
        };

        await prefs.setString(cacheKey, json.encode(result));
        return result;
      }
    } catch (e) {
      print('Open-Meteo取得エラー: $e');
    }
    return null;
  }
}