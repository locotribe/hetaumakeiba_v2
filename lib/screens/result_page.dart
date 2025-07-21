// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart'; // app_styles.dart をインポート

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
                        style: _parsedResult != null && _parsedResult!.containsKey('エラー')
                            ? AppStyles.errorMessageStyle
                            : AppStyles.normalMessageStyle,
                        textAlign: TextAlign.center,
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_parsedResult!.containsKey('年') && _parsedResult!.containsKey('回') && _parsedResult!.containsKey('日'))
                          Text(
                            '20${_parsedResult!['年']}年${_parsedResult!['回']}回${_parsedResult!['日']}日',
                            style: AppStyles.dateTextStyle,
                          ),
                        const SizedBox(height: 4),
                        if (_parsedResult!.containsKey('開催場') && _parsedResult!.containsKey('レース'))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_parsedResult!['開催場']}',
                                style: AppStyles.racecourseTextStyle,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 50.0,
                                    height: 30.0,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.all(Radius.circular(0)),
                                    ),
                                    child: Text(
                                      '${_parsedResult!['レース']}',
                                      style: AppStyles.raceNumberTextStyle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'レース',
                                    style: AppStyles.raceLabelTextStyle,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),

                        if (_parsedResult!.containsKey('式別'))
                          Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Builder(builder: (context) {
                                    String overallMethod = _parsedResult!['式別'] ?? '';
                                    String displayMethod = '';

                                    if (overallMethod == '通常') {
                                      displayMethod = '';
                                    } else if (overallMethod == '応援馬券') {
                                      displayMethod = '応援馬券';
                                    } else if (overallMethod == 'ながし' && _parsedResult!.containsKey('購入内容') && (_parsedResult!['購入内容'] as List).isNotEmpty && (_parsedResult!['購入内容'] as List)[0].containsKey('ながし')) {
                                      final List<Map<String, dynamic>> purchaseDetails =
                                      (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
                                      displayMethod = '${purchaseDetails[0]['ながし']}';
                                    } else {
                                      displayMethod = overallMethod;
                                    }

                                    if (displayMethod.isNotEmpty) {
                                      // ★ここを修正: Containerの幅と高さを固定し、FittedBoxでテキストを調整
                                      return Container(
                                        width: 200.0, // 固定幅
                                        height: 35.0, // 固定高さ
                                        alignment: Alignment.center, // テキストを中央寄せ
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        decoration: AppStyles.purchaseMethodBoxDecoration,
                                        child: FittedBox( // 追加: FittedBoxでテキストを自動調整
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center, // FittedBox内のテキストも中央寄せ
                                          child: Text(
                                            displayMethod,
                                            style: AppStyles.shikibetsuMethodTextStyle,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),

                        if (_parsedResult!.containsKey('購入内容'))
                          PurchaseDetailsCard(
                            parsedResult: _parsedResult!,
                            betType: _parsedResult!['式別'] ?? '',
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
                                  '合計',
                                  style: AppStyles.totalLabelStyle,
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '$totalAmount円',
                                    style: AppStyles.totalAmountStyle,
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
                                    style: AppStyles.salesLocationLabelStyle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    salesLocation,
                                    style: AppStyles.salesLocationTextStyle,
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