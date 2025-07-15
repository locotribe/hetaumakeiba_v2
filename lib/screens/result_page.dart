import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
// QRScannerPage や GalleryQrScannerPage は直接プッシュしなくなるため、インポートは不要になる可能性がありますが、
// _currentScanMethod を保持するロジックの簡略化のため、ここでは残しておきます。
// import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
// import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/scan_selection_page.dart'; // スキャン選択ページをインポート
import 'dart:convert'; // JsonEncoderを使用

// StatefulWidget に変更
class ResultPage extends StatefulWidget {
  final Map<String, dynamic>? parsedResult;
  // previousScanMethod は直接遷移に使わなくなるため、削除またはコメントアウト
  // final String? previousScanMethod; // コンストラクタから削除

  const ResultPage({super.key, this.parsedResult}); // previousScanMethod をコンストラクタから削除

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  // parsedResult を State の変数として管理
  Map<String, dynamic>? _parsedResult;
  String? _currentScanMethod; // 現在のスキャン方法を保持

  @override
  void initState() {
    super.initState();
    _parsedResult = widget.parsedResult?['parsedData']; // 'parsedData'キーから実際の解析結果を取得
    _currentScanMethod = widget.parsedResult?['scanMethod'] ?? 'unknown'; // スキャン方法を取得
  }

