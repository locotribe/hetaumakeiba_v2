// lib/test_cloud_sync_app.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/services/cloud_sync_service.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:file_picker/file_picker.dart'; // ← 上部に追加
import 'dart:convert';                         // ← 上部に追加
import 'dart:io';                              // ← 上部に追加

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'Cloud Sync Test App',
    home: CloudSyncTestPage(),
    debugShowCheckedModeBanner: false,
  ));
}

class CloudSyncTestPage extends StatefulWidget {
  const CloudSyncTestPage({super.key});

  @override
  State<CloudSyncTestPage> createState() => _CloudSyncTestPageState();
}

class _CloudSyncTestPageState extends State<CloudSyncTestPage> {
  final CloudSyncService _cloudSyncService = CloudSyncService();
  final TrackConditionRepository _repository = TrackConditionRepository();

  int _localVersion = -1;
  String _lastScrapedTime = '未設定';
  bool _hasTargetData = false;
  String _logMessage = '待機中...';
  bool _isProcessing = false;

  // クラウド側で指定されている最新の日付（version.jsonの中身に合わせてください）
  final String _targetDate = "2026-03-15";

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  /// 現在のローカル状態を読み込む
  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt('track_condition_csv_version') ?? 0;
    final lastScraped = prefs.getString('last_track_condition_scrape_time') ?? '未設定';

    // DBの初期化を確実に行う
    await DbProvider().database;
    final hasData = await _repository.hasDataForDate(_targetDate);

    setState(() {
      _localVersion = version;
      _lastScrapedTime = lastScraped;
      _hasTargetData = hasData;
    });
  }

  void _addLog(String msg) {
    setState(() {
      _logMessage = msg;
    });
    print('[TEST] $msg');
  }

  /// 同期チェックを実行
  Future<void> _testCheckSync() async {
    setState(() => _isProcessing = true);
    _addLog('同期チェック (checkSyncRequired) を実行中...');
    try {
      final needsSync = await _cloudSyncService.checkSyncRequired();
      _addLog('同期チェック完了: needsSync = $needsSync\n'
          '(trueならクラウドボタン赤色、falseなら通常状態)');
    } catch (e) {
      _addLog('エラー: $e');
    } finally {
      await _loadStatus();
      setState(() => _isProcessing = false);
    }
  }

  /// 強制インポートを実行
  Future<void> _testImport() async {
    setState(() => _isProcessing = true);
    _addLog('クラウドからのインポート (importFromCloud) を実行中...');
    try {
      final success = await _cloudSyncService.importFromCloud();
      _addLog('インポート完了: success = $success');
    } catch (e) {
      _addLog('エラー: $e');
    } finally {
      await _loadStatus();
      setState(() => _isProcessing = false);
    }
  }

  /// バージョンだけを0にリセット（分岐A・Bのテスト用）
  Future<void> _resetVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('track_condition_csv_version', 0);
    _addLog('ローカルバージョンを 0 にリセットしました。');
    await _loadStatus();
  }

  /// 完全初期化（新規インストール状態のシミュレート用）
  Future<void> _fullReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('track_condition_csv_version');
    await prefs.remove('last_track_condition_scrape_time');

    // オプション: もしDBから特定の日付データを消したい場合はここでクエリを実行
    final db = await DbProvider().database;
    await db.delete('track_conditions', where: 'date = ?', whereArgs: [_targetDate]);

    _addLog('完全初期化しました。（DBの対象日付データも削除）\nこれで新規インストールと同じ状態になります。');
    await _loadStatus();
  }

  // クラス内にメソッドを貼り付け（UI連携部分を少しテストアプリ用に調整）
  Future<void> _importLocalCsv() async {
    setState(() => _isProcessing = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        _addLog('ローカルCSVの読み込みを開始...');
        String csvString = "";
        if (result.files.single.bytes != null) {
          csvString = utf8.decode(result.files.single.bytes!);
        } else if (result.files.single.path != null) {
          File file = File(result.files.single.path!);
          csvString = await file.readAsString();
        }

        final resultCounts = await _repository.importTrackConditionsFromCsv(csvString);
        int inserted = resultCounts['inserted'] ?? 0;
        int duplicates = resultCounts['duplicates'] ?? 0;

        _addLog('✅ ローカルインポート完了: $inserted件追加 (スキップ: $duplicates件)');
      } else {
        _addLog('ファイル選択がキャンセルされました。');
      }
    } catch (e) {
      _addLog('❌ ローカルインポート失敗: $e');
    } finally {
      await _loadStatus();
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('☁️ クラウド同期テストツール'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ステータス表示パネル
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('【現在のローカル状態】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    Text('ローカルバージョン: $_localVersion', style: const TextStyle(fontSize: 16)),
                    Text('最終スクレイプ日時: $_lastScrapedTime', style: const TextStyle(fontSize: 14)),
                    Text('DBに「$_targetDate」のデータがあるか: ${_hasTargetData ? "✅ あり" : "❌ なし"}',
                        style: TextStyle(fontSize: 16, color: _hasTargetData ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 操作ボタン群
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _testCheckSync,
              icon: const Icon(Icons.sync),
              label: const Text('1. 同期チェックを実行 (checkSyncRequired)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _testImport,
              icon: const Icon(Icons.cloud_download),
              label: const Text('2. 強制インポートを実行 (importFromCloud)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const Divider(height: 32),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _resetVersion,
              icon: const Icon(Icons.restore),
              label: const Text('【テスト準備】バージョンのみを 0 にリセット'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _fullReset,
              icon: const Icon(Icons.delete_forever),
              label: const Text('【テスト準備】完全初期化 (新規インストール状態)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            const Spacer(),

            const Divider(height: 32),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _importLocalCsv,
              icon: const Icon(Icons.file_upload),
              label: const Text('【手動テスト】ローカルのCSVファイルを選択してインポート'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            ),

            // ログ表示エリア
            const Text('実行ログ:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _logMessage,
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}