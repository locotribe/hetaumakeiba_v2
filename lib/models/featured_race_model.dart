// lib/models/featured_race_model.dart

import 'dart:convert';

/// 今週の注目レースの情報を保持するデータモデルクラスです。
class FeaturedRace {
  final int? id; // データベースID (自動生成されるためnullable)
  final String raceId; // レースを一意に識別するID (例: '202504020407')
  final String raceName; // レース名 (例: 'アイビスＳＤ')
  final String raceGrade; // レースのグレード (例: 'G3')
  final String raceDate; // 開催日 (例: '2025年8月3日')
  final String venue; // 開催場所 (例: '新潟')
  final String raceNumber; // レース番号 (例: '7R')
  final String shutubaTableUrl; // 出馬表ページへのURL
  final DateTime lastScraped; // 最終スクレイピング日時
  // ▼▼▼ ここから追加 ▼▼▼
  final String distance; // 距離 (例: "芝2000m")
  final String conditions; // 条件 (例: "4歳上")
  final String weight; // 重量 (例: "ハンデ")
  // ▲▲▲ ここまで追加 ▲▲▲

  FeaturedRace({
    this.id,
    required this.raceId,
    required this.raceName,
    required this.raceGrade,
    required this.raceDate,
    required this.venue,
    required this.raceNumber,
    required this.shutubaTableUrl,
    required this.lastScraped,
    // ▼▼▼ ここから追加 ▼▼▼
    required this.distance,
    required this.conditions,
    required this.weight,
    // ▲▲▲ ここまで追加 ▲▲▲
  });

  /// MapからFeaturedRaceオブジェクトを生成するファクトリコンストラクタです。
  factory FeaturedRace.fromMap(Map<String, dynamic> map) {
    return FeaturedRace(
      id: map['id'] as int?,
      raceId: map['race_id'] as String,
      raceName: map['race_name'] as String,
      raceGrade: map['race_grade'] as String,
      raceDate: map['race_date'] as String,
      venue: map['venue'] as String,
      raceNumber: map['race_number'] as String,
      shutubaTableUrl: map['shutuba_table_url'] as String,
      lastScraped: DateTime.parse(map['last_scraped'] as String),
      // ▼▼▼ ここから追加 (DBにまだ列がない場合も考慮してnull許容で取得し、nullなら空文字を返す) ▼▼▼
      distance: map['distance'] as String? ?? '',
      conditions: map['conditions'] as String? ?? '',
      weight: map['weight'] as String? ?? '',
      // ▲▲▲ ここまで追加 ▲▲▲
    );
  }

  /// FeaturedRaceオブジェクトからMapを生成するメソッドです（データベース保存用）。
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'race_id': raceId,
      'race_name': raceName,
      'race_grade': raceGrade,
      'race_date': raceDate,
      'venue': venue,
      'race_number': raceNumber,
      'shutuba_table_url': shutubaTableUrl,
      'last_scraped': lastScraped.toIso8601String(),
      // ▼▼▼ ここから追加 ▼▼▼
      'distance': distance,
      'conditions': conditions,
      'weight': weight,
      // ▲▲▲ ここまで追加 ▲▲▲
    };
  }

  /// FeaturedRaceオブジェクトからJSON文字列を生成します。
  String toJson() => json.encode(toMap());

  /// JSON文字列からFeaturedRaceオブジェクトを生成するファクトリコンストラクタです。
  factory FeaturedRace.fromJson(String source) =>
      FeaturedRace.fromMap(json.decode(source) as Map<String, dynamic>);
}