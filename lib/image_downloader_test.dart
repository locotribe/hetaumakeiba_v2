// lib/image_downloader_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:charset_converter/charset_converter.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const BatchScraperTestApp());
}

class BatchScraperTestApp extends StatelessWidget {
  const BatchScraperTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batch Scraper Test',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const BatchTestPage(),
    );
  }
}

class HorseTestResult {
  final String id;
  String status;
  String ownerName;
  String ownerId;
  String? imagePath;
  String? log;

  HorseTestResult({required this.id, this.status = '待機中', this.ownerName = '', this.ownerId = ''});
}

class BatchTestPage extends StatefulWidget {
  const BatchTestPage({super.key});

  @override
  State<BatchTestPage> createState() => _BatchTestPageState();
}

class _BatchTestPageState extends State<BatchTestPage> {
  // ログから抽出したIDリスト
  final List<HorseTestResult> _testHorses = [
    HorseTestResult(id: '2023105380'), // サトノアイボリー
    HorseTestResult(id: '2020103075'), // ログで失敗していたID
    HorseTestResult(id: '2021107098'),
    HorseTestResult(id: '2021104094'),
    HorseTestResult(id: '2022104772'),
    HorseTestResult(id: '2020100680'),
  ];

  bool _isRunning = false;

  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  // ログ出力用ヘルパー
  void _log(String message) {
    // ターミナル/Logcatで見つけやすいようにプレフィックスをつける
    print('[TEST_LOG] $message');
  }

  Future<void> _runBatchTest() async {
    _log('テストを開始します。対象件数: ${_testHorses.length}件');

    setState(() {
      _isRunning = true;
      for (var horse in _testHorses) {
        horse.status = '待機中';
        horse.ownerName = '';
        horse.ownerId = '';
        horse.imagePath = null;
        horse.log = '';
      }
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/owner_images');
      if (!await saveDir.exists()) {
        _log('保存ディレクトリを作成: ${saveDir.path}');
        await saveDir.create(recursive: true);
      } else {
        _log('保存ディレクトリ確認OK: ${saveDir.path}');
      }

      for (var i = 0; i < _testHorses.length; i++) {
        final horse = _testHorses[i];

        setState(() {
          horse.status = '処理中...';
        });

        _log('--------------------------------------------------');
        _log('ID: ${horse.id} の処理を開始 (${i + 1}/${_testHorses.length})');

        try {
          // アクセス間隔
          _log('待機中(1000ms)...');
          await Future.delayed(const Duration(milliseconds: 1000));

          final url = 'https://db.netkeiba.com/horse/${horse.id}/';
          _log('アクセス先: $url');

          final response = await http.get(Uri.parse(url), headers: _headers);
          _log('ステータスコード: ${response.statusCode}');

          if (response.statusCode != 200) {
            _log('【エラー】HTTPステータス異常');
            setState(() {
              horse.status = 'HTTPエラー ${response.statusCode}';
              horse.log = '接続失敗';
            });
            continue;
          }

          final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
          final document = html.parse(decodedBody);

          // ページタイトル確認（リダイレクトやエラーページでないか確認）
          final pageTitle = document.querySelector('title')?.text.trim() ?? 'No Title';
          _log('ページタイトル: $pageTitle');

          // --- 解析ロジック ---
          String ownerId = '';
          String ownerName = '';

          _log('リンク解析を開始...');
          final allLinks = document.querySelectorAll('a');
          int ownerLinkCount = 0;

          for (final link in allLinks) {
            final href = link.attributes['href'];
            if (href != null && href.contains('/owner/')) {
              ownerLinkCount++;
              // 正規表現でID抽出 (/owner/123456/ または /owner/123456)
              final match = RegExp(r'/owner/(\d+)').firstMatch(href);
              if (match != null) {
                ownerId = match.group(1)!;
                ownerName = link.text.trim();
                _log('★ 馬主リンク発見: ID=$ownerId, Name=$ownerName (href=$href)');
                break; // 最初に見つかったものを採用
              }
            }
          }
          _log('馬主関連リンク検出数: $ownerLinkCount');

          if (ownerId.isNotEmpty) {
            // 画像保存
            final imageUrl = 'https://cdn.netkeiba.com/img//db/colours/$ownerId.gif';
            final filePath = '${saveDir.path}/owner_$ownerId.gif';
            final file = File(filePath);

            _log('画像保存処理開始: URL=$imageUrl');

            // 既にファイルがあっても上書きテストするか、なければダウンロード
            if (!await file.exists()) {
              _log('画像をダウンロードします...');
              final imgRes = await http.get(Uri.parse(imageUrl), headers: _headers);
              _log('画像ダウンロードステータス: ${imgRes.statusCode}, サイズ: ${imgRes.bodyBytes.length} bytes');

              if (imgRes.statusCode == 200 && imgRes.bodyBytes.isNotEmpty) {
                await file.writeAsBytes(imgRes.bodyBytes);
                _log('ファイル書き込み完了: $filePath');
              } else {
                _log('【警告】画像のダウンロードに失敗、または空です');
              }
            } else {
              _log('画像ファイルは既に存在します: $filePath');
            }

            setState(() {
              horse.ownerId = ownerId;
              horse.ownerName = ownerName;
              horse.imagePath = filePath;
              horse.status = '成功';
              horse.log = 'ID取得: $ownerId';
            });
          } else {
            // 失敗時の詳細ログ
            _log('【解析失敗】馬主IDが見つかりませんでした。');
            setState(() {
              horse.status = '解析失敗';
              horse.log = 'オーナーリンクなし\nTitle: $pageTitle';
            });
          }

        } catch (e, stackTrace) {
          _log('【例外発生】: $e');
          print(stackTrace);
          setState(() {
            horse.status = 'エラー';
            horse.log = e.toString();
          });
        }
      }
    } catch (e) {
      _log('【致命的エラー】テスト全体の中断: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
      _log('すべてのテストが終了しました。');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('連続スクレイピングテスト(ログ強化版)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runBatchTest,
              icon: const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'テスト実行中...' : 'テスト開始 (コンソールを確認してください)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _testHorses.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final horse = _testHorses[index];
                Color statusColor = Colors.grey;
                if (horse.status == '成功') statusColor = Colors.green;
                if (horse.status.contains('失敗') || horse.status == 'エラー') statusColor = Colors.red;
                if (horse.status == '処理中...') statusColor = Colors.blue;

                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[200],
                    child: horse.imagePath != null
                        ? Image.file(File(horse.imagePath!), fit: BoxFit.contain)
                        : const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                  title: Text('馬ID: ${horse.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ステータス: ${horse.status}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                      if (horse.ownerName.isNotEmpty) Text('馬主: ${horse.ownerName} (ID: ${horse.ownerId})'),
                      if (horse.log != null && horse.log!.isNotEmpty)
                        Text('ログ: ${horse.log}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}