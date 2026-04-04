// lib/services/odds_cache_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OddsCacheService {
  static const int cacheDurationMinutes = 60;

  String _generateKey(String raceId, String type) {
    return 'odds_cache_${raceId}_$type';
  }

  Future<void> saveOddsData({
    required String raceId,
    required String type,
    required List<Map<String, String>> oddsData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _generateKey(raceId, type);
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': oddsData,
    };
    await prefs.setString(key, json.encode(cacheData));
  }

  Future<List<Map<String, String>>?> getValidCachedOdds({
    required String raceId,
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _generateKey(raceId, type);
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    try {
      final cacheData = json.decode(jsonString) as Map<String, dynamic>;
      final timestampStr = cacheData['timestamp'] as String;
      final dataList = cacheData['data'] as List<dynamic>;
      final cachedTime = DateTime.parse(timestampStr);
      final difference = DateTime.now().difference(cachedTime).inMinutes;

      if (difference < cacheDurationMinutes) {
        return dataList.map((e) {
          final map = e as Map<String, dynamic>;
          return map.map((k, v) => MapEntry(k, v.toString()));
        }).toList();
      } else {
        await prefs.remove(key);
        return null;
      }
    } catch (e) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> clearCache(String raceId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_generateKey(raceId, type));
  }
}