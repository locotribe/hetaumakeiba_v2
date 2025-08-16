// lib/models/horse_memo_model.dart
class HorseMemo {
  final int? id; // データベース用のユニークID（自動採番）
  final String userId; // どのユーザーのメモか識別するためのID
  final String raceId; // どのレースのメモか識別するためのID
  final String horseId; // どの馬のメモか識別するためのID
  final String? predictionMemo; // 予想メモの文字列（nullable）
  final String? reviewMemo; // 総評メモの文字列（nullable）
  final double? odds;
  final int? popularity;
  final DateTime timestamp; // 最終更新日時

  HorseMemo({
    this.id,
    required this.userId,
    required this.raceId,
    required this.horseId,
    this.predictionMemo,
    this.reviewMemo,
    this.odds,
    this.popularity,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'raceId': raceId,
      'horseId': horseId,
      'predictionMemo': predictionMemo,
      'reviewMemo': reviewMemo,
      'odds': odds,
      'popularity': popularity,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HorseMemo.fromMap(Map<String, dynamic> map) {
    return HorseMemo(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      raceId: map['raceId'] as String,
      horseId: map['horseId'] as String,
      predictionMemo: map['predictionMemo'] as String?,
      reviewMemo: map['reviewMemo'] as String?,
      odds: map['odds'] as double?,
      popularity: map['popularity'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}