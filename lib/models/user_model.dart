// lib/models/user_model.dart
class User {
  final int? id; // データベース用のユニークID（自動採番）
  final String uuid; // ユーザーを永続的に識別するための一意なID
  final String username; // ユーザーが設定する名前
  final String hashedPassword; // ハッシュ化されたパスワード
  final DateTime createdAt; // 作成日時

  User({
    this.id,
    required this.uuid,
    required this.username,
    required this.hashedPassword,
    required this.createdAt,
  });
}