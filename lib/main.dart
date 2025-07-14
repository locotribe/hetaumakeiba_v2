// lib/main.dart の変更点

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // これは既存
import 'package:flutter/gestures.dart'; // これは既存
import 'package:flutter_localizations/flutter_localizations.dart'; // これは既存
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart'; // 追加
import 'package:hetaumakeiba_v2/models/qr_data_model.dart'; // 追加

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
  Map<String, dynamic>? parsedResult;
  List<QrData> _savedQrData = []; // 保存されたQRコードデータを保持するリスト
  final DatabaseHelper _dbHelper = DatabaseHelper(); // 追加

  @override
  void initState() {
    super.initState();
    _loadSavedQrData(); // アプリ起動時に保存データを読み込む
  }

  Future<void> _loadSavedQrData() async {
    final data = await _dbHelper.getAllQrData();
    setState(() {
      _savedQrData = data;
    });
  }

  void _openQRScanner() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );
    if (result != null) {
      // QRScannerPageから戻ってきたら、保存されたデータを再読み込み
      await _loadSavedQrData(); // 追加
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(parsedResult: result)),
      );
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('本当にすべての保存データを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteAllQrData();
      await _loadSavedQrData(); // 削除後、データを再読み込みしてUIを更新
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべてのデータが削除されました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("馬券QRリーダー")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _openQRScanner,
              child: const Text("QRコード読み取り"),
            ),
            const SizedBox(height: 16),
            ElevatedButton( // 全データ削除ボタンを追加
              onPressed: _deleteAllData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("全データを削除", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            const Text('保存されたQRコードデータ:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // 新しいヘッダー
            Expanded(
              child: _savedQrData.isEmpty
                  ? const Center(child: Text('保存されたデータはありません。'))
                  : ListView.builder(
                itemCount: _savedQrData.length,
                itemBuilder: (context, index) {
                  final qr = _savedQrData[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text('QRコード (${qr.id}): ${qr.qrCode.substring(0, 30)}...'), // QRコードの先頭を表示
                      subtitle: Text('保存日時: ${qr.timestamp.toLocal().toString().split('.')[0]}'),
                      // ここに詳細表示などのアクションを追加することも可能
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}