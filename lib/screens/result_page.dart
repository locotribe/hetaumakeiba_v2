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
              child: SingleChildScrollView( // ここをSingleChildScrollViewでラップしました
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
                              '購入内容',
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

  // 金額に応じた☆の数を返すヘルパーメソッド
  String _getStars(int amount) {
    String amountStr = amount.toString();
    int numDigits = amountStr.length;
    if (numDigits >= 6) {
      return '';
    } else if (numDigits == 5) {
      return '☆';
    } else if (numDigits == 4) {
      return '☆☆';
    } else if (numDigits == 3) {
      return '☆☆☆';
    }
    return ''; // 3桁未満の場合は☆なし
  }

  List<Widget> _buildHorseNumberWidgets(List<int> horseNumbers) {
    const double fixedWidth = 30.0; // 例: 2桁の数字が収まる程度の幅に調整してください

    return horseNumbers.map((number) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Container(
        width: fixedWidth, // 幅を固定
        alignment: Alignment.center, // 数字を中央寄せ
        padding: const EdgeInsets.symmetric(vertical: 2.0), // 垂直方向のパディングを調整
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          number.toString(),
          style: TextStyle(color: Colors.black54),
        ),
      ),
    )).toList();
  }

  List<Widget> _buildPurchaseDetails(dynamic purchaseData, String betType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    // Define a consistent width for labels to align content
    const double labelWidth = 80.0;

    if (betType == '応援馬券' && purchaseDetails.length >= 2) {
      final firstDetail = purchaseDetails[0];
      List<int> umanbanList = (firstDetail['馬番'] as List).cast<int>();
      int kingaku = firstDetail['購入金額'] as int; // int型で取得

      return [
        Row( // Keep '馬番' on the same line as the start of horse numbers
          crossAxisAlignment: CrossAxisAlignment.start, // Align to top
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                '馬番', // Colon removed
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.end, // Align text to the end of the SizedBox
              ),
            ),
            Expanded( // Allow horse numbers to take available space and wrap
              child: Wrap(
                spacing: 4.0, // horizontal space between items
                runSpacing: 4.0, // vertical space between lines
                children: _buildHorseNumberWidgets(umanbanList),
              ),
            ),
          ],
        ),
        // Add the "各☆☆☆〇円" line
        Text(
          '各${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
        // Restore the original "単勝" and "複勝" lines
        Text(
          '単勝 ${_getStars(kingaku)}${kingaku}円', // ☆を付与
          style: TextStyle(color: Colors.black54),
        ),
        Text(
          '複勝 ${_getStars(kingaku)}${kingaku}円', // ☆を付与
          style: TextStyle(color: Colors.black54),
        ),
      ];
    } else {
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        String nagashi = detail['ながし'] != null ? ' ${detail['ながashi']}' : '';
        int? kingaku = detail['購入金額']; // null許容int型で取得
        String kingakuDisplay = kingaku != null ? '${kingaku}円' : '';
        String uraDisplay = (detail['ウラ'] != null) ? 'ウラ: ${detail['ウラ']}' : '';

        List<Widget> detailWidgets = [];
        int combinations = 0; // Initialize combinations

        // Combination calculation logic
        if (betType == 'ボックス') {
          List<int> horseNumbers = (detail['馬番'] as List).cast<int>();
          int n = horseNumbers.length;
          if (shikibetsu == '馬連' || shikibetsu == '馬単') {
            combinations = n * (n - 1) ~/ (shikibetsu == '馬連' ? 2 : 1);
          } else if (shikibetsu == '3連複') {
            combinations = n * (n - 1) * (n - 2) ~/ 6; // nC3
          } else if (shikibetsu == '3連単') {
            combinations = n * (n - 1) * (n - 2); // nP3
          }
        } else if (betType == 'フォーメーション') {
          List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (shikibetsu == '3連単') {
            // For 3連単 formation, it's the product of the lengths of the horse groups
            if (horseGroups.length >= 3) {
              combinations = horseGroups[0].length * horseGroups[1].length * horseGroups[2].length;
            }
          } else if (shikibetsu == '3連複') {
            // For 3連複 formation, it's more complex, involving unique combinations from selected horses.
            // This is a simplified calculation for demonstration purposes.
            if (horseGroups.length >= 3) {
              combinations = horseGroups[0].length * horseGroups[1].length * horseGroups[2].length;
            }
          }
        } else if (betType == 'ながし') {
          int axisCount = 0;
          if (detail.containsKey('軸') && detail['軸'] is List) {
            axisCount = (detail['軸'] as List).length;
          } else if (detail.containsKey('軸') && detail['軸'] != null) {
            axisCount = 1; // Assuming a single axis horse if not a list
          }

          int opponentCount = 0;
          if (detail.containsKey('相手') && detail['相手'] is List) {
            opponentCount = (detail['相手'] as List).length;
          }
          combinations = axisCount * opponentCount;

          if (shikibetsu == '馬単' || shikibetsu == '3連単') {
            // For 馬単 and 3連単 nagashi, the combinations need to consider the order/permutations.
            // This is a simplified calculation; more complex logic might be needed depending on specific nagashi rules.
            // For now, it's a simple product of axis and opponent for basic cases.
          }
        }


        detailWidgets.add(Text(
          '式別 $shikibetsu$nagashi',
          style: TextStyle(color: Colors.black54),
        ));

        // Display combinations BEFORE the purchase amount
        if (combinations > 0) {
          detailWidgets.add(
            Text(
              '組合せ数: $combinations',
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          );
        }

        // 通常以外の買い目（複数の組み合わせがある場合）の判定を修正
        bool isComplexCombination = (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
            detail.containsKey('ながし') ||
            (detail.containsKey('馬番') is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List); // This condition specifically for formation where 馬番 is List<List<int>>


        if (detail['式別'] == '3連単' &&
            detail['馬番'] is List &&
            (detail['馬番'] as List).isNotEmpty &&
            (detail['馬番'] as List)[0] is List) {
          final List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (horseGroups.length >= 1) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '1着', // Colon removed
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _buildHorseNumberWidgets(horseGroups[0]),
                    ),
                  ),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 2) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '2着', // Colon removed
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _buildHorseNumberWidgets(horseGroups[1]),
                    ),
                  ),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 3) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '3着', // Colon removed
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _buildHorseNumberWidgets(horseGroups[2]),
                    ),
                  ),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('ながし')) {
          if (detail.containsKey('軸')) { // Changed from `detail['軸'] is List` to `detail.containsKey('軸')`
            List<int> axisHorses;
            if (detail['軸'] is List) {
              axisHorses = (detail['軸'] as List).cast<int>();
            } else {
              axisHorses = [(detail['軸'] as int)]; // Convert single int to list
            }
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '軸', // Colon removed
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _buildHorseNumberWidgets(axisHorses),
                    ),
                  ),
                ],
              ),
            ));
          }
          if (detail.containsKey('相手') && detail['相手'] is List) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '相手', // Colon removed
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _buildHorseNumberWidgets((detail['相手'] as List).cast<int>()),
                    ),
                  ),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') &&
            detail['馬番'] is List &&
            (detail['馬番'] as List).isNotEmpty &&
            (detail['馬番'] as List)[0] is List) {
          // This handles general formation (not just 3連単 specific logic)
          List<List<int>> formationHorseNumbers = (detail['馬番'] as List).cast<List<int>>();
          for (int i = 0; i < formationHorseNumbers.length; i++) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '${i + 1}組', // Colon removed
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _buildHorseNumberWidgets(formationHorseNumbers[i]),
                    ),
                  ),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    '馬番', // Colon removed
                    style: TextStyle(color: Colors.black54),
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: _buildHorseNumberWidgets((detail['馬番'] as List).cast<int>()),
                  ),
                ),
              ],
            ),
          ));
        }

        if (kingaku != null) { // 金額が存在する場合のみ表示
          String prefix = '';
          if (isComplexCombination) {
            prefix = '各組${_getStars(kingaku)}';
          } else {
            prefix = '${_getStars(kingaku)}';
          }
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text('$prefix$kingakuDisplay', style: TextStyle(color: Colors.black54)),
          ));
        }
        if (uraDisplay.isNotEmpty) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(uraDisplay, style: TextStyle(color: Colors.black54)),
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: detailWidgets,
        );
      }).toList();
    }
  }
}