// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // この段階では、まだセッション管理を実装していないため、
    // 常に未ログイン状態としてLoginPageを表示します。
    // 今後のステップでこの部分を実装します。
    setState(() {
      _currentUser = null;
    });
  }

  void _handleLoginSuccess(User user) async {
    final prefs = await SharedPreferences.getInstance();
    // ログインに成功したユーザーのuuidをセッション情報として保存
    await prefs.setString('logged_in_user_uuid', user.uuid);

    // グローバルなlocalUserIdも更新
    localUserId = user.uuid;

    setState(() {
      _currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return LoginPage(onLoginSuccess: _handleLoginSuccess);
    } else {
      return const MainScaffold();
    }
  }
}