// lib/main_scaffold.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/home_settings_page.dart';
import 'package:hetaumakeiba_v2/screens/jyusyoichiran_page.dart';
import 'package:hetaumakeiba_v2/screens/race_schedule_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/tablet/tablet_saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/tablet/tablet_schedule_wrapper_page.dart';
import 'package:hetaumakeiba_v2/screens/track_condition_page.dart';
import 'package:hetaumakeiba_v2/screens/user_settings_page.dart';
import 'package:hetaumakeiba_v2/services/local_auth_service.dart';
import 'package:hetaumakeiba_v2/widgets/track_condition_ticker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScaffold({super.key, required this.onLogout});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // [修正] 起動時のトップページをニュース(_pages[0])から馬場状態(_pages[1])へ変更 (v.2026.7.28+26072811)
  int _selectedIndex = 1;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();
  // [追加] タブレット版馬券タブの再読み込み用GlobalKey (v.2026.9.17+26091701)
  final GlobalKey<TabletSavedTicketsListPageState> _tabletSavedListKey =
  GlobalKey<TabletSavedTicketsListPageState>();
  final GlobalKey<RaceSchedulePageState> _raceScheduleKey = GlobalKey<RaceSchedulePageState>();

  final DbProvider _dbProvider = DbProvider();
  final UserRepository _userRepository = UserRepository();
  final TrackConditionRepository _trackConditionRepository = TrackConditionRepository();
  bool _isBusy = false;

  String _displayName = '';
  File? _profileImageFile;

  /// アプリ全体のデータ（DB・画像・設定）をZIP化し、専用パスワードで保護して共有する
  Future<void> _backupDatabase() async {
    if (!mounted) return;

    // 1. バックアップ専用パスワードの設定ダイアログ
    String? password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String input = '';
        bool obscureText = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('バックアップの作成'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('このバックアップファイルを復元する際に必要となる「専用パスワード」を設定してください。', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: obscureText,
                    onChanged: (val) => input = val,
                    decoration: InputDecoration(
                      labelText: 'バックアップ用パスワード',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (input.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('パスワードを入力してください')));
                      return;
                    }
                    Navigator.pop(context, input);
                  },
                  child: const Text('作成'),
                ),
              ],
            );
          },
        );
      },
    );

    if (password == null) return; // キャンセル時

    setState(() {
      _isBusy = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップを作成中...\n(画像データを含むため少し時間がかかります)')),
      );

      final archive = Archive();

      // 2. SharedPreferencesのデータとパスワードのハッシュ値をメタデータとして保存
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        prefsMap[key] = prefs.get(key);
      }
      final metaMap = {
        'password_hash': LocalAuthService().hashPassword(password),
        'shared_preferences': prefsMap,
      };
      final metaData = utf8.encode(jsonEncode(metaMap));
      archive.addFile(ArchiveFile('backup_meta.json', metaData.length, metaData));

      // 3. データベースファイルの追加
      await _dbProvider.closeDb(); // 一旦閉じて安全にコピー
      final databasePath = await getDatabasesPath();
      final dbPath = p.join(databasePath, DbConstants.dbName);
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        final dbBytes = await dbFile.readAsBytes();
        archive.addFile(ArchiveFile(DbConstants.dbName, dbBytes.length, dbBytes));
      }

      // 4. 画像ファイル群（勝負服・プロフィール画像）の追加
      final appDir = await getApplicationDocumentsDirectory();

      final ownerImagesDir = Directory(p.join(appDir.path, 'owner_images'));
      if (ownerImagesDir.existsSync()) {
        final files = ownerImagesDir.listSync(recursive: true).whereType<File>();
        for (final file in files) {
          final relPath = p.relative(file.path, from: appDir.path);
          final bytes = await file.readAsBytes();
          // Windowsのバックスラッシュをスラッシュに変換（ZIPの標準仕様）
          archive.addFile(ArchiveFile(relPath.replaceAll('\\', '/'), bytes.length, bytes));
        }
      }

      // プロフィール画像の追加
      final appDirFiles = appDir.listSync().whereType<File>();
      for (final file in appDirFiles) {
        final basename = p.basename(file.path);
        if (basename.startsWith('profile_picture_')) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(basename, bytes.length, bytes));
        }
      }

      // 5. ZIP化して共有
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) throw Exception('ZIPの作成に失敗しました');

      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd_HH-mm');
      final formattedDate = formatter.format(now);
      final fileName = 'hetaumakeiba_backup_$formattedDate.zip';

      final tempDir = await getTemporaryDirectory();
      final zipFile = File(p.join(tempDir.path, fileName));
      await zipFile.writeAsBytes(zipData);

      final xFile = XFile(zipFile.path, name: fileName);
      await Share.shareXFiles([xFile], text: 'アプリデータのバックアップ');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('バックアップ中にエラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  /// メイン画面でのインポートは安全のためログアウトを促す
  Future<void> _importDatabase() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データのインポートについて'),
        content: const Text('データの不整合や他ユーザーのデータを上書きしてしまう事故を防ぐため、\nバックアップからの復元はログアウト後の「ログイン画面」から行ってください。\n\nログアウトしてログイン画面に戻りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }

// （以降のコードは全く変更なしのため省略）

  Future<void> _loadUserInfoForDrawer() async {
    final localUserId = UserSession().localUserId;
    if (localUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final user = await _userRepository.getUserByUuid(localUserId);
    final profileImagePath = prefs.getString('profile_picture_path_$localUserId');

    File? newImageFile;
    if (profileImagePath != null) {
      newImageFile = File(profileImagePath);
      FileImage(newImageFile).evict();
    }

    if (mounted) {
      setState(() {
        _displayName =
            prefs.getString('display_name_$localUserId') ?? user?.username ?? '';
        _profileImageFile = newImageFile;
      });
    }
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserInfoForDrawer();

    _pages = <Widget>[
      const HomePage(),
      const TrackConditionPage(),
      RaceSchedulePage(key: _raceScheduleKey),
      const JyusyoIchiranPage(),
      SavedTicketsListPage(key: _savedListKey),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      _savedListKey.currentState?.reloadData();
      // [追加] タブレット版馬券タブ表示時の再読み込み (v.2026.9.17+26091701)
      _tabletSavedListKey.currentState?.reloadData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    // [修正] 重賞一覧ページを追加し、_selectedIndexとtabletPagesが1:1で対応するよう修正 (v.13.40.6)
    final List<Widget> tabletPages = [
      _pages[0],
      const TrackConditionPage(),
      const TabletScheduleWrapperPage(),
      const JyusyoIchiranPage(),
      // [修正] タブ表示時の再読み込みのためGlobalKeyを付与 (v.2026.9.17+26091701)
      TabletSavedTicketsListPage(key: _tabletSavedListKey),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Theme.of(context).primaryColor,
                    Colors.green.shade400,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: _profileImageFile != null ? FileImage(_profileImageFile!) : null,
                    child: _profileImageFile == null
                        ? Text(
                      _displayName.isNotEmpty ? _displayName[0] : '',
                      style: const TextStyle(fontSize: 30.0),
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('ユーザー設定'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => UserSettingsPage(onLogout: widget.onLogout),
                  ),
                );
                _loadUserInfoForDrawer();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('ニュースフィード設定'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HomeSettingsPage(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              enabled: !_isBusy,
              leading: const Icon(Icons.backup_outlined, color: Colors.green),
              title: const Text('データのバックアップ'),
              subtitle: const Text('現在のデータをファイルに書き出します。'),
              onTap: () {
                Navigator.of(context).pop();
                _backupDatabase();
              },
            ),
            ListTile(
              enabled: !_isBusy,
              leading: const Icon(Icons.import_export_outlined, color: Colors.orange),
              title: const Text('データのインポート'),
              subtitle: const Text('ファイルからデータを復元します。'),
              onTap: () {
                Navigator.of(context).pop();
                _importDatabase();
              },
            ),
            const Divider(),
          ],
        ),
      ),
      body: SafeArea(
        child: isTablet
            ? Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.green[900],
              // [修正] メニュー項目をdestinationsへ統合したためleadingのIconButtonを削除 (v.13.40.6)
              selectedIndex: _selectedIndex + 1,

              // [修正] BottomNavigationBarと同じ「index 0はメニュー(Drawer)」方式に統一し、
              // 5項目すべてのタップを正しいページへ振り分けるよう修正 (v.13.40.6)
              onDestinationSelected: (int index) {
                if (index == 0) {
                  _scaffoldKey.currentState?.openDrawer();
                  return;
                }
                _onItemTapped(index - 1);
              },

              labelType: NavigationRailLabelType.none,
              useIndicator: false,
              minWidth: 56.0,
              selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
              unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 24),
              selectedLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
              unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              // [修正] BottomNavigationBarItemと同じ5項目（メニュー/ニュース/開催一覧/重賞一覧/馬券履歴）に同期 (v.13.40.6)
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.menu), label: Text('メニュー')),
                NavigationRailDestination(icon: Icon(Icons.home), label: Text('ニュース')),
                NavigationRailDestination(icon: Icon(Icons.grass), label: Text('馬場')),
                NavigationRailDestination(icon: Icon(Icons.calendar_today), label: Text('開催一覧')),
                NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('重賞一覧')),
                NavigationRailDestination(icon: Icon(Icons.list_alt), label: Text('馬券履歴')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: tabletPages,
              ),
            ),
          ],
        )
            : IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: isTablet
          ? null
          : BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'メニュー'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ニュース'),
          BottomNavigationBarItem(icon: Icon(Icons.grass), label: '馬場'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '開催一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '重賞一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '馬券履歴'),
        ],
        currentIndex: _selectedIndex + 1,
        onTap: (int index) {
          if (index == 0) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            _onItemTapped(index - 1);
          }
        },
      ),
      // [削除] ニュースページの馬券取り込みのフローティングボタンを廃止（取り込みは馬券履歴の月バナーのボタンから） (v.2026.11.23+26112301)
    );
  }
}