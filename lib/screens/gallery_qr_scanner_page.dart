// lib/screens/gallery_qr_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート
import 'dart:ui' as ui; // BackdropFilterのために必要
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート
import 'dart:convert'; // JsonEncoderのために必要

class GalleryQrScannerPage extends StatefulWidget {
  final String scanMethod; // スキャン方法を受け取るためのプロパティ
  final GlobalKey<SavedTicketsListPageState> savedListKey; // Keyを受け取る

  const GalleryQrScannerPage({
    super.key,
    this.scanMethod = 'unknown',
    required this.savedListKey,
  });

  @override
  State<GalleryQrScannerPage> createState() => _GalleryQrScannerPageState();
}

class _GalleryQrScannerPageState extends State<GalleryQrScannerPage> {
  Map<String, dynamic>? _parsedResultForOverlay; // オーバーレイ表示用の解析結果
  bool _showResultOverlay = false; // 結果オーバーレイの表示状態

  // ダミーのQRコード解析処理
  void _processDummyQrCode() {
    final dummyParsedData = {
      'エラー': 'ギャラリー機能は未実装です',
      '詳細': 'ダミーデータです。実際のQRコードは検出されていません。',
      'QR': 'DUMMY_QR_CODE_FROM_GALLERY',
      '年': '2024',
      '回': '1',
      '日': '1',
      '開催場': '東京',
      'レース': '1R',
      '方式': '通常',
      '購入内容': [
        {'式別': '単勝', '馬番': [1], '購入金額': 100},
      ],
      '発売所': 'JRA東京',
    };

    setState(() {
      _parsedResultForOverlay = dummyParsedData;
      _showResultOverlay = true;
    });

    widget.savedListKey.currentState?.loadData();
  }

  void _hideResultOverlay() {
    setState(() {
      _showResultOverlay = false;
      _parsedResultForOverlay = null;
    });
  }

