// main_scaffold.dart
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/analytics_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/jyusyoichiran_page.dart';
import 'package:hetaumakeiba_v2/screens/home_settings_page.dart';
import 'dart:io';
import 'package:hetaumakeiba_v2/screens/user_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hetaumakeiba_v2/screens/race_schedule_page.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_settings_page.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_analysis_page.dart';
import 'package:hetaumakeiba_v2/widgets/track_condition_ticker.dart';


class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScaffold({super.key, required this.onLogout});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();
  final GlobalKey<AnalyticsPageState> _analyticsPageKey = GlobalKey<AnalyticsPageState>();
  final GlobalKey<RaceSchedulePageState> _raceScheduleKey = GlobalKey<RaceSchedulePageState>();

  final DbProvider _dbProvider = DbProvider();
  final UserRepository _userRepository = UserRepository();
  final TrackConditionRepository _trackConditionRepository = TrackConditionRepository();
  bool _isBusy = false;

  String _displayName = '';
  File? _profileImageFile;

  /// データベースをバックアップファイルとして共有する
  Future<void> _backupDatabase() async {
    if (!mounted) return;

    setState(() {
      _isBusy = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップを準備中...')),
      );

      final databasePath = await getDatabasesPath();
      final dbPath = p.join(databasePath, DbConstants.dbName);
      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd_HH-mm');
      final formattedDate = formatter.format(now);
      final fileName = 'hetaumakeiba_backup_$formattedDate.db';

      final xFile = XFile(dbPath, name: fileName);

      await Share.shareXFiles([xFile], text: 'データベースのバックアップ');

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

  /// ファイルからデータベースをインポート（復元）する
  Future<void> _importDatabase() async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データをインポート'),
        content: const Text(
            'ファイルからデータを復元します。\n現在のデータは全て上書きされ、この操作は取り消せません。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('インポート実行', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ファイル選択がキャンセルされました。')),
          );
        }
        setState(() { _isBusy = false; });
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text("インポート処理中..."),
            ],
          ),
        ),
      );

      final sourcePath = result.files.single.path!;

      await _dbProvider.closeDb();

      final databasePath = await getDatabasesPath();
      final destinationPath = p.join(databasePath, DbConstants.dbName);
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);

      if (!mounted) return;
      Navigator.of(context).pop();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('インポート完了'),
          content: const Text('データのインポートが完了しました。変更を正しく反映させるには、アプリを一度完全に終了してから、再度起動してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (mounted) {
        if(Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポート中にエラーが発生しました: $e')),
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

  Future<void> _loadUserInfoForDrawer() async {
    if (localUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final user = await _userRepository.getUserByUuid(localUserId!);
    final profileImagePath = prefs.getString('profile_picture_path_${localUserId!}');

    File? newImageFile;
    if (profileImagePath != null) {
      newImageFile = File(profileImagePath);
      FileImage(newImageFile).evict();
    }

    if (mounted) {
      setState(() {
        _displayName =
            prefs.getString('display_name_${localUserId!}') ?? user?.username ?? '';
        _profileImageFile = newImageFile;
      });
    }
  }

  Future<void> _importTrackConditionsCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVデータを読み込んでいます...')),
        );

        String csvString = "";

        if (result.files.single.bytes != null) {
          csvString = utf8.decode(result.files.single.bytes!);
        } else if (result.files.single.path != null) {
          File file = File(result.files.single.path!);
          csvString = await file.readAsString();
        }

        if (csvString.isEmpty) throw Exception("ファイルの内容を読み込めませんでした");

        final resultCounts = await _trackConditionRepository.importTrackConditionsFromCsv(csvString);
        int inserted = resultCounts['inserted'] ?? 0;
        int duplicates = resultCounts['duplicates'] ?? 0;

        if (!mounted) return;

        String message = '✅ インポート完了: $inserted件追加しました';
        if (duplicates > 0) {
          message += '（既に登録済みの $duplicates件 はスキップしました）';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        trackConditionTickerKey.currentState?.loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ インポート失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  late final List<Widget> _pages;
  static const List<String> _pageTitles = ['ニュース', '開催一覧', '重賞一覧', '購入履歴', '集計'];

  @override
  void initState() {
    super.initState();
    _loadUserInfoForDrawer();

    _pages = <Widget>[
      const HomePage(),
      RaceSchedulePage(key: _raceScheduleKey),
      const JyusyoIchiranPage(),
      SavedTicketsListPage(key: _savedListKey),
      AnalyticsPage(key: _analyticsPageKey),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      _savedListKey.currentState?.reloadData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
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
                    color: Colors.black.withOpacity(0.3), // 影の色（透過度調整可）
                    offset: const Offset(0, 4),           // 影の位置（X, Y）
                    blurRadius: 8,                        // 影のぼかし具合
                    spreadRadius: 2,                      // 影の広がり
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 8), // 上部の余白(ステータスバー分)を追加
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
              leading: const Icon(Icons.tune),
              title: const Text('AI予測チューニング'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AiPredictionSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.insights),
              title: const Text('AI予測 傾向分析'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AiPredictionAnalysisPage(),
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

            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('馬場データ(CSV)をインポート'),
              onTap: () {
                Navigator.pop(context); // メニューを閉じる
                _importTrackConditionsCsv(); // インポート処理を実行
              },
            ),

            const Divider(),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ニュース'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '開催一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '重賞一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '馬券履歴'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: '集計'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: AnimatedSlide(
        duration: Duration(milliseconds: _selectedIndex == 0 ? 250 : 500),
        curve: Curves.easeOut,
        offset: _selectedIndex == 0 ? Offset.zero : const Offset(2, 0),
        child: AnimatedOpacity(
          opacity: _selectedIndex == 0 ? 1.0 : 0.0,
          duration: Duration(milliseconds: _selectedIndex == 0 ? 250 : 500),
          curve: Curves.easeInOut,
          child: ExpandableFab(
            distance: 92.0,
            children: [
              ActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QRScannerPage(savedListKey: _savedListKey),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
              ),
              ActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GalleryQrScannerPage(savedListKey: _savedListKey),
                    ),
                  );
                },
                icon: const Icon(Icons.image),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// Expandable FAB 全体
@immutable
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    this.initialOpen,
    required this.distance,
    required this.children,
  });

  final bool? initialOpen;
  final double distance;
  final List<Widget> children;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen ?? false;
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          _buildTapToCloseFab(),
          ..._buildExpandingActionButtons(),
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  Widget _buildTapToCloseFab() {
    return SizedBox(
      width: 70,
      height: 70,
      child: Center(
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    final step = 90.0 / (count - 1);
    for (var i = 0, angleInDegrees = 0.0;
    i < count;
    i++, angleInDegrees += step) {
      children.add(
        _ExpandingActionButton(
          directionInDegrees: angleInDegrees,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: widget.children[i],
        ),
      );
    }
    return children;
  }
  Widget _buildTapToOpenFab() {
    return IgnorePointer(
      ignoring: _open,
      child: AnimatedContainer(
        transformAlignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          _open ? 0.7 : 1.0,
          _open ? 0.7 : 1.0,
          1.0,
        ),
        duration: const Duration(milliseconds: 250),
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        child: AnimatedOpacity(
          opacity: _open ? 0.0 : 1.0,
          curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
          duration: const Duration(milliseconds: 250),
          child: Material(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100.0),
              highlightColor: Colors.transparent,               // ← 押しっぱなしの影を消す
              radius: 0.0,                                     // ← 波紋の広がり半径を拡大
              onTap: _toggle,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0.0),
                child: Image.asset(
                  'assets/images/icon_baken.png',
                  width: 80,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (math.pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          right: 4.0 + offset.dx,
          bottom: 4.0 + offset.dy,
          child: Transform.rotate(
            angle: (1.0 - progress.value) * math.pi / 2,
            child: child!,
          ),
        );
      },
      child: FadeTransition(opacity: progress, child: child),
    );
  }
}

@immutable
class ActionButton extends StatelessWidget {
  const ActionButton({super.key, this.onPressed, required this.icon});

  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: Colors.green,
      elevation: 0.0,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        color: Colors.white,
      ),
    );
  }
}