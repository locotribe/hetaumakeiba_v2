// lib/screens/settings_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/services/analytics_service.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isBusy = false;

  /// ★★★ 新しく追加したメソッド ★★★
  /// 分析データを再構築する
  Future<void> _rebuildAnalyticsData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('分析データを再構築'),
        content: const Text('全ての購入履歴を元に、集計データを最初から作り直します。データ量によっては時間がかかる場合があります。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('実行', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isBusy = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text("データを再構築中..."),
          ],
        ),
      ),
    );

    try {
      // 1. 既存の集計データをクリア
      final db = await _dbHelper.database;
      await db.delete('analytics_aggregates');

      // 2. 全ての購入履歴からユニークなレースIDを抽出
      final allQrData = await _dbHelper.getAllQrData();
      final Set<String> raceIds = {};
      for (final qrData in allQrData) {
        try {
          final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
          final url = generateNetkeibaUrl(
            year: parsedTicket['年'].toString(),
            racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
            round: parsedTicket['回'].toString(),
            day: parsedTicket['日'].toString(),
            race: parsedTicket['レース'].toString(),
          );
          final raceId = ScraperService.getRaceIdFromUrl(url);
          if (raceId != null) {
            raceIds.add(raceId);
          }
        } catch (e) {
          print('Skipping a ticket due to parsing error during migration: $e');
        }
      }

      // 3. 各レースIDに対して集計処理を再実行
      for (final raceId in raceIds) {
        await AnalyticsService().updateAggregatesOnResultConfirmed(raceId);
      }

      if (mounted) {
        Navigator.of(context).pop(); // ローディングダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分析データの再構築が完了しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ローディングダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
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

  /// 全データを削除する
  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('本当にすべての保存データを削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await _dbHelper.deleteAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべてのデータが削除されました。')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除中にエラーが発生しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

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

      final dbPath = await _dbHelper.getDbPath();
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
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ファイル選択がキャンセルされました。')),
          );
        }
        // キャンセルされた場合も busy 状態を解除
        setState(() { _isBusy = false; });
        return;
      }

      if (!mounted) return;

      // ローディングダイアログを表示
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

      await _dbHelper.closeDb();

      final destinationPath = await _dbHelper.getDbPath();
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);

      if (!mounted) return;
      Navigator.of(context).pop(); // ローディングダイアログを閉じる

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
        // エラー発生時にローディングダイアログが開いている可能性があれば閉じる
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ListTile(
                enabled: !_isBusy,
                leading: const Icon(Icons.build, color: Colors.blueAccent),
                title: const Text('分析データを再構築'),
                subtitle: const Text('既存の全購入履歴から分析データを再計算します。'),
                onTap: _rebuildAnalyticsData,
              ),
              const Divider(),
              ListTile(
                enabled: !_isBusy,
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('全データ削除'),
                subtitle: const Text('保存されている全ての購入履歴とレース結果を削除します。'),
                onTap: _deleteAllData,
              ),
              const Divider(),
              ListTile(
                enabled: !_isBusy,
                leading: const Icon(Icons.backup_outlined, color: Colors.green),
                title: const Text('データのバックアップ'),
                subtitle: const Text('現在のデータをファイルに書き出します。'),
                onTap: _backupDatabase,
              ),
              ListTile(
                enabled: !_isBusy,
                leading: const Icon(Icons.import_export_outlined, color: Colors.orange),
                title: const Text('データのインポート'),
                subtitle: const Text('ファイルからデータを復元します。'),
                onTap: _importDatabase,
              ),
              // 将来的に他の設定項目をここに追加できます
            ],
          ),
        ],
      ),
    );
  }
}