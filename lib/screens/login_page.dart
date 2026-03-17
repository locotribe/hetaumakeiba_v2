// lib/screens/login_page.dart
import 'dart:convert'; // ★追加
import 'dart:io'; // ★追加

import 'package:archive/archive.dart'; // ★追加
import 'package:file_picker/file_picker.dart'; // ★追加
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart'; // ★追加
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/screens/register_page.dart';
import 'package:hetaumakeiba_v2/services/local_auth_service.dart';
import 'package:path/path.dart' as p; // ★追加
import 'package:path_provider/path_provider.dart'; // ★追加
import 'package:shared_preferences/shared_preferences.dart'; // ★追加
import 'package:sqflite/sqflite.dart';

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

  // ★新規追加: バックアップ用パスワードの入力ダイアログ
  Future<String?> _showBackupPasswordDialog() async {
    String password = '';
    bool obscureText = true;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('バックアップの復元'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('バックアップ作成時に設定した「専用パスワード」を入力してください。', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: obscureText,
                    onChanged: (val) => password = val,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('パスワードを入力してください')));
                      return;
                    }
                    Navigator.pop(context, password);
                  },
                  child: const Text('復元'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ★新規追加: ZIPファイルのインポート処理
  Future<void> _importDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Android等での互換性のためanyを使用
      );

      if (result == null || result.files.single.path == null) {
        return; // キャンセル
      }

      setState(() {
        _isLoading = true;
      });

      // 1. ファイルの読み込みとZIP解凍
      final sourcePath = result.files.single.path!;
      final bytes = await File(sourcePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 2. メタデータ (backup_meta.json) の検索と検証
      final metaFile = archive.findFile('backup_meta.json');
      if (metaFile == null) {
        throw Exception('有効なバックアップファイルではありません。(メタデータが存在しません)');
      }

      final metaMap = jsonDecode(utf8.decode(metaFile.content as List<int>));
      final savedHash = metaMap['password_hash'] as String?;

      if (savedHash == null) {
        throw Exception('バックアップファイルが破損しています。');
      }

      setState(() {
        _isLoading = false; // パスワード入力のため一旦ローディング解除
      });

      // 3. パスワードの要求と照合
      if (!mounted) return;
      final password = await _showBackupPasswordDialog();
      if (password == null) return; // キャンセル

      setState(() {
        _isLoading = true;
      });

      final inputHash = _localAuthService.hashPassword(password);
      if (inputHash != savedHash) {
        throw Exception('パスワードが正しくありません。');
      }

      // 4. 復元処理の実行 (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // 既存の設定をすべて消去
      final Map<String, dynamic> prefsData = metaMap['shared_preferences'] ?? {};
      for (final key in prefsData.keys) {
        final value = prefsData[key];
        if (value is String) await prefs.setString(key, value);
        else if (value is int) await prefs.setInt(key, value);
        else if (value is double) await prefs.setDouble(key, value);
        else if (value is bool) await prefs.setBool(key, value);
        else if (value is List) {
          await prefs.setStringList(key, (value).map((e) => e.toString()).toList());
        }
      }

      // 5. 復元処理の実行 (DBファイル・画像群)
      final databasePath = await getDatabasesPath();
      final dbPath = p.join(databasePath, DbConstants.dbName);
      final appDir = await getApplicationDocumentsDirectory();

      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'backup_meta.json') continue; // メタデータはスキップ

          if (file.name == DbConstants.dbName) {
            // DBファイルの上書き
            await File(dbPath).writeAsBytes(file.content as List<int>);
          } else {
            // 画像などのファイルの上書き
            final outFile = File(p.join(appDir.path, file.name));
            outFile.parent.createSync(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
      }

      // 6. 完了報告
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('復元完了', style: TextStyle(color: Colors.green)),
            content: const Text('データの復元が完了しました。設定されたログインIDでログインしてください。'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('復元中にエラーが発生しました: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                  const Divider(height: 48), // ★追加: セパレーター
                  // ★新規追加: 復元ボタン
                  TextButton.icon(
                    onPressed: _isLoading ? null : _importDatabase,
                    icon: const Icon(Icons.settings_backup_restore, color: Colors.orange),
                    label: const Text(
                      'バックアップファイルから復元',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
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