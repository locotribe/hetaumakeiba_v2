// lib/services/jma_weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JmaWeatherService {
  static const Map<String, String> _venueAreaCodes = {
    '札幌': '016000', '函館': '012000', '福島': '070000', '新潟': '150000',
    '東京': '130000', '中山': '120000', '中京': '230000', '京都': '260000',
    '阪神': '280000', '小倉': '400000',
  };

  static Future<Map<String, String>?> fetchWeatherAndPop(String venue, String raceId, {bool forceRefresh = false, bool isPastRace = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'jma_weather_overview_$raceId';

    if (!forceRefresh) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        return Map<String, String>.from(json.decode(cachedData));
      }
    }

    if (isPastRace) return null;

    final areaCode = _venueAreaCodes[venue];
    if (areaCode == null) return null;

    // ▼ 通常の予報ではなく「天気概況（詳しい解説文）」のエンドポイントに変更
    final url = Uri.parse('https://www.jma.go.jp/bosai/forecast/data/overview_forecast/$areaCode.json');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        // 1. 発表時刻の取得とフォーマット (例: 2024-03-08T16:47:00+09:00 -> 3/8 16:47)
        String reportDatetime = data['reportDatetime'] ?? '';
        if (reportDatetime.isNotEmpty) {
          final dt = DateTime.parse(reportDatetime);
          reportDatetime = '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }

        // 2. 詳しい解説文の取得
        String overviewText = data['text'] ?? '解説データがありません';
        // 全角スペースや不要な改行を整理して読みやすくする
        overviewText = overviewText.replaceAll('　', '').trim();

        final result = {
          'reportDatetime': reportDatetime,
          'overviewText': overviewText,
        };

        await prefs.setString(cacheKey, json.encode(result));
        return result;
      }
    } catch (e) {
      print('気象庁API(概況)取得エラー: $e');
    }
    return null;
  }
}