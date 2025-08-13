// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hetaumakeiba_v2/main_scaffold.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // この行を追加
import 'package:shared_preferences/shared_preferences.dart'; // この行を追加
import 'package:uuid/uuid.dart'; // この行を追加

// アプリ全体で利用する永続的なローカルIDを保持する変数
String? localUserId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 永続的なローカルユーザーIDの初期化
  final prefs = await SharedPreferences.getInstance();
  localUserId = prefs.getString('local_user_id');
  if (localUserId == null) {
    localUserId = const Uuid().v4();
    await prefs.setString('local_user_id', localUserId!);
    print("Generated new local user ID: $localUserId");
  } else {
    print("Loaded existing local user ID: $localUserId");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // この行を追加
  );
  // 匿名認証によるサインイン処理
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      print("Signed in with temporary account.");
    } catch (e) {
      print("Error signing in anonymously: $e");
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(172, 234, 231, 1.0),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        // FABがBottomNavigationBarにめり込むデザインのための設定
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''),
      ],
      // アプリの開始点をMainScaffoldに変更
      home: const MainScaffold(),
    );
  }
}