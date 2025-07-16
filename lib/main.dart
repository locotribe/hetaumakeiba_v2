import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';

// 修正箇所: インポートパスを修正済み
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
// scan_selection_pageは直接使われなくなるため、コメントアウトまたは削除も可能ですが、
// 今回は「他のコードをいじらない」指示に基づき、そのまま残します。
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
      // データベースが初めて作成されるときにqr_dataテーブルを作成
      return db.execute(
        'CREATE TABLE qr_data(id INTEGER PRIMARY KEY AUTOINCREMENT, qrCode TEXT, timestamp TEXT)',
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
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();

  // ボトムナビゲーションに関連する状態とメソッドを削除
  // int _selectedIndex = 0; // 削除
  // static final List<Widget> _widgetOptions = <Widget>[ // 削除
  //   const HomePage(),
  //   const SavedTicketsListPage(),
  //   ScanSelectionPage(savedListKey: _savedListKey),
  // ];

  // void _onItemTapped(int index) { // 削除
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // 日本語
      ],
      home: Scaffold(
        appBar: AppBar(
          title: const Text('へたうま競馬'),
          // 戻るボタンのロジックを修正
          // _selectedIndex に依存していた部分を削除し、HomePage がルートになるため戻るボタンは自動で表示しない
          automaticallyImplyLeading: false, // 戻るボタンを自動で表示しない
          // 以前の戻るボタンのロジックは削除
          // leading: Builder(
          //   builder: (BuildContext context) {
          //     if (Navigator.of(context).canPop()) {
          //       return IconButton(
          //         icon: const Icon(Icons.arrow_back),
          //         onPressed: () {
          //           Navigator.of(context).pop();
          //           setState(() {});
          //         },
          //       );
          //     } else if (_selectedIndex != 0) {
          //       return IconButton(
          //         icon: const Icon(Icons.arrow_back),
          //         onPressed: () {
          //           setState(() {
          //             _selectedIndex = 0;
          //           });
          //         },
          //       );
          //     } else {
          //       return const SizedBox.shrink();
          //     }
          //   },
          // ),
        ),
        // ボトムナビゲーションバーを完全に削除
        // bottomNavigationBar: BottomNavigationBar(
        //   items: const <BottomNavigationBarItem>[
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.home),
        //       label: 'ホーム',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.list),
        //       label: '保存済み',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.qr_code_scanner),
        //       label: 'スキャン',
        //     ),
        //   ],
        //   currentIndex: _selectedIndex,
        //   onTap: _onItemTapped,
        // ),
        // body を直接 HomePage に変更し、_savedListKey を渡す
        body: HomePage(savedListKey: _savedListKey),
      ),
    );
  }
}
