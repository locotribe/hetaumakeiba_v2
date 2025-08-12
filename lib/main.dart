// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hetaumakeiba_v2/main_scaffold.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // この行を追加

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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