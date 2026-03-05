// lib/test_scraper_app.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/services/horse_profile_scraper_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: '緊急DB更新ツール',
    home: EmergencyUpdateScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class EmergencyUpdateScreen extends StatefulWidget {
  const EmergencyUpdateScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyUpdateScreen> createState() => _EmergencyUpdateScreenState();
}

class _EmergencyUpdateScreenState extends State<EmergencyUpdateScreen> {
  bool _isUpdating = false;
  int _totalCount = 0;
  int _currentIndex = 0;
  String _currentHorseId = '';
  final List<String> _logs = [];

  // ログを画面に追加する関数
  void _addLog(String message) {
    setState(() {
      // 最新のログが一番上に来るように追加
      _logs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)} $message');
    });
    print('EMERGENCY_UPDATE: $message');
  }

  // 緊急更新ロジック本体
  Future<void> _startEmergencyUpdate() async {
    setState(() {
      _isUpdating = true;
      _logs.clear();
      _totalCount = 0;
      _currentIndex = 0;
    });

    _addLog('🚨 緊急アップデート（血統データ再取得）を開始します...');

    try {
      // 1. データベースから既存の馬IDをすべて取得する
      final db = await DbProvider().database;
      final maps = await db.query(DbConstants.tableHorseProfiles, columns: ['horseId']);
      final horseIds = maps.map((e) => e['horseId'] as String).toList();

      setState(() {
        _totalCount = horseIds.length;
      });

      _addLog('対象の競走馬データ: $_totalCount 件');

      if (horseIds.isEmpty) {
        _addLog('更新対象のデータがありませんでした。');
        setState(() => _isUpdating = false);
        return;
      }

      // 2. 1件ずつプロフィールを再取得して保存（ディレイを入れる）
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < horseIds.length; i++) {
        if (!mounted) return; // 画面が閉じられたら安全に中断

        final horseId = horseIds[i];
        setState(() {
          _currentIndex = i + 1;
          _currentHorseId = horseId;
        });

        _addLog('[$_currentIndex/$_totalCount] ID: $horseId のデータを取得中...');

        try {
          // プロフィールのスクレイピングとDB保存を実行
          final profile = await HorseProfileScraperService.scrapeAndSaveProfile(horseId);
          if (profile != null) {
            successCount++;
            _addLog('✅ 成功: ${profile.horseName}');
          } else {
            errorCount++;
            _addLog('⚠️ 失敗: ID: $horseId のプロフィールが取得できませんでした');
          }
        } catch (e) {
          errorCount++;
          _addLog('❌ エラー: ID: $horseId - $e');
        }

        // ★超重要：netkeibaのサーバー負荷とIP BANを防ぐため、2.5秒待機
        await Future.delayed(const Duration(milliseconds: 2500));
      }

      _addLog('🏁 すべての更新が完了しました！ (成功: $successCount, 失敗: $errorCount)');

    } catch (e) {
      _addLog('❌ 致命的なエラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐴 緊急プロフィール一括更新ツール'),
        backgroundColor: Colors.red[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 注意書き
            const Card(
              color: Colors.amberAccent,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  '【注意】\nDB内の全競走馬データを再取得します。\n1件につき約2.5秒かかります。\n途中でアプリを閉じないでください。',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 進捗バー
            if (_totalCount > 0) ...[
              Text(
                '進捗: $_currentIndex / $_totalCount 完了',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _currentIndex / _totalCount,
                minHeight: 12,
                backgroundColor: Colors.grey[300],
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              Text(
                '現在処理中: ID $_currentHorseId',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],

            // 実行ボタン
            ElevatedButton.icon(
              onPressed: _isUpdating ? null : _startEmergencyUpdate,
              icon: _isUpdating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.sync_problem),
              label: Text(_isUpdating ? '更新処理中...' : '一括更新を開始する'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // ログ表示エリア
            const Text('実行ログ:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}