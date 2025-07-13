// lib/screens/result_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'dart:convert'; // JsonEncoderを使用

class ResultPage extends StatelessWidget {
  final Map<String, dynamic>? parsedResult;

  const ResultPage({super.key, this.parsedResult});

  @override
  Widget build(BuildContext context) {
    final prettyJson = parsedResult != null
        ? JsonEncoder.withIndent('  ').convert(parsedResult)
        : 'QRコードの読み取りに失敗しました';

    // 合計金額を計算
    int totalAmount = 0;
    if (parsedResult != null && parsedResult!.containsKey('購入内容')) {
      List<Map<String, dynamic>> purchaseDetails = (parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
      for (var detail in purchaseDetails) {
        if (detail.containsKey('購入金額')) {
          totalAmount += (detail['購入金額'] as int);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('解析結果'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '解析結果',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: parsedResult == null
                    ? Center(
                  child: Text(
                    prettyJson,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
                    : (parsedResult!.containsKey('エラー')
                    ? Text(
                  'エラー: ${parsedResult!['エラー']}\n詳細: ${parsedResult!['詳細']}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: parsedResult!.keys.length + 1, // 合計金額の行を追加
                  itemBuilder: (context, index) {
                    // 合計金額の行はリストの最後に追加
                    if (index == parsedResult!.keys.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '合計金額:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$totalAmount円',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold, // 合計金額を目立たせる
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final key = parsedResult!.keys.elementAt(index);
                    final value = parsedResult![key];
                    final isUrl = key == 'URL' && value is String;

                    // parsedResultから方式を取得
                    final String betType = parsedResult!['方式'] ?? '';

                    // 指定された7項目のみ表示（「開催所」を「開催場」に修正）
                    if (!['開催場', '年', '回', '日', 'レース', '方式', '購入内容'].contains(key)) {
                      return const SizedBox.shrink(); // 指定外は非表示
                    }

                    if (key == '方式') {
                      String displayValue = value.toString();
                      if (displayValue == '応援馬券') {
                        displayValue = '単勝+複勝';
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '$key:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                displayValue,
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (key == '購入内容') {
                      List<Map<String, dynamic>> purchaseDetails = (value as List).cast<Map<String, dynamic>>();

                      // '応援馬券'の場合の特殊な表示ルール
                      if (betType == '応援馬券' && purchaseDetails.length >= 2) {
                        // 単勝と複勝の購入内容から情報を取得
                        final firstDetail = purchaseDetails[0]; // 単勝または複勝のどちらでも金額は同じなので一つを参照
                        String umanban = (firstDetail['馬番'] ?? []).toString().replaceAll('[', '').replaceAll(']', '');
                        String kingakuValue = firstDetail['購入金額'] != null ? firstDetail['購入金額'].toString() : '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '$key:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 100), // 他の値と揃えるためにインデント
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '馬番 $umanban 各${kingakuValue}円',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                        Text(
                                          '単勝 ${kingakuValue}円',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                        Text(
                                          '複勝 ${kingakuValue}円',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        // 他の方式の場合の既存ロジック
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // "購入内容:" ラベルの表示
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100, // 他のキーと幅を合わせる
                                    child: Text(
                                      '$key:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // 購入内容の詳細をインデントして表示
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 100), // 他の値と揃えるためにインデント
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: purchaseDetails.map((detail) {
                                        String shikibetsu = detail['式別'] ?? '';
                                        String umanban = (detail['馬番'] ?? []).toString().replaceAll('[', '').replaceAll(']', '');
                                        String nagashi = detail['ながし'] != null ? ' ${detail['ながし']}' : '';
                                        String jiku = (detail['軸'] is List) ? '軸:${(detail['軸'] as List).map((e) => e.toString()).join(',')}' : (detail['軸'] != null ? '軸:${detail['軸']}' : '');
                                        String aite = (detail['相手'] is List) ? '相手:${(detail['相手'] as List).map((e) => e.toString()).join(',')}' : '';
                                        String kingakuDisplay = detail['購入金額'] != null ? '${detail['購入金額']}円' : '';

                                        String combinationText;

                                        if (detail.containsKey('ながし')) {
                                          combinationText = '式別 $shikibetsu$nagashi';
                                          if (jiku.isNotEmpty) combinationText += ' $jiku';
                                          if (aite.isNotEmpty) combinationText += ' $aite';
                                        } else if (detail.containsKey('馬番') && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
                                          // フォーメーションの場合の処理
                                          List<List<int>> formationHorseNumbers = (detail['馬番'] as List).cast<List<int>>();
                                          combinationText = '式別 $shikibetsu';
                                          for (int i = 0; i < formationHorseNumbers.length; i++) {
                                            combinationText += ' ${formationHorseNumbers[i].join(',')}';
                                          }
                                        } else {
                                          combinationText = '式別 $shikibetsu 馬番 $umanban';
                                        }

                                        String uraDisplay = (detail['ウラ'] != null) ? ' ウラ:${detail['ウラ']}' : '';

                                        return Text(
                                          '$combinationText 金額 $kingakuDisplay$uraDisplay',
                                          style: TextStyle(color: Colors.black54),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              '$key:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                            child: isUrl
                                ? SelectableText.rich(
                              TextSpan(
                                text: value,
                                style: TextStyle(color: Colors.blue),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    launchUrl(Uri.parse(value));
                                  },
                              ),
                            )
                                : Text(
                              value.toString(),
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QRScannerPage()),
                      );
                      if (result != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultPage(parsedResult: result),
                          ),
                        );
                      }
                    },
                    child: const Text('次の馬券を登録'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}