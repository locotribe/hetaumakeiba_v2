import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';

// 修正箇所: インポートパスを修正済み
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/scan_selection_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart'; // 明示的にインポート
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart'; // 明示的にインポート
import 'package:hetaumakeiba_v2/screens/result_page.dart'; // 明示的にインポート
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart'; // 明示的にインポート
import 'package:hetaumakeiba_v2/models/qr_data_model.dart'; // QrDataモデルをインポート

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'ticket_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE qr_data(id INTEGER PRIMARY KEY AUTOINCREMENT, qr_code TEXT, timestamp TEXT)',
      );
    },
    version: 1,
  );
  runApp(MyApp(database: database));
}

class MyApp extends StatefulWidget {
  final Database database;
  const MyApp({super.key, required this.database});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // SavedTicketsListPageState のキーをグローバルに保持
  // このキーは、SavedTicketsListPage の状態を外部から操作するために使用されます。
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // アプリ全体のAppBarのデフォルトスタイルを設定（各ページで上書き可能）
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(172, 234, 231, 1.0), // 背景色を薄い緑に設定
          foregroundColor: Colors.black87, // アイコンとテキストの色を黒に設定
          elevation: 0, // 影をなくす
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // 日本語
      ],
      // アプリのホーム画面を直接HomePageに設定
      // HomePage自体はAppBarを持たず、その子ページがAppBarを持つようにします。
      home: HomePage(savedListKey: _savedListKey), // savedListKey を HomePage に渡す
    );
  }
}
