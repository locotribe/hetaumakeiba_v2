// lib/services/local_auth_service.dart
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:uuid/uuid.dart';

class LocalAuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // パスワードをハッシュ化する
  String hashPassword(String password) {
    final bytes = utf8.encode(password); // パスワードをUTF-8のバイトに変換
    final digest = sha256.convert(bytes); // SHA-256でハッシュ化
    return digest.toString();
  }

  // ユーザーを登録する
  Future<User?> registerUser(String username, String password) async {
    try {
      // パスワードが入力されている場合のみハッシュ化し、空の場合は空文字を保存
      final hashedPassword = password.isNotEmpty ? hashPassword(password) : '';

      final newUser = User(
        uuid: const Uuid().v4(),
        username: username,
        hashedPassword: hashedPassword,
        createdAt: DateTime.now(),
      );
      print('[AUTH_SERVICE] Registering user: ${newUser.username}, uuid: ${newUser.uuid}');
      await _dbHelper.insertUser(newUser);
      print('[AUTH_SERVICE] User registration successful.');
      return newUser;
    } catch (e) {
      // ユーザー名の重複などでエラーが発生した場合
      print('[AUTH_SERVICE] User registration failed: $e');
      return null;
    }
  }

  // ログイン処理
  Future<User?> login(String username, String password) async {
    print('[AUTH_SERVICE] Attempting to log in user: $username');
    final userFromDb = await _dbHelper.getUserByUsername(username);

    if (userFromDb == null) {
      print('[AUTH_SERVICE] Login failed: User not found in DB.');
      return null; // ユーザーが存在しない
    }

    // データベースにハッシュ化されたパスワードが保存されているかチェック
    if (userFromDb.hashedPassword.isEmpty) {
      // パスワードが設定されていないユーザーの場合、IDのみでログイン成功
      print('[AUTH_SERVICE] Login successful for user (no password): ${userFromDb.username}');
      return userFromDb;
    } else {
      // パスワードが設定されているユーザーの場合、入力されたパスワードと照合
      final hashedPassword = hashPassword(password);
      if (userFromDb.hashedPassword == hashedPassword) {
        print('[AUTH_SERVICE] Login successful for user: ${userFromDb.username}');
        return userFromDb; // パスワードが一致
      }
    }
    print('[AUTH_SERVICE] Login failed: Password does not match.');
    return null; // パスワードが不一致
  }
  /// パスワードを更新または削除する
  Future<bool> updatePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final userFromDb = await _dbHelper.getUserByUsername(username);
    if (userFromDb == null) {
      return false; // ユーザーが存在しない
    }

    // パスワードが設定されている場合、現在のパスワードが正しいか検証する
    if (userFromDb.hashedPassword.isNotEmpty) {
      final currentHashed = hashPassword(currentPassword);
      if (userFromDb.hashedPassword != currentHashed) {
        return false; // 現在のパスワードが不一致
      }
    }

    // 新しいパスワードをハッシュ化（空の場合は空文字のまま）
    final newHashedPassword = newPassword.isNotEmpty ? hashPassword(newPassword) : '';

    // データベースを更新
    final updatedUser = User(
      id: userFromDb.id,
      uuid: userFromDb.uuid,
      username: userFromDb.username,
      hashedPassword: newHashedPassword,
      createdAt: userFromDb.createdAt,
    );
    await _dbHelper.updateUser(updatedUser);
    return true;
  }
}