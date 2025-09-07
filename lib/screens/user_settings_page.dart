// lib/screens/user_settings_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      _cropImage(pickedFile.path);
    }
  }

  Future<void> _cropImage(String filePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: filePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 正方形を指定
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
          resetAspectRatioEnabled: false, // リセットボタンを非表示にする
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
    // 表示名を保存
    await prefs.setString(
        'display_name_${localUserId!}', _displayNameController.text);

    // プロフィール画像を保存
    if (_profileImageFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picture_${localUserId!}.jpg';
      final savedImage =
      await _profileImageFile!.copy(p.join(appDir.path, fileName));
      await prefs.setString(
          'profile_picture_path_${localUserId!}', savedImage.path);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました。')),
      );
      Navigator.of(context).pop(true); // trueを返して更新を通知
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
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}