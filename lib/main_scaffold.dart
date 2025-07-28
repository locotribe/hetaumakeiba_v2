// lib/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/analytics_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/settings_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  // ▼▼▼ 履歴ページの状態を管理するためのGlobalKey ▼▼▼
  final GlobalKey<SavedTicketsListPageState> _savedListKey = GlobalKey<SavedTicketsListPageState>();

  late final List<Widget> _pages;
  static const List<String> _pageTitles = ['ホーム', '購入履歴', '集計'];

  bool _isFabExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      // ▼▼▼ HomePageから不要なキーの受け渡しを削除 ▼▼▼
      const HomePage(),
      // ▼▼▼ SavedTicketsListPageにGlobalKeyを正しく設定 ▼▼▼
      SavedTicketsListPage(key: _savedListKey),
      const AnalyticsPage(),
    ];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // 履歴タブがタップされたときに、リストをリフレッシュする
    if (index == 1) {
      _savedListKey.currentState?.reloadData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ).then((_) {
                // 設定ページから戻ってきたときに履歴をリロードする
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
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '履歴'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: '集計'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded)
            ScaleTransition(
              scale: _animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton(
                  heroTag: 'galleryFab',
                  onPressed: () {
                    _toggleFab();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GalleryQrScannerPage(savedListKey: _savedListKey),
                      ),
                    );
                  },
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.image),
                ),
              ),
            ),
          if (_isFabExpanded)
            ScaleTransition(
              scale: _animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton(
                  heroTag: 'cameraFab',
                  onPressed: () {
                    _toggleFab();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QRScannerPage(savedListKey: _savedListKey),
                      ),
                    );
                  },
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.camera_alt),
                ),
              ),
            ),
          FloatingActionButton(
            heroTag: 'mainFab',
            onPressed: _toggleFab,
            backgroundColor: _isFabExpanded ? Colors.grey : Colors.green,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: Align(
              alignment: const Alignment(0.0, -0.4),
              child: _isFabExpanded
                  ? const Text(
                'Ｘ',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.black54,
                ),
              )
                  : const Text(
                '＋',
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
