// lib/models/horse_stats_cache_model.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';

class HorseStatsCache {
  final String raceId;
  final Map<String, HorseStats> statsMap;
  final DateTime lastUpdatedAt;

  HorseStatsCache({
    required this.raceId,
    required this.statsMap,
    required this.lastUpdatedAt,
  });

  // DBから取得したMapをオブジェクトに変換
  factory HorseStatsCache.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> decodedJson = json.decode(map['statsJson'] as String);
    final Map<String, HorseStats> stats = decodedJson.map((key, value) {
      // JSONからデコードされたMapを元にHorseStatsオブジェクトを復元
      return MapEntry(key, HorseStats(
        raceCount: value['raceCount'] ?? 0,
        winRate: value['winRate'] ?? 0.0,
        placeRate: value['placeRate'] ?? 0.0,
        showRate: value['showRate'] ?? 0.0,
        winRecoveryRate: value['winRecoveryRate'] ?? 0.0,
        showRecoveryRate: value['showRecoveryRate'] ?? 0.0,
      ));
    });

    return HorseStatsCache(
      raceId: map['raceId'] as String,
      statsMap: stats,
      lastUpdatedAt: DateTime.parse(map['lastUpdatedAt'] as String),
    );
  }

  // オブジェクトをDB保存用のMapに変換
  Map<String, dynamic> toMap() {
    // HorseStatsオブジェクトをJSONエンコード可能なマップに変換
    final Map<String, dynamic> encodableMap = statsMap.map((key, value) {
      return MapEntry(key, {
        'raceCount': value.raceCount,
        'winRate': value.winRate,
        'placeRate': value.placeRate,
        'showRate': value.showRate,
        'winRecoveryRate': value.winRecoveryRate,
        'showRecoveryRate': value.showRecoveryRate,
      });
    });

    return {
      'raceId': raceId,
      'statsJson': json.encode(encodableMap),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }
}