  // parsedResult が更新された場合に State を更新する
  @override
  void didUpdateWidget(covariant ResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parsedResult != oldWidget.parsedResult) {
      setState(() {
        _parsedResult = widget.parsedResult?['parsedData'];
        _currentScanMethod = widget.parsedResult?['scanMethod'] ?? 'unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prettyJson = _parsedResult != null
        ? JsonEncoder.withIndent('  ').convert(_parsedResult)
        : '馬券の読み取りに失敗しました';

    // 合計金額を計算
    int totalAmount = 0;
    if (_parsedResult != null && _parsedResult!.containsKey('購入内容')) {
      List<Map<String, dynamic>> purchaseDetails = (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
      for (var detail in purchaseDetails) {
        if (detail.containsKey('購入金額')) {
          totalAmount += (detail['購入金額'] as int);
        }
      }
    }

    // Check for 発売所 information
    String? salesLocation;
    // Assuming '発売所' key might exist at the top level of _parsedResult if available
    if (_parsedResult != null && _parsedResult!.containsKey('発売所')) {
      salesLocation = _parsedResult!['発売所'] as String;
    }


    return Padding( // This is the root of ResultPage after Scaffold/AppBar removal
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
                child: _parsedResult == null
                    ? Center(
                  child: Text(
                    prettyJson,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
                    : (_parsedResult!.containsKey('エラー')
                    ? Text(
                  'エラー: ${_parsedResult!['エラー']}\n詳細: ${_parsedResult!['詳細']}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_parsedResult!.containsKey('年') && _parsedResult!.containsKey('回') && _parsedResult!.containsKey('日'))
                      Text(
                        '${_parsedResult!['年']}年${_parsedResult!['回']}回${_parsedResult!['日']}日',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 4),
                    if (_parsedResult!.containsKey('開催場') && _parsedResult!.containsKey('レース'))
                      Text(
                        '${_parsedResult!['開催場']}${_parsedResult!['レース']}レース',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 8),
                    if (_parsedResult!.containsKey('購入内容') && _parsedResult!.containsKey('方式'))
                      Builder(builder: (context) {
                        final List<Map<String, dynamic>> purchaseDetails =
                        (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
                        String betType = _parsedResult!['方式'] ?? '';
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
                    if (_parsedResult!.containsKey('購入内容'))
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
                              children: _buildPurchaseDetails(_parsedResult!['購入内容'], _parsedResult!['方式']),
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
          // ResultPageがオーバーレイとして使用されるため、これらのボタンはQRScannerPageのオーバーレイに移動
          // const SizedBox(height: 20),
          // ElevatedButton(
          //   onPressed: () async {
          //     // 直前のスキャン方法に基づいて次のスキャン画面に直接遷移 (pushReplacementに戻す)
          //     if (_currentScanMethod == 'camera') {
          //       Navigator.of(context, rootNavigator: false).pushReplacement(
          //         MaterialPageRoute(builder: (_) => const QRScannerPage(scanMethod: 'camera')),
          //       );
          //     } else if (_currentScanMethod == 'gallery') {
          //       Navigator.of(context, rootNavigator: false).pushReplacement(
          //         MaterialPageRoute(builder: (_) => const GalleryQrScannerPage(scanMethod: 'gallery')),
          //       );
          //     } else {
          //       // どちらでもない場合は、スキャン選択ページに戻る（フォールバック）
          //       Navigator.of(context, rootNavigator: false).pushReplacement(
          //         MaterialPageRoute(builder: (_) => const ScanSelectionPage()),
          //       );
          //     }
          //   },
          //   style: ElevatedButton.styleFrom(
          //     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          //     textStyle: const TextStyle(fontSize: 18),
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          //   ),
          //   child: const Text('次の馬券を読み込む'),
          // ),
          // const SizedBox(height: 10), // ボタン間のスペース
          // ElevatedButton(
          //   onPressed: () {
          //     // ナビゲーションスタックをクリアしてトップ画面に戻る
          //     Navigator.of(context).popUntil((route) => route.isFirst);
          //   },
          //   style: ElevatedButton.styleFrom(
          //     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          //     textStyle: const TextStyle(fontSize: 18),
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          //     backgroundColor: Colors.grey, // 差別化のために色を変更
          //   ),
          //   child: const Text('トップ画面に戻る'),
          // ),
        ],
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

  // 馬番と馬番の間に表示する記号を返すヘルパーメソッド
  String _getHorseNumberSymbol(String shikibetsu, String betType) {
    // 方式が「通常」の場合のみ記号を適用
    if (betType == '通常') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') {
        return '→';
      } else if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') {
        return '-';
      } else if (shikibetsu == 'ワイド') {
        return '◆';
      }
    }
    // その他の方式（ボックス、ながし、フォーメーション、応援馬券）や、
    // 「通常」でも記号が不要な式別（単勝、複勝）は空文字を返す
    return '';
  }


  // 馬番のリストを記号を挟んで表示するウィジェットのリストを生成するヘルパーメソッド
  List<Widget> _buildHorseNumberDisplay(List<int> horseNumbers, {String symbol = ''}) {
    List<Widget> widgets = [];
    const double fixedWidth = 30.0; // 例: 2桁の数字が収まる程度の幅に調整してください

    for (int i = 0; i < horseNumbers.length; i++) {
      widgets.add(
        Padding(
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
              horseNumbers[i].toString(),
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
      // 最後の馬番の後には記号を追加しない
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

    // '応援馬券'の処理は、他の複雑なロジックと分離して、購入内容のトップで処理
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
              child: Wrap( // Wrap widget to handle overflow
                children: [..._buildHorseNumberDisplay(umanbanList, symbol: '')], // 応援馬券は記号なし
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
      // その他の買い方の場合
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        String nagashi = detail['ながし'] != null ? ' ${detail['ながし']}' : ''; // Typo fixed: nagashi
        int? kingaku = detail['購入金額'];
        String kingakuDisplay = kingaku != null ? '${kingaku}円' : '';
        String uraDisplay = (detail['ウラ'] != null) ? 'ウラ: ${detail['ウラ']}' : '';

        List<Widget> detailWidgets = [];
        int combinations = 0;

        // 組み合わせ数の計算ロジック（変更なし）
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

        // 「各組」プレフィックスと金額の改行表示を制御する複雑な組み合わせの判定
        bool isComplexCombinationForPrefix =
            (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
                detail.containsKey('ながし') ||
                (betType == 'ボックス'); // ボックスは「各組」プレフィックスを使用し、金額は改行で表示

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

        bool amountHandledInline = false; // Flag to track if amount is displayed on the same line

        // Display blocks for different betting types
        if (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          // Formation (3連単)
          final List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (horseGroups.length >= 1) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('1着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[0], symbol: '')])), // フォーメーションは記号なし
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
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[1], symbol: '')])), // フォーメーションは記号なし
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
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[2], symbol: '')])), // フォーメーションは記号なし
                ],
              ),
            ));
          }
        } else if (detail.containsKey('ながし')) {
          // Nagashi
          if (detail.containsKey('軸')) {
            List<int> axisHorses = detail['軸'] is List ? (detail['軸'] as List).cast<int>() : [(detail['軸'] as int)];
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('軸', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(axisHorses, symbol: '')])), // ながしは記号なし
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
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay((detail['相手'] as List).cast<int>(), symbol: '')])), // ながしは記号なし
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          // General Formation (e.g., 3連複 formation)
          List<List<int>> formationHorseNumbers = (detail['馬番'] as List).cast<List<int>>();
          for (int i = 0; i < formationHorseNumbers.length; i++) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('${i + 1}組', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(formationHorseNumbers[i], symbol: '')])), // フォーメーションは記号なし
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List) {
          // This block covers '通常の買い方' (amount inline) AND 'ボックス' (amount on new line)
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, betType); // 馬番間の記号を取得

          if (!isComplexCombinationForPrefix) { // This condition identifies '通常の買い方'
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Changed from baseline to start
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
                    child: Wrap( // Use Wrap here to handle wrapping for horse numbers and amount
                      spacing: 4.0, // Space between items in the wrap
                      runSpacing: 4.0, // Space between lines of wrapped items
                      children: [
                        // Spread the horse number widgets generated by _buildHorseNumberDisplay
                        ..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: currentSymbol),
                        if (kingaku != null)
                          Text( // Amount text, now directly in Wrap
                            '$prefixForAmount$kingakuDisplay',
                            style: TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
            amountHandledInline = true; // Mark amount as handled within the Wrap
          } else { // This else block handles 'ボックス'
            // For Box, display horse numbers, but amount will be added on a new line below
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
                    child: Wrap( // Using Wrap here for consistent _buildHorseNumberDisplay usage
                      children: [..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: '')], // ボックスは記号なし
                    ),
                  ),
                ],
              ),
            ));
            // amountHandledInline remains false, so it will be added on a new line at the end
          }
        }

        // Add amount on a new line if not already handled inline (e.g., for Formations, Nagashi, Box)
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
}
