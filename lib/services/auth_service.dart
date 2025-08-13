// lib/services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/main.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // アカウント連携とデータ移行を開始するメインのメソッド
  Future<void> linkAccountAndMigrateData(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      // 匿名ユーザーでない場合は何もしない
      return;
    }

    // メールアドレスとパスワードの入力を求めるダイアログを表示
    final credentials = await _showLinkDialog(context);

    if (credentials == null || !context.mounted) {
      // ユーザーがキャンセルした場合は何もしない
      return;
    }

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 匿名アカウントに新しい認証情報（メール・パスワード）をリンクする
      final userCredential = await user.linkWithCredential(credentials);
      final newFirebaseUser = userCredential.user;
      if (newFirebaseUser == null) {
        throw Exception('アカウントの作成に失敗しました。');
      }

      // データ移行処理 (ローカルIDを元にデータを移行)
      await _migrateLocalDataToFirestore(newFirebaseUser.uid);

      // 同期フラグを有効にする
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isCloudSyncEnabled_${newFirebaseUser.uid}', true);

      if (context.mounted) {
        Navigator.of(context).pop(); // ローディングを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウントの作成とデータ同期が完了しました。')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // ローディングを閉じる
        // エラー処理
        String message = 'エラーが発生しました。';
        if (e.code == 'email-already-in-use') {
          message = 'このメールアドレスは既に使用されています。';
        } else if (e.code == 'weak-password') {
          message = 'パスワードは6文字以上で設定してください。';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // ローディングを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予期せぬエラーが発生しました: $e')),
        );
      }
    }
  }

  // ユーザーにメールとパスワードを入力させるダイアログ
  Future<AuthCredential?> _showLinkDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return await showDialog<AuthCredential?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アカウントを作成'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains('@')) ? '有効なメールアドレスを入力してください' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                  validator: (value) => (value == null || value.length < 6) ? '6文字以上のパスワードを入力してください' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final credential = EmailAuthProvider.credential(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                  Navigator.of(context).pop(credential);
                }
              },
              child: const Text('作成'),
            ),
          ],
        );
      },
    );
  }

  // 実際のデータ移行処理
  Future<void> _migrateLocalDataToFirestore(String newFirebaseUserId) async {
    final db = await _dbHelper.database;
    final batch = _firestore.batch();

    // 移行元のIDとして永続ローカルIDを使用
    final String? sourceUserId = localUserId;
    if (sourceUserId == null) {
      // ローカルIDがない場合は移行するデータもないので終了
      return;
    }

    // 1. QRデータを移行
    final qrDataList = await _dbHelper.getAllQrData(sourceUserId);
    for (final qrData in qrDataList) {
      final docRef = _firestore.collection('users').doc(newFirebaseUserId).collection('qr_data').doc();
      final firestoreMap = qrData.toMap();
      firestoreMap['userId'] = newFirebaseUserId; // userIdを新しいFirebaseのものに書き換える
      batch.set(docRef, firestoreMap);
    }

    // 2. ユーザーの印データを移行
    final userMarksMaps = await db.query('user_marks', where: 'userId = ?', whereArgs: [sourceUserId]);
    for (final markMap in userMarksMaps) {
      final docRef = _firestore.collection('users').doc(newFirebaseUserId).collection('user_marks').doc();
      final firestoreMap = Map<String, dynamic>.from(markMap);
      firestoreMap['userId'] = newFirebaseUserId; // userIdを新しいFirebaseのものに書き換える
      batch.set(docRef, firestoreMap);
    }

    // 3. フィードデータを移行
    final feedList = await _dbHelper.getAllFeeds(sourceUserId);
    for (final feed in feedList) {
      final docRef = _firestore.collection('users').doc(newFirebaseUserId).collection('user_feeds').doc();
      final firestoreMap = feed.toMap();
      firestoreMap['userId'] = newFirebaseUserId; // userIdを新しいFirebaseのものに書き換える
      batch.set(docRef, firestoreMap);
    }

    // バッチ処理を実行して、全てのデータを一度に書き込む
    await batch.commit();

    // 移行完了後、ローカルDBのIDも新しいFirebaseのものに更新する
    await db.transaction((txn) async {
      await txn.update('qr_data', {'userId': newFirebaseUserId}, where: 'userId = ?', whereArgs: [sourceUserId]);
      await txn.update('user_marks', {'userId': newFirebaseUserId}, where: 'userId = ?', whereArgs: [sourceUserId]);
      await txn.update('user_feeds', {'userId': newFirebaseUserId}, where: 'userId = ?', whereArgs: [sourceUserId]);
      await txn.update('horse_memos', {'userId': newFirebaseUserId}, where: 'userId = ?', whereArgs: [sourceUserId]);
      await txn.update('analytics_aggregates', {'userId': newFirebaseUserId}, where: 'userId = ?', whereArgs: [sourceUserId]);
    });

    // 最後に、端末に保存されているローカルID自体も新しいFirebaseIDに書き換える
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_user_id', newFirebaseUserId);
    localUserId = newFirebaseUserId; // グローバル変数も更新
  }
}