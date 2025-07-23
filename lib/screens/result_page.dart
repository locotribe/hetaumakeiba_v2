// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart'; // ★追加

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
          Column(
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
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 8),
                        if (_parsedResult!.containsKey('式別'))
                          Builder(builder: (context) {
                            String shikibetsuToDisplay = ''; // 例: 馬単, 応援馬券, ボックス
                            String hoshikiToDisplay = ''; // 例: マルチ, 単勝+複勝, 軸1頭

                            String overallMethod = _parsedResult!['式別'] ?? '';
                            String primaryShikibetsuFromDetails = '';

                            // purchaseDetailsをBuilderスコープ内で宣言し、初期化
                            List<Map<String, dynamic>> purchaseDetails = [];
                            if (_parsedResult!.containsKey('購入内容')) {
                              purchaseDetails = (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
                              if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
                                primaryShikibetsuFromDetails = purchaseDetails[0]['式別'];
                              }
                            }

                            if (overallMethod == '応援馬券') {
                              shikibetsuToDisplay = '応援馬券';
                              hoshikiToDisplay = '単勝+複勝';
                            } else if (overallMethod == '通常') {
                              shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : '通常';
                              hoshikiToDisplay = ''; // 「通常」の場合は方式を独立して表示しない
                            } else {
                              // ボックス, ながし, フォーメーション, クイックピック
                              shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : overallMethod;

                              // purchaseDetailsが有効な範囲内でアクセス
                              if (overallMethod == 'ながし' && primaryShikibetsuFromDetails.isNotEmpty && purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('ながし')) {
                                hoshikiToDisplay = purchaseDetails[0]['ながし']; // 例: 軸1頭, 軸2頭
                              } else if (primaryShikibetsuFromDetails.isNotEmpty) {
                                hoshikiToDisplay = overallMethod; // 例: ボックス, フォーメーション, クイックピック
                              } else {
                                // primaryShikibetsuFromDetailsがない場合は、方式も表示しない（overallMethodが式別として表示されるため）
                                hoshikiToDisplay = '';
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (shikibetsuToDisplay.isNotEmpty)
                                  Text(
                                    shikibetsuToDisplay,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 28, // 大きめのフォント
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (hoshikiToDisplay.isNotEmpty)
                                  Text(
                                    hoshikiToDisplay,
                                    style: const TextStyle(
                                      color: Colors.black54, // 少し薄い色
                                      fontSize: 20, // 少し小さめのフォント
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            );
                          }),
                        const SizedBox(height: 8),
                        if (_parsedResult!.containsKey('購入内容'))
                          PurchaseDetailsCard(
                            parsedResult: _parsedResult!,
                            betType: _parsedResult!['式別'] ?? '',
                          ),
                        const SizedBox(height: 8),

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