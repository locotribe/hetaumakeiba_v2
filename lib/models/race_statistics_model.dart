// lib/models/race_statistics_model.dart

import 'dart:convert';

class RaceStatistics {
  final String raceId; // 最新のレースID（主キーとして使用）
  final String raceName; // レース名
  final String statisticsJson; // 分析された統計データ全体をJSON文字列で保持
  final String analyzedRacesJson; // 分析対象となったレース一覧のJSON文字列
  final DateTime lastUpdatedAt; // 最終更新日時

  RaceStatistics({
    required this.raceId,
    required this.raceName,
    required this.statisticsJson,
    this.analyzedRacesJson = '[]', // デフォルトは空リスト
    required this.lastUpdatedAt,
  });

  // DBに保存するデータをMapに変換
  Map<String, dynamic> toMap() {
    return {
      'raceId': raceId,
      'raceName': raceName,
      'statisticsJson': statisticsJson,
      // ★修正: データベースの準備が整ったため、保存対象に戻す
      'analyzedRacesJson': analyzedRacesJson,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  // DBからデータを読み込んでオブジェクトを作成
  factory RaceStatistics.fromMap(Map<String, dynamic> map) {
    return RaceStatistics(
      raceId: map['raceId'] as String,
      raceName: map['raceName'] as String,
      statisticsJson: map['statisticsJson'] as String,
      // 既存データにカラムがない場合やNULLの場合の安全策
      analyzedRacesJson: map.containsKey('analyzedRacesJson') && map['analyzedRacesJson'] != null
          ? map['analyzedRacesJson'] as String
          : '[]',
      lastUpdatedAt: DateTime.parse(map['lastUpdatedAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory RaceStatistics.fromJson(String source) =>
      RaceStatistics.fromMap(json.decode(source) as Map<String, dynamic>);

  /// 分析対象レースのリストを取得するヘルパー
  List<Map<String, dynamic>> get analyzedRacesList {
    try {
      if (analyzedRacesJson.isEmpty) return [];
      return List<Map<String, dynamic>>.from(json.decode(analyzedRacesJson));
    } catch (e) {
      return [];
    }
  }
}