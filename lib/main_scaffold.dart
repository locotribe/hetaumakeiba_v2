// main_scaffold.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/logic/memo_import_logic.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_memo_model.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/home_settings_page.dart';
import 'package:hetaumakeiba_v2/screens/jyusyoichiran_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/race_schedule_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/tablet/tablet_saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/tablet/tablet_schedule_wrapper_page.dart';
import 'package:hetaumakeiba_v2/screens/user_settings_page.dart';
import 'package:hetaumakeiba_v2/widgets/track_condition_ticker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
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
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();
  final GlobalKey<RaceSchedulePageState> _raceScheduleKey = GlobalKey<RaceSchedulePageState>();

  final DbProvider _dbProvider = DbProvider();
  final UserRepository _userRepository = UserRepository();
  final TrackConditionRepository _trackConditionRepository = TrackConditionRepository();
  bool _isBusy = false;

  final RaceRepository _raceRepo = RaceRepository();
  final HorseRepository _horseRepo = HorseRepository();

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

  Future<void> _importGlobalMemosFromCsv() async {
    final userId = localUserId; // _MainScaffoldState内で取得可能なユーザーID
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isBusy = false;
        });
        return; // キャンセル時
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final csvString = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) throw Exception('データがありません');

      // ヘッダーの検証
      final header = rows.first.map((e) => e.toString().trim()).toList();
      final expectedHeaderPrefix = 'raceId,horseId,horseNumber,horseName,reviewMemo,predictionMemo';
      final currentHeaderPrefix = header.take(6).join(',');

      if (currentHeaderPrefix != expectedHeaderPrefix) {
        throw Exception('CSVヘッダーが正しくありません。正しいフォーマットのファイルを選択してください。');
      }

      final hasRaceMemoCol = header.length > 6 && header[6] == 'raceMemo';

      // DBアクセスの負荷を下げるためのキャッシュ用Map
      final Map<String, Map<String, HorseMemo>> cachedHorseMemos = {};
      final Map<String, RaceMemo?> cachedRaceMemos = {};

      final Map<String, RaceMemo> raceMemosToUpdate = {}; // raceIdごとの最新状態を保持
      final List<HorseMemo> memosToUpdate = [];

      int updatedHorseCount = 0;
      int updatedRaceMemoCount = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 2) continue; // 空行などをスキップ

        final csvRaceId = row[0].toString();
        final horseId = row[1].toString();
        final horseName = row.length > 3 ? row[3].toString() : '馬番不明';
        final csvReview = row.length > 4 ? row[4].toString() : '';
        final csvPrediction = row.length > 5 ? row[5].toString() : '';

        // 初めて登場したレースIDの既存データをDBから一括取得してキャッシュする
        if (!cachedHorseMemos.containsKey(csvRaceId)) {
          final memos = await _horseRepo.getMemosForRace(userId, csvRaceId);
          cachedHorseMemos[csvRaceId] = {for (var m in memos) m.horseId: m};
          cachedRaceMemos[csvRaceId] = await _raceRepo.getRaceMemo(userId, csvRaceId);
        }

        final existingHorse = cachedHorseMemos[csvRaceId]![horseId];
        String finalReview = existingHorse?.reviewMemo ?? '';
        String finalPrediction = existingHorse?.predictionMemo ?? '';
        bool isHorseUpdated = false;

        // 回顧メモの競合判定
        final reviewMerge = MemoImportLogic.determineMergeAction(existingHorse?.reviewMemo, csvReview);
        if (reviewMerge.action == MemoMergeAction.overwrite) {
          finalReview = reviewMerge.resultText;
          isHorseUpdated = true;
        } else if (reviewMerge.action == MemoMergeAction.conflict) {
          final resolved = await _resolveConflictDialog('$horseNameの回顧メモ\n(レース: $csvRaceId)', reviewMerge);
          if (resolved != null && resolved != finalReview) {
            finalReview = resolved;
            isHorseUpdated = true;
          }
        }

        // 予想メモの競合判定
        final predictionMerge = MemoImportLogic.determineMergeAction(existingHorse?.predictionMemo, csvPrediction);
        if (predictionMerge.action == MemoMergeAction.overwrite) {
          finalPrediction = predictionMerge.resultText;
          isHorseUpdated = true;
        } else if (predictionMerge.action == MemoMergeAction.conflict) {
          final resolved = await _resolveConflictDialog('$horseNameの予想メモ\n(レース: $csvRaceId)', predictionMerge);
          if (resolved != null && resolved != finalPrediction) {
            finalPrediction = resolved;
            isHorseUpdated = true;
          }
        }

        // 変更があった場合、または新規作成の場合のみ更新リストへ追加
        if (isHorseUpdated || existingHorse == null) {
          // 新規の場合でかつCSVのメモがどちらも空なら追加しない
          if (existingHorse != null || finalReview.isNotEmpty || finalPrediction.isNotEmpty) {
            memosToUpdate.add(HorseMemo(
              id: existingHorse?.id,
              userId: userId,
              raceId: csvRaceId,
              horseId: horseId,
              reviewMemo: finalReview,
              predictionMemo: finalPrediction,
              timestamp: DateTime.now(),
              odds: existingHorse?.odds,
              popularity: existingHorse?.popularity,
            ));
            updatedHorseCount++;
          }
        }

        // レース総評の処理
        if (hasRaceMemoCol && row.length > 6) {
          final csvRaceMemo = row[6].toString().trim();
          if (csvRaceMemo.isNotEmpty) {
            final existingRaceMemo = cachedRaceMemos[csvRaceId];

            // 同一レースの複数行で総評が上書きされないように、ループ内の更新状況(raceMemosToUpdate)を優先的に確認する
            String currentRaceMemoText = raceMemosToUpdate.containsKey(csvRaceId)
                ? raceMemosToUpdate[csvRaceId]!.memo
                : (existingRaceMemo?.memo ?? '');

            final raceMerge = MemoImportLogic.determineMergeAction(currentRaceMemoText, csvRaceMemo);
            if (raceMerge.action == MemoMergeAction.overwrite) {
              raceMemosToUpdate[csvRaceId] = RaceMemo(
                id: existingRaceMemo?.id,
                userId: userId,
                raceId: csvRaceId,
                memo: raceMerge.resultText,
                timestamp: DateTime.now(),
              );
            } else if (raceMerge.action == MemoMergeAction.conflict) {
              final resolved = await _resolveConflictDialog('レース総評\n(レース: $csvRaceId)', raceMerge);
              if (resolved != null && resolved != currentRaceMemoText) {
                raceMemosToUpdate[csvRaceId] = RaceMemo(
                  id: existingRaceMemo?.id,
                  userId: userId,
                  raceId: csvRaceId,
                  memo: resolved,
                  timestamp: DateTime.now(),
                );
              }
            }
          }
        }
      }

      // 3. 馬ごとのメモを一括保存
      if (memosToUpdate.isNotEmpty) {
        await _horseRepo.insertOrUpdateMultipleMemos(memosToUpdate);
      }

      // 4. レース総評を個別に保存
      for (final rm in raceMemosToUpdate.values) {
        await _raceRepo.insertOrUpdateRaceMemo(rm);
        updatedRaceMemoCount++;
      }

      // 5. 成功のUIフィードバック
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$updatedHorseCount件の馬メモと$updatedRaceMemoCount件のレース総評をインポートしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 失敗時のUIフィードバック
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('インポートエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 処理終了後にBusyフラグを下ろす
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  /// 競合発生時にユーザーに解決アクションを選択させるダイアログ
  Future<String?> _resolveConflictDialog(String title, MemoMergeResult conflict) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('競合の解決: $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('【現在のデータ】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(conflict.existingText.isEmpty ? '(なし)' : conflict.existingText),
              ),
              const Text('【インポートデータ】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(conflict.newText.isEmpty ? '(なし)' : conflict.newText),
              ),
              const Text('このデータをどのように処理しますか？', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, conflict.existingText),
            child: const Text('スキップ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, conflict.newText),
            child: const Text('CSVで上書き', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, '${conflict.existingText}\n\n${conflict.newText}'),
            child: const Text('追記する'),
          ),
        ],
      ),
    );
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserInfoForDrawer();

    _pages = <Widget>[
      const HomePage(),
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
    if (index == 3) {
      _savedListKey.currentState?.reloadData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    final int tabletIndex = _selectedIndex == 0 ? 0 : (_selectedIndex <= 2) ? 1 : 2;
    final List<Widget> tabletPages = [
      _pages[0],
      const TabletScheduleWrapperPage(),
      const TabletSavedTicketsListPage(),
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
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('馬場データ(CSV)をインポート'),
              onTap: () {
                Navigator.pop(context);
                _importTrackConditionsCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('メモ・総評の一括インポート(CSV)'),
              subtitle: const Text(
                '複数レースのメモをまとめて取り込みます。',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _importGlobalMemosFromCsv();
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
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              selectedIndex: tabletIndex,

              onDestinationSelected: (int index) {
                int mappedIndex = index;
                if (index == 1) mappedIndex = 1;
                else if (index == 2) mappedIndex = 3;

                _onItemTapped(mappedIndex);
              },

              labelType: NavigationRailLabelType.all,
              useIndicator: false,
              minWidth: 72.0,
              selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
              unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 24),
              selectedLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
              unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home), label: Text('ニュース')),
                NavigationRailDestination(icon: Icon(Icons.calendar_today), label: Text('開催一覧')),
                NavigationRailDestination(icon: Icon(Icons.list_alt), label: Text('馬券履歴')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: tabletIndex,
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