// lib/main_clear_db.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClearDbApp());
}

class ClearDbApp extends StatelessWidget {
  const ClearDbApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DBクリーニング',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const ClearDbHomePage(),
    );
  }
}

class ClearDbHomePage extends StatefulWidget {
  const ClearDbHomePage({Key? key}) : super(key: key);

  @override
  State<ClearDbHomePage> createState() => _ClearDbHomePageState();
}

class _ClearDbHomePageState extends State<ClearDbHomePage> {
  String _statusMessage = '待機中...';
  bool _isLoading = false;

  // 馬場状態テーブル（track_conditions）の全データを削除する関数
  Future<void> _clearTrackConditions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'track_conditions テーブルを削除中...';
    });

    try {
      final db = await DatabaseHelper().database;
      // テーブル内の全レコードを削除
      int deletedCount = await db.delete('track_conditions');

      setState(() {
        _statusMessage = '✅ 完了: $deletedCount 件のデータを削除しました。\\n（これでNNナンバリングがリセットされました）';
        _isLoading = false;
      });
      debugPrint('Deleted $deletedCount rows from track_conditions');
    } catch (e) {
      setState(() {
        _statusMessage = '❌ エラーが発生しました: $e';
        _isLoading = false;
      });
      debugPrint('Error clearing track_conditions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('馬場データ強制クリア'),
        backgroundColor: Colors.red[800],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                '馬場状態・含水率のデータを全て削除しますか？\\n(他のレース予想データなどは消えません)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _clearTrackConditions,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('全データを削除してリセット', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}