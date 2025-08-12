// lib/models/user_mark_model.dart

class UserMark {
  final int? id; // データベースID (自動生成)
  // ★★★ ここからが修正箇所 ★★★
  final String userId; // 所有者を示すユーザーID
  // ★★★ ここまでが修正箇所 ★★★
  final String raceId;
  final String horseId;
  final String mark; // 例: "◎", "〇", "▲", "△", "×"
  final DateTime timestamp;

  UserMark({
    this.id,
    // ★★★ ここからが修正箇所 ★★★
    required this.userId,
    // ★★★ ここまでが修正箇所 ★★★
    required this.raceId,
    required this.horseId,
    required this.mark,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // ★★★ ここからが修正箇所 ★★★
      'userId': userId,
      // ★★★ ここまでが修正箇所 ★★★
      'raceId': raceId,
      'horseId': horseId,
      'mark': mark,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory UserMark.fromMap(Map<String, dynamic> map) {
    return UserMark(
      id: map['id'] as int?,
      // ★★★ ここからが修正箇所 ★★★
      userId: map['userId'] as String? ?? '', // 古いデータにはuserIdがないため、nullの場合は空文字を返す
      // ★★★ ここまでが修正箇所 ★★★
      raceId: map['raceId'] as String,
      horseId: map['horseId'] as String,
      mark: map['mark'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}