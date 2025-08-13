// lib/models/user_mark_model.dart

class UserMark {
  final int? id; // データベースID (自動生成)
  final String userId; // 所有者を示すユーザーID
  final String raceId;
  final String horseId;
  final String mark; // 例: "◎", "〇", "▲", "△", "×"
  final DateTime timestamp;

  UserMark({
    this.id,
    required this.userId,
    required this.raceId,
    required this.horseId,
    required this.mark,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'raceId': raceId,
      'horseId': horseId,
      'mark': mark,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory UserMark.fromMap(Map<String, dynamic> map) {
    return UserMark(
      id: map['id'] as int?,
      userId: map['userId'] as String? ?? '', // 古いデータにはuserIdがないため、nullの場合は空文字を返す
      raceId: map['raceId'] as String,
      horseId: map['horseId'] as String,
      mark: map['mark'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}