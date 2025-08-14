// lib/screens/register_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/services/local_auth_service.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onRegisterSuccess;

  const RegisterPage({super.key, required this.onRegisterSuccess});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuthService = LocalAuthService();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = await _localAuthService.registerUser(
        _usernameController.text,
        _passwordController.text,
      );

      if (mounted) {
        if (user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザー登録が完了しました。')),
          );
          widget.onRegisterSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('このユーザー名は既に使用されています。')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
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
        title: const Text('ユーザー登録'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'ユーザー名'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ユーザー名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return '6文字以上のパスワードを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _handleRegister,
                  child: const Text('登録'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}