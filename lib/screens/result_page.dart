// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';

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

    String? salesLocation;
    if (_parsedResult != null && _parsedResult!.containsKey('発売所')) {
      salesLocation = _parsedResult!['発売所'] as String;
    }

    String shikibetsuToDisplay = '';
    String hoshikiToDisplay = '';

    // ★★★ 修正箇所: キーを「式別」から「方式」へ変更 ★★★
    if (_parsedResult != null && _parsedResult!.containsKey('方式')) {
      String overallMethod = _parsedResult!['方式'] ?? '';
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
        // 「通常」の場合は、購入内容の式別をそのまま表示
        shikibetsuToDisplay = purchaseDetails.map((p) => p['式別']).toSet().join(',');
        hoshikiToDisplay = '';
      } else {
        shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : overallMethod;

        if (overallMethod == 'ながし' && primaryShikibetsuFromDetails.isNotEmpty && purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('ながし')) {
          hoshikiToDisplay = purchaseDetails[0]['ながし'];
        } else {
          // ながし以外の方式（ボックス、フォーメーション）は、その方式名を表示
          hoshikiToDisplay = overallMethod;
        }
      }
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
                                style: TextStyle(color: Colors.black, fontSize: 30),
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
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Text(
                                        '${_parsedResult!['レース']}',
                                        style: const TextStyle(color: Colors.white, fontSize: 32, height: 0.9),
                                      ),
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
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 250,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black, width: 2.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  IntrinsicHeight(
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.black,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                          child: Text(
                                            'Top',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      // ★★★ 修正箇所: キーを「式別」から「方式」へ変更 ★★★
                                      child: _parsedResult!.containsKey('方式')
                                          ? Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: shikibetsuToDisplay.characters.map((char) {
                                          return Text(
                                            char,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }).toList(),
                                      )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  IntrinsicHeight(
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.black,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                          child: Text(
                                            'Bottom',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )

                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              flex: 85,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hoshikiToDisplay.isNotEmpty)
                                    Text(
                                      hoshikiToDisplay,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  PurchaseDetailsCard(
                                    parsedResult: _parsedResult!,
                                    // ★★★ 修正箇所: キーを「式別」から「方式」へ変更 ★★★
                                    betType: _parsedResult!['方式'] ?? '',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

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