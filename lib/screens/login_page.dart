// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/services/local_auth_service.dart';
import 'package:hetaumakeiba_v2/screens/register_page.dart';

class LoginPage extends StatefulWidget {
  final Function(User) onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuthService = LocalAuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = await _localAuthService.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (mounted) {
        if (user != null) {
          widget.onLoginSuccess(user);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログインIDまたはパスワードが違います。')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegisterPage(
          onRegisterSuccess: () {
            Navigator.of(context).pop(); // 登録成功したらログイン画面に戻る
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'ログインID'),
                    autofillHints: const [AutofillHints.username],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'ログインIDを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'パスワードを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _handleLogin,
                          child: const Text('ログイン'),
                        ),
                  TextButton(
                    onPressed: _navigateToRegister,
                    child: const Text('新しいユーザーを登録'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
