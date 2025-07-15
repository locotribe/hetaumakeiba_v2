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

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50), // 緑色
          foregroundColor: Colors.white, // 文字色を白に
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4CAF50), // 緑色
          foregroundColor: Colors.white, // アイコン色を白に
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF4CAF50), // 選択されたアイコンを緑色に
          unselectedItemColor: Colors.grey, // 未選択のアイコンをグレーに
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
      home: MyHomePage(database: database),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Database database;
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();

  MyHomePage({Key? key, required this.database}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // ホームタブ用
    GlobalKey<NavigatorState>(), // 保存済みタブ用
    GlobalKey<NavigatorState>(), // スキャンタブ用
  ];

  final List<String> _appBarTitles = const [
    'へたうま競馬',
    '保存済み馬券',
    'スキャン',
  ];

  List<Widget> get _widgetOptions => <Widget>[
    Navigator(
      key: _navigatorKeys[0],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const HomePage());
      },
    ),
    Navigator(
      key: _navigatorKeys[1],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
            builder: (context) =>
                SavedTicketsListPage(key: widget._savedListKey));
      },
    ),
    Navigator(
      key: _navigatorKeys[2],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
            builder: (context) => ScanSelectionPage(
              savedListKey: widget._savedListKey,
            ));
      },
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        final NavigatorState? currentNavigator =
            _navigatorKeys[_selectedIndex].currentState;
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          if (mounted) {
            final bool? shouldExit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('アプリを終了しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('終了'),
                  ),
                ],
              ),
            );
            if (shouldExit == true) {
              if (mounted) {
                // SystemNavigator.pop(); // アプリを終了
              }
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitles[_selectedIndex]),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          // 修正箇所: leading プロパティのロジックを改善
          leading: Builder(
            builder: (BuildContext context) {
              final NavigatorState? currentNavigator =
                  _navigatorKeys[_selectedIndex].currentState;
              if (currentNavigator != null && currentNavigator.canPop()) {
                return IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    currentNavigator.pop();
                    // pop 後に AppBar が再ビルドされ、canPop() が再評価されるように setState を呼び出す
                    setState(() {});
                  },
                );
              } else if (_selectedIndex != 0) {
                // 現在のタブがホームタブ以外で、かつそのタブのルートにいる場合、ホームタブに戻るボタンを表示
                return IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 0; // ホームタブに切り替える
                    });
                  },
                );
              } else {
                // ホームタブのルートにいる場合、戻るボタンは表示しない
                // 修正箇所: nullの代わりにSizedBox.shrink()を返す
                return const SizedBox.shrink();
              }
            },
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'ホーム',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: '保存済み',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner),
              label: 'スキャン',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}