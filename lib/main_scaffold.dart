// lib/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/analytics_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/settings_page.dart';
import 'package:hetaumakeiba_v2/screens/jyusyoichiran_page.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final GlobalKey<SavedTicketsListPageState> _savedListKey = GlobalKey<SavedTicketsListPageState>();

  late final List<Widget> _pages;
  static const List<String> _pageTitles = ['ホーム', '重賞', '購入履歴', '集計'];

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const HomePage(), // 0: ホーム
      const JyusyoIchiranPage(), // 1: 重賞
      SavedTicketsListPage(key: _savedListKey), // 2: 履歴
      const AnalyticsPage(), // 3: 集計
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _savedListKey.currentState?.reloadData();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 集計ページ(index: 3)が選択されているかどうか
    final bool isAnalyticsPageSelected = _selectedIndex == 3;

    return Scaffold(
      // 集計ページ以外でのみAppBarを表示する
      appBar: isAnalyticsPageSelected
          ? null
          : AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ).then((_) {
                _savedListKey.currentState?.reloadData();
              });
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '重賞'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '履歴'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: '集計'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: SpeedDial(
          child: ClipOval(
            child: Image.asset(
              'assets/images/icon_baken.png',
              width: 56.0, // FABの標準サイズ
              height: 56.0,
              fit: BoxFit.contain,
            ),
          ),
          activeChild: ClipOval(
            child: Image.asset(
              'assets/images/icon_baken.png',
              width: 56.0,
              height: 56.0,
              fit: BoxFit.contain,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0.0, // 影を無効化
          renderOverlay: false, // オーバーレイを無効化
          shape: const CircleBorder(), // ボタンの形状を円形に
          overlayColor: Colors.transparent,
          overlayOpacity: 0.0,
          foregroundColor: Colors.transparent,
          animatedIconTheme: const IconThemeData(size: 22.0),
          curve: Curves.easeOut,
          animationDuration: const Duration(milliseconds: 150),
          childrenButtonSize: const Size(56.0, 56.0),
          children: [
            SpeedDialChild(
              child: const Icon(Icons.camera_alt),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              label: 'カメラで読み取る',
              elevation: 0.0,
              shape: const CircleBorder(), // 子ボタンも円形に
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QRScannerPage(savedListKey: _savedListKey),
                  ),
                );
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.image),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              label: '画像から読み取る',
              elevation: 0.0,
              shape: const CircleBorder(), // 子ボタンも円形に
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GalleryQrScannerPage(savedListKey: _savedListKey),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

    );
  }
}
