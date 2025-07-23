// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart'; // ★変更なし

class ResultPage extends StatefulWidget {
  final Map<String, dynamic>? parsedResult;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const ResultPage({
    super.key,
    this.parsedResult,
    required this.savedListKey,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Map<String, dynamic>? _parsedResult;

  @override
  void initState() {
    super.initState();
    _parsedResult = widget.parsedResult;
  }

  @override
  void didUpdateWidget(covariant ResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parsedResult != oldWidget.parsedResult) {
      setState(() {
        _parsedResult = widget.parsedResult;
      });
    }
  }

  // 半角数字を全角数字に変換するヘルパー関数
  String _convertHalfWidthNumbersToFullWidth(String text) {
    return text
        .replaceAll('0', '０')
        .replaceAll('1', '１')
        .replaceAll('2', '２')
        .replaceAll('3', '３')
        .replaceAll('4', '４')
        .replaceAll('5', '５')
        .replaceAll('6', '６')
        .replaceAll('7', '７')
        .replaceAll('8', '８')
        .replaceAll('9', '９');
  }

  @override
  Widget build(BuildContext context) {
    String displayMessage;
    bool isErrorOrNotTicket = false;

    if (_parsedResult == null) {
      displayMessage = '馬券の読み取りに失敗しました';
      isErrorOrNotTicket = true;
    } else if (_parsedResult!.containsKey('isNotTicket') && _parsedResult!['isNotTicket'] == true) {
      displayMessage = '馬券ではありませんでした';
      isErrorOrNotTicket = true;
    } else if (_parsedResult!.containsKey('エラー')) {
      displayMessage = 'エラー: ${_parsedResult!['エラー']}\n詳細: ${_parsedResult!['詳細']}';
      isErrorOrNotTicket = true;
    } else {
      displayMessage = JsonEncoder.withIndent('  ').convert(_parsedResult);
    }

    // totalAmountの計算ロジックは変更なし
    int totalAmount = 0;
    if (_parsedResult != null && _parsedResult!.containsKey('購入内容')) {
      List<Map<String, dynamic>> purchaseDetails = (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
      for (var detail in purchaseDetails) {
        if (detail.containsKey('購入金額')) {
          int kingakuPerCombination = detail['購入金額'] as int;
          if (detail.containsKey('表示用相手頭数') && detail.containsKey('表示用乗数')) {
            // Case for Multi with specific display values (e.g., 3x6)
            int opponentCountForDisplay = detail['表示用相手頭数'] as int;
            int multiplierForDisplay = detail['表示用乗数'] as int;
            totalAmount += (opponentCountForDisplay * multiplierForDisplay * kingakuPerCombination);
          } else if (detail.containsKey('組合せ数')) {
            // Case for regular combinations (e.g., 12 combinations)
            int combinations = detail['組合せ数'] as int;
            totalAmount += (combinations * kingakuPerCombination);
          } else {
            // Default: just add the purchase amount if no combination info
            totalAmount += kingakuPerCombination;
          }
        }
      }
    }

    String? salesLocation;
    if (_parsedResult != null && _parsedResult!.containsKey('発売所')) {
      salesLocation = _parsedResult!['発売所'] as String;
    }

    // 式別と方式の計算ロジックは変更なし
    String shikibetsuToDisplay = ''; // 例: 馬単, 応援馬券, ボックス
    String hoshikiToDisplay = ''; // 例: マルチ, 単勝+複勝, 軸1頭

    if (_parsedResult != null && _parsedResult!.containsKey('式別')) {
      String overallMethod = _parsedResult!['式別'] ?? '';
      String primaryShikibetsuFromDetails = '';

      List<Map<String, dynamic>> purchaseDetails = [];
      if (_parsedResult!.containsKey('購入内容')) {
        purchaseDetails = (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
        if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
          primaryShikibetsuFromDetails = purchaseDetails[0]['式別'];
        }
      }

      if (overallMethod == '応援馬券') {
        shikibetsuToDisplay = '単勝＋複勝';
        hoshikiToDisplay = 'がんばれ！';
      } else if (overallMethod == '通常') {
        shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : '通常';
        hoshikiToDisplay = ''; // 「通常」の場合は方式を独立して表示しない
      } else {
        // ボックス, ながし, フォーメーション, クイックピック
        shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : overallMethod;

        if (overallMethod == 'ながし' && primaryShikibetsuFromDetails.isNotEmpty && purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('ながし')) {
          hoshikiToDisplay = purchaseDetails[0]['ながし']; // 例: 軸1頭, 軸2頭
        } else if (primaryShikibetsuFromDetails.isNotEmpty) {
          hoshikiToDisplay = overallMethod; // 例: ボックス, フォーメーション, クイックピック
        } else {
          // primaryShikibetsuFromDetailsがない場合は、方式も表示しない（overallMethodが式別として表示されるため）
          hoshikiToDisplay = '';
        }
      }
      // 半角数字を全角に変換
      shikibetsuToDisplay = _convertHalfWidthNumbersToFullWidth(shikibetsuToDisplay);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('解析結果'),
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
          Column( // ページ全体のコンテンツを縦に並べる
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isErrorOrNotTicket
                        ? Center(
                      child: Text(
                        displayMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: _parsedResult != null && _parsedResult!.containsKey('エラー') ? Colors.red : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : Column( // メインコンテンツの縦並び
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // コンテナ1: レース情報など表示
                        // 現在のリザルトページのレース情報部分をここに配置
                        if (_parsedResult!.containsKey('年') && _parsedResult!.containsKey('回') && _parsedResult!.containsKey('日'))
                          Text(
                            '20${_parsedResult!['年']}年${_parsedResult!['回']}回${_parsedResult!['日']}日',
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        const SizedBox(height: 4),
                        if (_parsedResult!.containsKey('開催場') && _parsedResult!.containsKey('レース'))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_parsedResult!['開催場']}',
                                style: TextStyle(color: Colors.black, fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 0),
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.all(Radius.circular(0)),
                                    ),
                                    child: Text(
                                      '${_parsedResult!['レース']}',
                                      style: const TextStyle(color: Colors.white, fontSize: 28, height: 0.9),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'レース',
                                    style: TextStyle(color: Colors.black, fontSize: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 16), // レース情報と次のRowの間にスペース

                        // 中央のRowで式別と購入内容を横に並べる
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // 子ウィジェットを上揃えにする
                          children: [
                            // コンテナ2: 左側の式別関連の親コンテナ
                            // 幅は固定ではなく、flexで調整することでレスポンシブに対応
                            Expanded(
                              flex: 15, // 幅の比率
                              child: Column( // コンテナ4, 5, 6を縦に並べる
                                mainAxisSize: MainAxisSize.min, // Columnの高さを内容に合わせる
                                crossAxisAlignment: CrossAxisAlignment.start, // 各文字を左揃え
                                children: [
                                  // コンテナ4: 式別の英語名を表示（未実装）
                                  // 仮のテキストを配置
                                  Container(
                                    // width: 100, // 固定幅ではなくコンテンツに合わせるかExpandedで
                                    // height: 39, // 固定高ではなくコンテンツに合わせるかExpandedで
                                    padding: const EdgeInsets.all(4.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue), // 仮のボーダー
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: const Text(
                                      'BET TYPE (Top)', // 仮の英語名
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(height: 8), // スペース

                                  // コンテナ5: 式別のみ表示
                                  // 現在のリザルトページの式別表示部分をここに配置
                                  _parsedResult!.containsKey('式別')
                                      ? Align( // 垂直方向の中央揃え
                                    alignment: Alignment.center,
                                    child: Container( // ★Containerを追加して線で囲む
                                      padding: const EdgeInsets.all(4.0), // 内側の余白
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black, width: 2.0), // 線の色と太さ
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min, // Columnの高さを内容に合わせる
                                        crossAxisAlignment: CrossAxisAlignment.start, // 各文字を左揃え
                                        children: shikibetsuToDisplay.characters.map((char) {
                                          return Text(
                                            char,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 28, // 大きめのフォント
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  )
                                      : const SizedBox.shrink(), // 式別がない場合は空のウィジェットを返す
                                  const SizedBox(height: 8), // スペース

                                  // コンテナ6: 式別の英語名を表示（未実装）
                                  // 仮のテキストを配置
                                  Container(
                                    // width: 100,
                                    // height: 39,
                                    padding: const EdgeInsets.all(4.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue), // 仮のボーダー
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: const Text(
                                      'BET TYPE (Bottom)', // 仮の英語名
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16), // 式別と方式/購入内容の間のスペース

                            // コンテナ3: 右側の方式と購入内容の親コンテナ
                            Expanded(
                              flex: 85, // 幅の比率
                              child: Column( // コンテナ7, 8を縦に並べる
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // コンテナ7: 方式を表示
                                  // 現在のリザルトページの方式表示部分をここに配置
                                  if (hoshikiToDisplay.isNotEmpty)
                                    Text(
                                      hoshikiToDisplay,
                                      style: const TextStyle(
                                        color: Colors.black54, // 少し薄い色
                                        fontSize: 20, // 少し小さめのフォント
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 8), // 方式と購入内容の間にスペース

                                  // コンテナ8: 購入内容を表示
                                  // 現在のリザルトページのPurchaseDetailsCardをここに配置
                                  PurchaseDetailsCard(
                                    parsedResult: _parsedResult!,
                                    betType: _parsedResult!['式別'] ?? '',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // 発売所情報 (既存の配置を維持)
                        if (salesLocation != null && salesLocation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    salesLocation,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // 画面下部のボタン (既存の配置を維持)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => QRScannerPage(
                              scanMethod: 'camera',
                              savedListKey: widget.savedListKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('続けてカメラで登録'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => GalleryQrScannerPage(
                              scanMethod: 'gallery',
                              savedListKey: widget.savedListKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ギャラリーから登録'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ホームに戻る'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
