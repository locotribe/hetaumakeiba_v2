// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/main_scaffold.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/screens/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _currentUser;
  bool _isLoading = true; // 読み込み状態を管理するフラグ

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    print('[AUTH_GATE] Checking login status...');
    final prefs = await SharedPreferences.getInstance();
    final userUuid = prefs.getString('logged_in_user_uuid');
    print('[AUTH_GATE] Found UUID in SharedPreferences: $userUuid');

    User? user;
    if (userUuid != null) {
      final dbHelper = DatabaseHelper();
      user = await dbHelper.getUserByUuid(userUuid);
      print('[AUTH_GATE] User fetched from DB with UUID: ${user?.username}');
    }

    // グローバルなlocalUserIdも設定
    localUserId = user?.uuid;

    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  void _handleLoginSuccess(User user) async {
    final prefs = await SharedPreferences.getInstance();
    // ログインに成功したユーザーのuuidをセッション情報として保存
    await prefs.setString('logged_in_user_uuid', user.uuid);
    print('[AUTH_GATE] Saved UUID to SharedPreferences: ${user.uuid}');

    // グローバルなlocalUserIdも更新
    localUserId = user.uuid;

    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_uuid'); // 保存されているセッション情報を削除

    // グローバルなlocalUserIdもクリア
    localUserId = null;

    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return LoginPage(onLoginSuccess: _handleLoginSuccess);
    } else {
      return MainScaffold(onLogout: _handleLogout);
    }
  }
}