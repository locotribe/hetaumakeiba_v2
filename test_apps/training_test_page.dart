import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    home: TrainingTestPage(),
    theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
  ));
}

class TrainingTestPage extends StatefulWidget {
  @override
  _TrainingTestPageState createState() => _TrainingTestPageState();
}

class _TrainingTestPageState extends State<TrainingTestPage> {
  // テスト用初期値: フィリーズレビュー (2026/03/07 阪神 11R)
  final _dateController = TextEditingController(text: '20260307');
  final _placeController = TextEditingController(text: '3');
  final _roundController = TextEditingController(text: '11');
  // 添付されたCSVにある実際の馬IDをセット
  final _horseIdsController = TextEditingController(text: '2023101159,2023103086,2023106780');

  String _csvOutput = '';
  bool _isLoading = false;

  Future<void> _fetchTrainingData() async {
    setState(() { _isLoading = true; _csvOutput = ''; });

    try {
      final date = _dateController.text;
      final place = _placeController.text;
      final round = _roundController.text;
      final horseIds = _horseIdsController.text.split(',').map((e) => e.trim()).toList();

      print('--- [DEBUG] 調教データ取得開始 ---');
      print('リクエストパラメータ: 日付=$date, 場所=$place, レース=$round, 対象馬頭数=${horseIds.length}');

      final urls = [
        'https://pakara-keiba.com/ajax/race/get_cyoukyou.php',
        'https://pakara-keiba.com/ajax/race/get_cyoukyou_wc.php'
      ];

      final Map<String, String> body = {
        "date": date,
        "place": place,
        "round": round,
      };
      for (int i = 0; i < horseIds.length; i++) {
        body["name$i"] = horseIds[i];
      }

      String combinedCsv = "種別,馬ID,調教日,時間,6F,5F,4F,3F,2F,1F,厩舎\n";

      for (var url in urls) {
        final isWC = url.contains('wc');
        final typeLabel = isWC ? "ウッド" : "坂路";

        print('[$typeLabel] APIリクエスト送信中: $url');

        final response = await http.post(
          Uri.parse(url),
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-Requested-With": "XMLHttpRequest",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          },
          body: body,
        );

        print('[$typeLabel] レスポンス受信: Status=${response.statusCode}');

        if (response.statusCode == 200) {
          // レスポンスが空でないか、HTMLが混じっていないか確認するためのログ
          if (response.body.length < 100) {
            print('[$typeLabel] 受信データ(生): ${response.body}');
          } else {
            print('[$typeLabel] 受信データサイズ: ${response.body.length} bytes');
          }

          final dynamic decoded = json.decode(response.body);
          if (decoded is List) {
            print('[$typeLabel] パース成功: ${decoded.length} 頭分のデータを検知');

            for (var horse in decoded) {
              final hId = horse['name'] ?? '不明';
              final cyoukyou = horse['cyoukyou'] as List?;

              if (cyoukyou != null && cyoukyou.isNotEmpty) {
                print('  - 馬ID: $hId (${cyoukyou.length} 件の履歴)');
                for (var c in cyoukyou) {
                  combinedCsv += "$typeLabel,$hId,${c['date']},${c['time']},${c['f6']??''},${c['f5']??''},${c['f4']??''},${c['f3']??''},${c['f2']??''},${c['f1']??''},${c['kyuusya']??''}\n";
                }
              } else {
                print('  - 馬ID: $hId (調教データなし)');
              }
            }
          }
        } else {
          print('[$typeLabel] エラー: サーバーがステータスコード ${response.statusCode} を返しました');
          combinedCsv += "エラー: $typeLabel 取得失敗 (Status: ${response.statusCode})\n";
        }
      }

      print('--- [DEBUG] 全工程完了 ---');
      setState(() { _csvOutput = combinedCsv; });
    } catch (e) {
      print('--- [CRITICAL ERROR] ---');
      print(e);
      setState(() { _csvOutput = "実行エラー: $e"; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("調教APIデバッグテスト")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: TextField(controller: _dateController, decoration: InputDecoration(labelText: "日付 (YYYYMMDD)"))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: _placeController, decoration: InputDecoration(labelText: "場所コード"))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: _roundController, decoration: InputDecoration(labelText: "レース番号"))),
            ]),
            TextField(controller: _horseIdsController, decoration: InputDecoration(labelText: "馬ID（カンマ区切り）")),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchTrainingData,
              icon: Icon(Icons.bug_report),
              label: Text("デバッグ実行"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[100],
                  minimumSize: Size(double.infinity, 50)
              ),
            ),
            if (_isLoading) LinearProgressIndicator(),
            SizedBox(height: 16),
            Text("出力結果 (CSV形式):", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8)
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                      _csvOutput,
                      style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 10)
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}