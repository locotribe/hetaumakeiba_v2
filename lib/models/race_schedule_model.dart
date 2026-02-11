// lib/models/race_schedule_model.dart
import 'dart:convert';

// トップレベルのヘルパー関数
String raceScheduleToJson(RaceSchedule data) => json.encode(data.toMap());
RaceSchedule raceScheduleFromJson(String str) => RaceSchedule.fromMap(json.decode(str));

/// 特定の開催日の全レース情報を保持するクラス
class RaceSchedule {
  final String date; // yyyy-MM-dd形式の主キー
  final String dayOfWeek;
  final List<VenueSchedule> venues;

  RaceSchedule({
    required this.date,
    required this.dayOfWeek,
    required this.venues,
  });

  factory RaceSchedule.fromMap(Map<String, dynamic> map) {
    return RaceSchedule(
      date: map['date'] as String,
      dayOfWeek: map['dayOfWeek'] as String,
      venues: List<VenueSchedule>.from(
        (map['venues'] as List<dynamic>).map<VenueSchedule>(
              (x) => VenueSchedule.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'dayOfWeek': dayOfWeek,
      'venues': venues.map((x) => x.toMap()).toList(),
    };
  }
}

/// 競馬場ごとの開催情報を保持するクラス
class VenueSchedule {
  final String venueTitle; // 例: "3回 札幌 5日目"
  final List<SimpleRaceInfo> races;

  VenueSchedule({
    required this.venueTitle,
    required this.races,
  });

  factory VenueSchedule.fromMap(Map<String, dynamic> map) {
    return VenueSchedule(
      venueTitle: map['venueTitle'] as String,
      races: List<SimpleRaceInfo>.from(
        (map['races'] as List<dynamic>).map<SimpleRaceInfo>(
              (x) => SimpleRaceInfo.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'venueTitle': venueTitle,
      'races': races.map((x) => x.toMap()).toList(),
    };
  }
}

/// 個々のレースの簡易情報を保持するクラス
class SimpleRaceInfo {
  final String raceId;
  final String raceNumber;
  final String raceName;
  final String grade; // G1, G2, OP, 1勝など
  final String details; // "芝右1200m / 15:45発走" など
  bool isConfirmed; // ★ここを保存できるように修正します

  SimpleRaceInfo({
    required this.raceId,
    required this.raceNumber,
    required this.raceName,
    required this.grade,
    required this.details,
    this.isConfirmed = false,
  });

  factory SimpleRaceInfo.fromMap(Map<String, dynamic> map) {
    return SimpleRaceInfo(
      raceId: map['raceId'] as String,
      raceNumber: map['raceNumber'] as String,
      raceName: map['raceName'] as String,
      grade: map['grade'] as String,
      details: map['details'] as String,
      // ★追加: 保存されたデータから isConfirmed を復元
      isConfirmed: map['isConfirmed'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raceId': raceId,
      'raceNumber': raceNumber,
      'raceName': raceName,
      'grade': grade,
      'details': details,
      // ★追加: isConfirmed を保存データに含める
      'isConfirmed': isConfirmed,
    };
  }
}