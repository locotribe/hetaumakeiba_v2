// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// 各画面をインポート
import 'package:hetaumakeiba_v2/screens/home_page.dart'; // 新規作成したホーム画面
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // 保存済みリスト画面
import 'package:hetaumakeiba_v2/screens/scan_selection_page.dart'; // スキャン選択画面

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale("ja", "JP")],
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(172, 234, 231, 1.0), // 明るいテーマのAppBar色
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
        colorScheme: const ColorScheme.dark(primary: Colors.green),
      ),
      themeMode: ThemeMode.system,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0; // 現在選択されているタブのインデックス

  // 各タブに対応するウィジェットのリスト
  // ここで各画面のインスタンスを作成します
  static final List<Widget> _widgetOptions = <Widget>[
    const HomePage(), // ホーム画面
    const SavedTicketsListPage(), // 保存済みリスト画面
    const ScanSelectionPage(), // スキャン選択画面
  ];

  // 各タブのタイトル
  static const List<String> _appBarTitles = <String>[
    '馬券QRリーダー', // ホーム
    '保存された馬券', // 保存済み
    'スキャン選択', // スキャン
  ];

  // BottomNavigationBarのアイテムがタップされたときの処理
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]), // 選択されたタブに応じてタイトルを変更
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions, // 選択されたタブのウィジェットを表示
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home), // ホームアイコン
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt), // 保存済みリストのアイコン
            label: '保存済み',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner), // スキャンのアイコン
            label: 'スキャン',
          ),
        ],
        currentIndex: _selectedIndex, // 現在選択されているインデックス
        selectedItemColor: Theme.of(context).primaryColor, // 選択されたアイテムの色
        onTap: _onItemTapped, // タップ時の処理
      ),
    );
  }
}
