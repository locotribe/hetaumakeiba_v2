// lib/models/horse_performance_model.dart

import 'dart:convert'; // JSONエンコード/デコードのために必要

/// 競走馬の個々の競走成績を保持するデータモデルクラスです。
class HorseRaceRecord {
  final int? id; // データベースID (自動生成されるためnullable)
  final String horseId; // 競走馬のID (例: '2020101779')
  final String date; // 日付 (例: '2025/07/19')
  final String venue; // 開催 (例: '2福島7')
  final String weather; // 天気 (例: '曇')
  final String raceNumber; // R (レース番号) (例: '1')
  final String raceName; // レース名 (例: '障害3歳以上OP')
  final String numberOfHorses; // 頭数 (例: '8')
  final String frameNumber; // 枠番 (例: '1')
  final String horseNumber; // 馬番 (例: '1')
  final String odds; // オッズ (例: '18.0')
  final String popularity; // 人気 (例: '7')
  final String rank; // 着順 (例: '5')
  final String jockey; // 騎手 (例: '大江原圭')
  final String carriedWeight; // 斤量 (例: '60')
  final String distance; // 距離 (例: '障3380')
  final String trackCondition; // 馬場 (例: '良')
  final String time; // タイム (例: '3:50.9')
  final String margin; // 着差 (例: '1.9')
  final String cornerPassage; // 通過 (コーナー通過順位) (例: '2-2-4-4')
  final String pace; // ペース (例: '108.0-40.2')
  final String agari; // 上り (上がり3ハロンタイム) (例: '13.7')
  final String horseWeight; // 馬体重 (例: '438(-6)')
  final String winnerOrSecondHorse; // 勝ち馬(2着馬) (例: 'シホノスペランツァ')
  final String prizeMoney; // 賞金 (例: '143.0')

  HorseRaceRecord({
    this.id,
    required this.horseId,
    required this.date,
    required this.venue,
    required this.weather,
    required this.raceNumber,
    required this.raceName,
    required this.numberOfHorses,
    required this.frameNumber,
    required this.horseNumber,
    required this.odds,
    required this.popularity,
    required this.rank,
    required this.jockey,
    required this.carriedWeight,
    required this.distance,
    required this.trackCondition,
    required this.time,
    required this.margin,
    required this.cornerPassage,
    required this.pace,
    required this.agari,
    required this.horseWeight,
    required this.winnerOrSecondHorse,
    required this.prizeMoney,
  });

  /// MapからHorseRaceRecordオブジェクトを生成するファクトリコンストラクタです。
  factory HorseRaceRecord.fromMap(Map<String, dynamic> map) {
    return HorseRaceRecord(
      id: map['id'] as int?,
      horseId: map['horse_id'] as String,
      date: map['date'] as String,
      venue: map['venue'] as String,
      weather: map['weather'] as String,
      raceNumber: map['race_number'] as String,
      raceName: map['race_name'] as String,
      numberOfHorses: map['number_of_horses'] as String,
      frameNumber: map['frame_number'] as String,
      horseNumber: map['horse_number'] as String,
      odds: map['odds'] as String,
      popularity: map['popularity'] as String,
      rank: map['rank'] as String,
      jockey: map['jockey'] as String,
      carriedWeight: map['carried_weight'] as String,
      distance: map['distance'] as String,
      trackCondition: map['track_condition'] as String,
      time: map['time'] as String,
      margin: map['margin'] as String,
      cornerPassage: map['corner_passage'] as String,
      pace: map['pace'] as String,
      agari: map['agari'] as String,
      horseWeight: map['horse_weight'] as String,
      winnerOrSecondHorse: map['winner_or_second_horse'] as String,
      prizeMoney: map['prize_money'] as String,
    );
  }

  /// HorseRaceRecordオブジェクトからMapを生成するメソッドです（データベース保存用）。
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'horse_id': horseId,
      'date': date,
      'venue': venue,
      'weather': weather,
      'race_number': raceNumber,
      'race_name': raceName,
      'number_of_horses': numberOfHorses,
      'frame_number': frameNumber,
      'horse_number': horseNumber,
      'odds': odds,
      'popularity': popularity,
      'rank': rank,
      'jockey': jockey,
      'carried_weight': carriedWeight,
      'distance': distance,
      'track_condition': trackCondition,
      'time': time,
      'margin': margin,
      'corner_passage': cornerPassage,
      'pace': pace,
      'agari': agari,
      'horse_weight': horseWeight,
      'winner_or_second_horse': winnerOrSecondHorse,
      'prize_money': prizeMoney,
    };
  }

  /// HorseRaceRecordオブジェクトからJSON文字列を生成します。
  String toJson() => json.encode(toMap());

  /// JSON文字列からHorseRaceRecordオブジェクトを生成するファクトリコンストラクタです。
  factory HorseRaceRecord.fromJson(String source) =>
      HorseRaceRecord.fromMap(json.decode(source) as Map<String, dynamic>);
}