  // ResultPageから移動したヘルパーメソッド群
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
    return '';
  }

  String _getHorseNumberSymbol(String shikibetsu, String betType) {
    if (betType == '通常') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') {
        return '→';
      } else if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') {
        return '-';
      } else if (shikibetsu == 'ワイド') {
        return '◆';
      }
    }
    return '';
  }

  List<Widget> _buildHorseNumberDisplay(List<int> horseNumbers, {String symbol = ''}) {
    List<Widget> widgets = [];
    const double fixedWidth = 30.0;

    for (int i = 0; i < horseNumbers.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Container(
            width: fixedWidth,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black54),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              horseNumbers[i].toString(),
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
      if (symbol.isNotEmpty && i < horseNumbers.length - 1) {
        widgets.add(
          Text(symbol, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildPurchaseDetails(dynamic purchaseData, String betType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    const double labelWidth = 80.0;

    if (betType == '応援馬券' && purchaseDetails.length >= 2) {
      final firstDetail = purchaseDetails[0];
      List<int> umanbanList = (firstDetail['馬番'] as List).cast<int>();
      int kingaku = firstDetail['購入金額'] as int;

      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                '馬番',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Wrap(
                children: [..._buildHorseNumberDisplay(umanbanList, symbol: '')],
              ),
            ),
          ],
        ),
        Text(
          '各${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
        Text(
          '単勝 ${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
        Text(
          '複勝 ${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
      ];
    } else {
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        int? kingaku = detail['購入金額'];
        String kingakuDisplay = kingaku != null ? '${kingaku}円' : '';
        String uraDisplay = (detail['ウラ'] != null) ? 'ウラ: ${detail['ウラ']}' : '';

        List<Widget> detailWidgets = [];
        int combinations = 0;

        if (betType == 'ボックス') {
          List<int> horseNumbers = (detail['馬番'] as List).cast<int>();
          int n = horseNumbers.length;
          if (shikibetsu == '馬連' || shikibetsu == '馬単') {
            combinations = n * (n - 1) ~/ (shikibetsu == '馬連' ? 2 : 1);
          } else if (shikibetsu == '3連複') {
            combinations = n * (n - 1) * (n - 2) ~/ 6;
          } else if (shikibetsu == '3連単') {
            combinations = n * (n - 1) * (n - 2);
          }
        } else if (betType == 'フォーメーション') {
          List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (shikibetsu == '3連単') {
            if (horseGroups.length >= 3) {
              combinations = horseGroups[0].length * horseGroups[1].length * horseGroups[2].length;
            }
          } else if (shikibetsu == '3連複') {
            if (horseGroups.length >= 3) {
              combinations = horseGroups[0].length * horseGroups[1].length * horseGroups[2].length;
            }
          }
        } else if (betType == 'ながし') {
          int axisCount = 0;
          if (detail.containsKey('軸') && detail['軸'] is List) {
            axisCount = (detail['軸'] as List).length;
          } else if (detail.containsKey('軸') && detail['軸'] != null) {
            axisCount = 1;
          }

          int opponentCount = 0;
          if (detail.containsKey('相手') && detail['相手'] is List) {
            opponentCount = (detail['相手'] as List).length;
          }
          combinations = axisCount * opponentCount;
        }

        bool isComplexCombinationForPrefix =
            (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
                detail.containsKey('ながし') ||
                (betType == 'ボックス');

        String prefixForAmount = '';
        if (kingaku != null) {
          if (isComplexCombinationForPrefix) {
            prefixForAmount = '各組${_getStars(kingaku)}';
          } else {
            prefixForAmount = '${_getStars(kingaku)}';
          }
        }

        if (combinations > 0) {
          detailWidgets.add(
            Text(
              '組合せ数 $combinations',
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          );
        }

        bool amountHandledInline = false;

        if (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          final List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (horseGroups.length >= 1) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('1着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[0], symbol: '')])),
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
                  SizedBox(width: labelWidth, child: Text('2着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[1], symbol: '')])),
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
                  SizedBox(width: labelWidth, child: Text('3着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[2], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('ながし')) {
          if (detail.containsKey('軸')) {
            List<int> axisHorses = detail['軸'] is List ? (detail['軸'] as List).cast<int>() : [(detail['軸'] as int)];
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('軸', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(axisHorses, symbol: '')])),
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
                  SizedBox(width: labelWidth, child: Text('相手', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay((detail['相手'] as List).cast<int>(), symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          List<List<int>> formationHorseNumbers = (detail['馬番'] as List).cast<List<int>>();
          for (int i = 0; i < formationHorseNumbers.length; i++) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('${i + 1}組', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(formationHorseNumbers[i], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List) {
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, betType);

          if (!isComplexCombinationForPrefix) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '馬番',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: [
                        ..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: currentSymbol),
                        if (kingaku != null)
                          Text(
                            '$prefixForAmount$kingakuDisplay',
                            style: TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
            amountHandledInline = true;
          } else {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '馬番',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: '')],
                    ),
                  ),
                ],
              ),
            ));
          }
        }

        if (kingaku != null && !amountHandledInline) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text('$prefixForAmount$kingakuDisplay', style: TextStyle(color: Colors.black54)),
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

  // ResultPageのbuildメソッドの内容をウィジェットとして返す新しいメソッド
  Widget _buildResultContent(Map<String, dynamic>? parsedResult) {
    final prettyJson = parsedResult != null
        ? JsonEncoder.withIndent('  ').convert(parsedResult)
        : '馬券の読み取りに失敗しました';

    int totalAmount = 0;
    if (parsedResult != null && parsedResult.containsKey('購入内容')) {
      List<Map<String, dynamic>> purchaseDetails = (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
      for (var detail in purchaseDetails) {
        if (detail.containsKey('購入金額')) {
          totalAmount += (detail['購入金額'] as int);
        }
      }
    }

    String? salesLocation;
    if (parsedResult != null && parsedResult.containsKey('発売所')) {
      salesLocation = parsedResult['発売所'] as String;
    }

    return Padding(
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
            child: SingleChildScrollView(
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
                    : (parsedResult.containsKey('エラー')
                    ? Text(
                  'エラー: ${parsedResult['エラー']}\n詳細: ${parsedResult['詳細']}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parsedResult.containsKey('年') && parsedResult.containsKey('回') && parsedResult.containsKey('日'))
                      Text(
                        '${parsedResult['年']}年${parsedResult['回']}回${parsedResult['日']}日',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 4),
                    if (parsedResult.containsKey('開催場') && parsedResult.containsKey('レース'))
                      Text(
                        '${parsedResult['開催場']}${parsedResult['レース']}レース',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 8),
                    if (parsedResult.containsKey('購入内容') && parsedResult.containsKey('方式'))
                      Builder(builder: (context) {
                        final List<Map<String, dynamic>> purchaseDetails =
                        (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
                        String betType = parsedResult['方式'] ?? '';
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
                    if (parsedResult.containsKey('購入内容'))
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
                              children: _buildPurchaseDetails(parsedResult['購入内容'], parsedResult['方式']),
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
                              '合計金額',
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
                    if (salesLocation != null && salesLocation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '発売所',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                salesLocation,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Scaffoldを再導入
      appBar: AppBar( // AppBarを再導入
        title: const Text('ギャラリーから読み込み'), // AppBarのタイトル
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // テーマから背景色を取得
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor, // テーマから前景色を取得
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ギャラリーからの読み込み機能は\n今後実装予定です。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _processDummyQrCode,
                  child: const Text('ダミーデータでResultPageへ'),
                ),
              ],
            ),
          ),

          if (_showResultOverlay)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: SingleChildScrollView(
                      child: AlertDialog(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                        title: Text(
                          'スキャン結果',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildResultContent(_parsedResultForOverlay), // 統合されたResultPageの内容を表示
                        ),
                        actions: [
                          TextButton(
                            onPressed: _hideResultOverlay,
                            child: const Text('次の馬券を読み込む (ダミー)'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: const Text('トップ画面に戻る'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
