// lib/screens/user_settings_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/user_model.dart';
import 'package:hetaumakeiba_v2/services/local_auth_service.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class UserSettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  const UserSettingsPage({super.key, required this.onLogout});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _localAuthService = LocalAuthService();
  User? _currentUser;
  bool _hasPassword = false;
  String _loginUsername = '';
  File? _profileImageFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    if (localUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final db = DatabaseHelper();
    final user = await db.getUserByUuid(localUserId!);
    final prefs = await SharedPreferences.getInstance();

    final profileImagePath = prefs.getString('profile_picture_path_${localUserId!}');

    setState(() {
      _currentUser = user;
      _hasPassword = user?.hashedPassword.isNotEmpty ?? false;
      _loginUsername = user?.username ?? '取得エラー';
      _displayNameController.text =
          prefs.getString('display_name_${localUserId!}') ?? user?.username ?? '';
      if (profileImagePath != null) {
        _profileImageFile = File(profileImagePath);
      }
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery || source == ImageSource.camera) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        _cropImage(pickedFile.path);
      }
    }
  }

  Future<void> _cropImage(String filePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: filePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: '画像の切り抜き',
            toolbarColor: Colors.green[900],
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true),
        IOSUiSettings(
          title: '画像の切り抜き',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _profileImageFile = File(croppedFile.path);
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate() || localUserId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'display_name_${localUserId!}', _displayNameController.text);

    final imagePathKey = 'profile_picture_path_${localUserId!}';
    if (_profileImageFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picture_${localUserId!}.jpg';
      final savedImage =
      await _profileImageFile!.copy(p.join(appDir.path, fileName));
      await prefs.setString(imagePathKey, savedImage.path);
    } else {
      // 画像がnullの場合（削除された場合）、保存パスを削除
      await prefs.remove(imagePathKey);
    }

    if (_newPasswordController.text.isNotEmpty) {
      final success = await _localAuthService.updatePassword(
        username: _currentUser!.username,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('現在のパスワードが正しくありません。')),
        );
        setState(() => _isLoading = false);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました。')),
      );
      // 画面を閉じずにローディング状態だけを解除
      setState(() {
        _isLoading = false;
        // パスワードが変更された可能性があるので、状態を再読み込み
        _hasPassword = _newPasswordController.text.isNotEmpty;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      // Navigator.of(context).pop(true); // この行は以前の修正で削除済み
    }
  }

  Future<void> _removePassword() async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パスワードの削除'),
        content: const Text('パスワードを削除すると、ログインIDのみで認証されるようになります。本当に削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final success = await _localAuthService.updatePassword(
      username: _currentUser!.username,
      currentPassword: _currentPasswordController.text,
      newPassword: '',
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードを削除しました。')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('現在のパスワードが正しくありません。')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ユーザー設定'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (builder) {
                      return SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('ギャラリーから選択'),
                              onTap: () {
                                _pickImage(ImageSource.gallery);
                                Navigator.of(context).pop();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_camera),
                              title: const Text('カメラで撮影'),
                              onTap: () {
                                _pickImage(ImageSource.camera);
                                Navigator.of(context).pop();
                              },
                            ),
                            if (_profileImageFile != null) // 画像が設定されている場合のみ削除オプションを表示
                              ListTile(
                                leading: const Icon(Icons.delete, color: Colors.red),
                                title: const Text('画像を削除', style: TextStyle(color: Colors.red)),
                                onTap: () {
                                  setState(() {
                                    _profileImageFile = null;
                                  });
                                  Navigator.of(context).pop();
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _profileImageFile != null
                      ? FileImage(_profileImageFile!)
                      : null,
                  child: _profileImageFile == null
                      ? Icon(Icons.person,
                      size: 60, color: Colors.grey.shade700)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'タップして画像を変更',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: '表示名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '表示名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _loginUsername,
                decoration: const InputDecoration(
                  labelText: 'ログインID (変更不可)',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color.fromARGB(255, 230, 230, 230),
                ),
                readOnly: true,
              ),
              const Divider(height: 48),
              Text(
                'パスワード設定',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              if (_hasPassword)
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: '現在のパスワード',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                      return 'パスワードの変更・削除には現在のパスワードが必要です';
                    }
                    return null;
                  },
                ),

              if (_hasPassword) const SizedBox(height: 16),

              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: _hasPassword ? '新しいパスワード' : 'パスワードを設定',
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return '6文字以上のパスワードを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: _hasPassword ? '新しいパスワード（確認用）' : 'パスワード（確認用）',
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'パスワードが一致しません';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('保存'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, color: Colors.grey),
                label: const Text(
                  'ログアウト',
                  style: TextStyle(color: Colors.grey),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
              if (_hasPassword)
                TextButton(
                  onPressed: _removePassword,
                  child: const Text(
                    'パスワードを削除',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}