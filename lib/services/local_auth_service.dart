// lib/services/local_auth_service.dart
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:uuid/uuid.dart';

class LocalAuthService {
  final UserRepository _userRepo = UserRepository();

  // パスワードをハッシュ化する
  String hashPassword(String password) {
    final bytes = utf8.encode(password); // パスワードをUTF-8のバイトに変換
    final digest = sha256.convert(bytes); // SHA-256でハッシュ化
    return digest.toString();
  }

  // ユーザーを登録する
  Future<User?> registerUser(String username, String password) async {
    try {
      final hashedPassword = password.isNotEmpty ? hashPassword(password) : '';

      final newUser = User(
        uuid: const Uuid().v4(),
        username: username,
        hashedPassword: hashedPassword,
        createdAt: DateTime.now(),
      );

      await _userRepo.insertUser(newUser);
      return newUser;
    } catch (e) {
      return null;
    }
  }

  // ログイン処理
  Future<User?> login(String username, String password) async {
    final userFromDb = await _userRepo.getUserByUsername(username);

    if (userFromDb == null) {
      return null;
    }

    if (userFromDb.hashedPassword.isEmpty) {
      return userFromDb;
    } else {
      final hashedPassword = hashPassword(password);
      if (userFromDb.hashedPassword == hashedPassword) {
        return userFromDb;
      }
    }
    return null;
  }

  /// パスワードを更新または削除する
  Future<bool> updatePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final userFromDb = await _userRepo.getUserByUsername(username);
    if (userFromDb == null) {
      return false;
    }

    if (userFromDb.hashedPassword.isNotEmpty) {
      final currentHashed = hashPassword(currentPassword);
      if (userFromDb.hashedPassword != currentHashed) {
        return false;
      }
    }

    final newHashedPassword = newPassword.isNotEmpty ? hashPassword(newPassword) : '';

    final updatedUser = User(
      id: userFromDb.id,
      uuid: userFromDb.uuid,
      username: userFromDb.username,
      hashedPassword: newHashedPassword,
      createdAt: userFromDb.createdAt,
    );
    await _userRepo.updateUser(updatedUser);
    return true;
  }
}