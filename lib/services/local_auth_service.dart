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
      final hashedPassword = hashPassword(password);
      final newUser = User(
        uuid: const Uuid().v4(),
        username: username,
        hashedPassword: hashedPassword,
        createdAt: DateTime.now(),
      );
      await _dbHelper.insertUser(newUser);
      return newUser;
    } catch (e) {
      // ユーザー名の重複などでエラーが発生した場合
      print('User registration failed: $e');
      return null;
    }
  }

  // ログイン処理
  Future<User?> login(String username, String password) async {
    final userFromDb = await _dbHelper.getUserByUsername(username);

    if (userFromDb == null) {
      return null; // ユーザーが存在しない
    }

    final hashedPassword = hashPassword(password);
    if (userFromDb.hashedPassword == hashedPassword) {
      return userFromDb; // パスワードが一致
    }

    return null; // パスワードが不一致
  }
}