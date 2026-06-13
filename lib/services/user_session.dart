// lib/services/user_session.dart

// [追加] localUserIdグローバル変数を廃止し、シングルトンで一元管理するためのサービスクラス (v.13.40.4)
/// アプリ全体で利用するログイン中ユーザーのローカルIDを保持するシングルトンクラス。
class UserSession {
  static final UserSession _instance = UserSession._internal();

  factory UserSession() => _instance;

  UserSession._internal();

  String? localUserId;
}
