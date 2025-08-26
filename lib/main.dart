// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hetaumakeiba_v2/screens/auth_gate.dart';


// アプリ全体で利用する永続的なローカルIDを保持する変数
String? localUserId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[900],
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: const TextStyle(
            color: Colors.white,      // 文字色を白に指定
            fontSize: 20,             // フォントサイズを指定
            fontWeight: FontWeight.bold, // 文字の太さを指定
          ),
        ),

        // ★★★ TabBarのテーマ設定を修正 ★★★
        tabBarTheme: TabBarThemeData( // 'TabBarTheme' -> 'TabBarThemeData' に修正
          labelColor: Colors.white, // 選択中のタブの文字色
          unselectedLabelColor: Colors.grey[300], // 未選択のタブの文字色
          indicatorColor: Colors.white, // 下線の色
        ),

        // FABがBottomNavigationBarにめり込むデザインのための設定
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.green[900],
          selectedItemColor: Colors.white,
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
      home: const AuthGate(),
    );
  }
}
