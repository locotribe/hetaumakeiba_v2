// lib/models/race_memo_model.dart

class RaceMemo {
  final int? id;
  final String userId;
  final String raceId;
  final String memo; // レース総評（レース後）
  // [追加] レースメモ用途分離: AI予想・買い目（レース前）。総評(memo)とは別スロット (v.2026.9.28+26092801)
  final String? aiPredictionMemo;
  final DateTime timestamp;

  RaceMemo({
    this.id,
    required this.userId,
    required this.raceId,
    required this.memo,
    this.aiPredictionMemo,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'raceId': raceId,
      'memo': memo,
      'aiPredictionMemo': aiPredictionMemo,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RaceMemo.fromMap(Map<String, dynamic> map) {
    return RaceMemo(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      raceId: map['raceId'] as String,
      // [修正] レースメモ用途分離: AI予想のみ入力の行は memo が NULL になり得るため空文字で受ける (v.2026.9.28+26092801)
      memo: (map['memo'] as String?) ?? '',
      aiPredictionMemo: map['aiPredictionMemo'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
