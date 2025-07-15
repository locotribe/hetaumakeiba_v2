// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// 各画面をインポート
import 'package:hetaumakeiba_v2/screens/home_page.dart'; // 新規作成したホーム画面
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // 保存済みリスト画面
import 'package:hetaumakeiba_v2/screens/scan_selection_page.dart'; // スキャン選択画面
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart'; // カメラQRスキャナーページ
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart'; // ギャラリーQRスキャナーページ
import 'package:hetaumakeiba_v2/screens/result_page.dart'; // 解析結果ページを再インポート
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart'; // 保存済み馬券詳細ページ (修正済み)
import 'package:hetaumakeiba_v2/models/qr_data_model.dart'; // QrDataモデル

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

  // 各タブのNavigatorに割り当てるGlobalKey
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // For Home tab
    GlobalKey<NavigatorState>(), // For Saved tab
    GlobalKey<NavigatorState>(), // For Scan tab
  ];

  // SavedTicketsListPageState にアクセスするためのGlobalKey
  final GlobalKey<SavedTicketsListPageState> _savedTicketsListKey = GlobalKey<SavedTicketsListPageState>();

  // 各タブに対応するウィジェットのリスト
  late final List<Widget> _widgetOptions; // late を使用してinitStateで初期化

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      // ホームタブ
      Navigator(
        key: _navigatorKeys[0], // Keyを割り当て
        onGenerateRoute: (settings) {
          return MaterialPageRoute(builder: (context) => const HomePage());
        },
      ),
      // 保存済みタブ
      Navigator(
        key: _navigatorKeys[1], // Keyを割り当て
        onGenerateRoute: (settings) {
          Widget page;
          if (settings.name == '/detail') {
            final qrData = settings.arguments as QrData;
            // SavedTicketDetailPage を直接使用
            page = SavedTicketDetailPage(qrData: qrData);
          } else {
            page = SavedTicketsListPage(key: _savedTicketsListKey); // Keyを割り当て
          }
          return MaterialPageRoute(builder: (context) => page);
        },
      ),
      // スキャンタブ
      Navigator(
        key: _navigatorKeys[2], // Keyを割り当て
        onGenerateRoute: (settings) {
          Widget page;
          if (settings.name == '/camera_scanner') {
            final args = settings.arguments as Map<String, dynamic>?;
            // QRScannerPage を直接使用
            page = QRScannerPage(
              scanMethod: args?['scanMethod'] ?? 'camera',
              savedListKey: _savedTicketsListKey, // Keyを渡す
            );
          } else if (settings.name == '/gallery_scanner') {
            final args = settings.arguments as Map<String, dynamic>?;
            // GalleryQrScannerPage を直接使用
            page = GalleryQrScannerPage(
              scanMethod: args?['scanMethod'] ?? 'gallery',
              savedListKey: _savedTicketsListKey, // Keyを渡す
            );
          } else if (settings.name == '/result') { // 新しいResultPageのルートを追加
            final parsedResult = settings.arguments as Map<String, dynamic>?;
            // ResultPage を直接使用
            page = ResultPage(parsedResult: parsedResult);
          }
          else {
            page = ScanSelectionPage(savedListKey: _savedTicketsListKey); // Keyを渡す
          }
          return MaterialPageRoute(builder: (context) => page);
        },
      ),
    ];
  }

  // 各タブのタイトル
  static const List<String> _appBarTitles = <String>[
    '馬券QRリーダー', // ホーム
    '保存された馬券', // 保存済み
    'スキャン', // スキャン
  ];

  // BottomNavigationBarのアイテムがタップされたときの処理
  void _onItemTapped(int index) {
    // スキャンタブに切り替える際に、そのタブのナビゲーションスタックをリセット
    if (index == 2 && _selectedIndex != 2) { // スキャンタブへの切り替え時のみ
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    // 保存済みタブに切り替える際に、データをリロード
    if (index == 1 && _selectedIndex != 1) { // 保存済みタブへの切り替え時のみ
      _savedTicketsListKey.currentState?.loadData();
    }
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
        // 現在のタブのNavigatorがpopできる場合のみ戻るボタンを表示
        leading: _navigatorKeys[_selectedIndex].currentState?.canPop() == true
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 現在のタブのNavigatorでpopを試みる
            _navigatorKeys[_selectedIndex].currentState?.pop();
          },
        )
            : null, // popできない場合は戻るボタンを表示しない
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
