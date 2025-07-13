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
              '読み込んだ馬券',
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
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parsedResult!.containsKey('年') && parsedResult!.containsKey('回') && parsedResult!.containsKey('日'))
                      Text(
                        '${parsedResult!['年']}年${parsedResult!['回']}回${parsedResult!['日']}日',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 4),
                    if (parsedResult!.containsKey('開催場') && parsedResult!.containsKey('レース'))
                      Text(
                        '${parsedResult!['開催場']}${parsedResult!['レース']}レース',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 8),
                    if (parsedResult!.containsKey('購入内容') && parsedResult!.containsKey('方式'))
                      Builder(builder: (context) {
                        final List<Map<String, dynamic>> purchaseDetails =
                        (parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
                        String betType = parsedResult!['方式'] ?? '';
                        String shikibetsu = '';
                        if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
                          shikibetsu = purchaseDetails[0]['式別'];
                        }

                        String displayString = shikibetsu;

                        if (betType == '応援馬券') {
                          displayString = '応援馬券 単勝+複勝';
                        } else if (betType == 'ながし') {
                          if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('ながし')) {
                            displayString += ' ${purchaseDetails[0]['ながし']}';
                          } else {
                            displayString += ' ながし';
                          }
                        } else {
                          displayString += ' $betType';
                        }

                        return Text(
                          displayString,
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        );
                      }),
                    const SizedBox(height: 8),
                    if (parsedResult!.containsKey('購入内容'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '購入内容:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildPurchaseDetails(parsedResult!['購入内容'], parsedResult!['方式']),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Padding(
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
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$totalAmount円',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  List<Widget> _buildPurchaseDetails(dynamic purchaseData, String betType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    if (betType == '応援馬券' && purchaseDetails.length >= 2) {
      final firstDetail = purchaseDetails[0];
      String umanban = (firstDetail['馬番'] ?? []).toString().replaceAll('[', '').replaceAll(']', '');
      String kingakuValue = firstDetail['購入金額'] != null ? firstDetail['購入金額'].toString() : '';

      return [
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
      ];
    } else {
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        String umanban = (detail['馬番'] ?? []).toString().replaceAll('[', '').replaceAll(']', '');
        String nagashi = detail['ながし'] != null ? ' ${detail['ながし']}' : '';
        String jiku = (detail['軸'] is List)
            ? '軸:${(detail['軸'] as List).map((e) => e.toString()).join(',')}'
            : (detail['軸'] != null ? '軸:${detail['軸']}' : '');
        String aite = (detail['相手'] is List) ? '相手:${(detail['相手'] as List).map((e) => e.toString()).join(',')}' : '';
        String kingakuDisplay = detail['購入金額'] != null ? '${detail['購入金額']}円' : '';
        String uraDisplay = (detail['ウラ'] != null) ? ' ウラ:${detail['ウラ']}' : '';

        String combinationText;

        if (detail['式別'] == '3連単' &&
            detail['馬番'] is List &&
            (detail['馬番'] as List).isNotEmpty &&
            (detail['馬番'] as List)[0] is List) {
          combinationText = '式別 $shikibetsu$nagashi';
          final List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (horseGroups.length >= 1) {
            jiku = '1着: ${horseGroups[0].join(',')}';
          }
          if (horseGroups.length >= 2) {
            aite = '2着: ${horseGroups[1].join(',')}';
          }
          if (horseGroups.length >= 3) {
            aite += ' / 3着: ${horseGroups[2].join(',')}';
          }
          combinationText += ' $jiku $aite';
        } else if (detail.containsKey('ながし')) {
          combinationText = '式別 $shikibetsu$nagashi';
          if (jiku.isNotEmpty) combinationText += ' $jiku';
          if (aite.isNotEmpty) combinationText += ' $aite';
        } else if (detail.containsKey('馬番') &&
            detail['馬番'] is List &&
            (detail['馬番'] as List).isNotEmpty &&
            (detail['馬番'] as List)[0] is List) {
          List<List<int>> formationHorseNumbers = (detail['馬番'] as List).cast<List<int>>();
          combinationText = '式別 $shikibetsu';
          for (int i = 0; i < formationHorseNumbers.length; i++) {
            combinationText += ' ${formationHorseNumbers[i].join(',')}_';
          }
          if (combinationText.endsWith('_')) {
            combinationText = combinationText.substring(0, combinationText.length - 1);
          }
        } else {
          combinationText = '式別 $shikibetsu 馬番 $umanban';
        }

        return Text(
          '$combinationText 金額 $kingakuDisplay$uraDisplay',
          style: TextStyle(color: Colors.black54),
        );
      }).toList();
    }
  }
}
