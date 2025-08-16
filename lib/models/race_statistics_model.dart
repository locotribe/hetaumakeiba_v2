// lib/models/race_statistics_model.dart

import 'dart:convert';

class RaceStatistics {
  final String raceId; // 最新のレースID（主キーとして使用）
  final String raceName; // レース名
  final String statisticsJson; // 分析された統計データ全体をJSON文字列で保持
  final DateTime lastUpdatedAt; // 最終更新日時

  RaceStatistics({
    required this.raceId,
    required this.raceName,
    required this.statisticsJson,
    required this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'raceId': raceId,
      'raceName': raceName,
      'statisticsJson': statisticsJson,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory RaceStatistics.fromMap(Map<String, dynamic> map) {
    return RaceStatistics(
      raceId: map['raceId'] as String,
      raceName: map['raceName'] as String,
      statisticsJson: map['statisticsJson'] as String,
      lastUpdatedAt: DateTime.parse(map['lastUpdatedAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory RaceStatistics.fromJson(String source) =>
      RaceStatistics.fromMap(json.decode(source) as Map<String, dynamic>);
}