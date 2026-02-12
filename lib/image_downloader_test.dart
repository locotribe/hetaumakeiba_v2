// lib/image_downloader_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ImageDownloaderTestApp());
}

class ImageDownloaderTestApp extends StatelessWidget {
  const ImageDownloaderTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Downloader Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<String> _logs = [];
  String? _savedImagePath;
  bool _isDownloading = false;

  // テスト用画像URL (サンデーレーシングの勝負服)
  final String _testImageUrl = 'https://cdn.netkeiba.com/img/db/colours/226800.gif';
  // ユーザーエージェント (スクレイピング時と同じもの)
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
  };

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().split('.').first}: $message');
    });
    print(message); // コンソールにも出力
  }

  Future<void> _runTest() async {
    setState(() {
      _logs.clear();
      _savedImagePath = null;
      _isDownloading = true;
    });

    try {
      _addLog('テスト開始');

      // 1. ドキュメントディレクトリの取得
      final directory = await getApplicationDocumentsDirectory();
      _addLog('ドキュメントパス取得成功:\n${directory.path}');

      // 2. owner_images ディレクトリの作成
      final saveDir = Directory('${directory.path}/owner_images');
      if (!await saveDir.exists()) {
        _addLog('ディレクトリが存在しないため作成します...');
        await saveDir.create(recursive: true);
        _addLog('ディレクトリ作成完了: owner_images');
      } else {
        _addLog('ディレクトリは既に存在します: owner_images');
      }

      // 3. 画像のダウンロード
      _addLog('画像ダウンロード開始: $_testImageUrl');
      final response = await http.get(Uri.parse(_testImageUrl), headers: _headers);

      if (response.statusCode == 200) {
        _addLog('ダウンロード成功 (サイズ: ${response.bodyBytes.length} bytes)');

        // 4. ファイルへの保存
        final filePath = '${saveDir.path}/test_owner_226800.gif';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        _addLog('ファイル保存成功:\n$filePath');

        // ファイルが存在するか再確認
        if (await file.exists()) {
          _addLog('ファイル存在確認OK');
          setState(() {
            _savedImagePath = filePath;
          });
        } else {
          _addLog('【エラー】保存したはずのファイルが見つかりません');
        }

      } else {
        _addLog('【エラー】ダウンロード失敗 ステータスコード: ${response.statusCode}');
      }

    } catch (e) {
      _addLog('【例外発生】: $e');
    } finally {
      setState(() {
        _isDownloading = false;
      });
      _addLog('テスト終了');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('画像保存テスト')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isDownloading ? null : _runTest,
              child: Text(_isDownloading ? '実行中...' : 'テスト実行 (ダウンロード＆保存)'),
            ),
            const SizedBox(height: 20),
            const Text('【実行ログ】', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[100],
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Text(
                    _logs[index],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('【保存された画像の表示テスト】', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: _savedImagePath != null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.file(
                      File(_savedImagePath!),
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text('表示エラー: $error', style: const TextStyle(color: Colors.red));
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('表示成功！', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                )
                    : const Text('画像はまだありません'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}