// lib/models/race_memo_model.dart

class RaceMemo {
  final int? id;
  final String userId;
  final String raceId;
  final String memo;
  final DateTime timestamp;

  RaceMemo({
    this.id,
    required this.userId,
    required this.raceId,
    required this.memo,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'raceId': raceId,
      'memo': memo,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RaceMemo.fromMap(Map<String, dynamic> map) {
    return RaceMemo(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      raceId: map['raceId'] as String,
      memo: map['memo'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}