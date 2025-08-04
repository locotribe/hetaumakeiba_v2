// lib/models/featured_race_model.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';

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
  final String distance; // 距離 (例: "芝2000m")
  final String conditions; // 条件 (例: "4歳上")
  final String weight; // 重量 (例: "ハンデ")
  final String? raceDetails1; // 詳細情報1 (発走時間 / コース情報など)
  final String? raceDetails2; // 詳細情報2 (レース条件など)
  final List<ShutubaHorseDetail>? shutubaHorses; // ★追加：出馬表の馬詳細リスト

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
    required this.distance,
    required this.conditions,
    required this.weight,
    this.raceDetails1,
    this.raceDetails2,
    this.shutubaHorses,
  });

  /// MapからFeaturedRaceオブジェクトを生成するファクトリコンストラクタです。
  factory FeaturedRace.fromMap(Map<String, dynamic> map) {
    List<ShutubaHorseDetail>? horses;
    if (map['shutubaHorsesJson'] != null) {
      final List<dynamic> jsonList = json.decode(map['shutubaHorsesJson'] as String);
      horses = jsonList.map((e) => ShutubaHorseDetail.fromMap(e as Map<String, dynamic>)).toList();
    }
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
      distance: map['distance'] as String? ?? '',
      conditions: map['conditions'] as String? ?? '',
      weight: map['weight'] as String? ?? '',
      raceDetails1: map['race_details_1'] as String?,
      raceDetails2: map['race_details_2'] as String?,
      shutubaHorses: horses,
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
      'distance': distance,
      'conditions': conditions,
      'weight': weight,
      'race_details_1': raceDetails1,
      'race_details_2': raceDetails2,
      'shutubaHorsesJson': shutubaHorses != null // ★追加：JSONエンコード
          ? json.encode(shutubaHorses!.map((e) => e.toMap()).toList())
          : null,
    };
  }

  /// FeaturedRaceオブジェクトからJSON文字列を生成します。
  String toJson() => json.encode(toMap());

  /// JSON文字列からFeaturedRaceオブジェクトを生成するファクトリコンストラクタです。
  factory FeaturedRace.fromJson(String source) =>
      FeaturedRace.fromMap(json.decode(source) as Map<String, dynamic>);
}