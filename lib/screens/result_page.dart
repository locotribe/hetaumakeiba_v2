// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

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

  String _getHorseNumberSymbol(String shikibetsu, String betType, {String? uraStatus}) {
    if (uraStatus == 'あり') {
      return '◀ ▶';
    }

    if (betType == '通常') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') {
        return '▶';
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
        String uraDisplay = (detail['ウラ'] == 'あり') ? 'ウラ: あり' : '';

        int combinations = 0;
        if (betType == 'クイックピック') {
          combinations = _parsedResult!['組合せ数'] as int? ?? 0;
        } else {
          combinations = detail['組合せ数'] as int? ?? 0;
        }

        print('DEBUG_RESULT_PAGE: combinations for $shikibetsu (overall betType: $betType): $combinations');

        bool isComplexCombinationForPrefix =
            (shikibetsu == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
                detail.containsKey('ながし') ||
                (betType == 'ボックス');

        String prefixForAmount = '';
        if (kingaku != null) {
          if (isComplexCombinationForPrefix) {
            prefixForAmount = '　各組${_getStars(kingaku)}';
          } else {
            prefixForAmount = '${_getStars(kingaku)}';
          }
        }

        List<Widget> detailWidgets = [];

        String combinationDisplay = '$combinations'; // デフォルトは計算された合計数

        // 三連単軸1頭or2頭ながしマルチの表示修飾
        // parse.dartで追加した "表示用相手頭数" と "表示用乗数" があるかを確認
        if (detail.containsKey('表示用相手頭数') && detail.containsKey('表示用乗数')) {
          final int opponentCountForDisplay = detail['表示用相手頭数'] as int;
          final int multiplierForDisplay = detail['表示用乗数'] as int;
          combinationDisplay = '${opponentCountForDisplay}×$multiplierForDisplay';
        }


        bool amountHandledInline = false;

        if (shikibetsu == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
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
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, betType, uraStatus: detail['ウラ']);

          if (!isComplexCombinationForPrefix) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Wrap(
                          spacing: 4.0,
                          runSpacing: 4.0,
                          children: [
                            ..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: currentSymbol),
                          ],
                        ),
                        if (kingaku != null)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$prefixForAmount$kingakuDisplay',
                                style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
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
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '組合せ数 $combinationDisplay',
                      style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold,),
                    ),
                  ),
                ),
              ],
            ),
          ));

          detailWidgets.add(const SizedBox(height: 8.0));
          print('DEBUG_RESULT_PAGE: Added combination count widget for $shikibetsu (betType: $betType). Current detailWidgets length: ${detailWidgets.length}');


          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    // マルチの場合に「マルチ」をContainerで表示し、各組と金額を並べる
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Rowの幅を内容に合わせる
                      children: [
                        if (detail.containsKey('マルチ') && detail['マルチ'] == 'あり')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.all(Radius.circular(0)),
                            ),
                            child: const Text('マルチ', style: TextStyle(color: Colors.white, fontSize: 22, height: 1)),
                          ),
                        Text('$prefixForAmount$kingakuDisplay', style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                            String overallMethod = _parsedResult!['式別'] ?? '';
                            String displayString = '';
                            String primaryShikibetsu = '';
                            if (_parsedResult!.containsKey('購入内容')) {
                              final List<Map<String, dynamic>> purchaseDetails =
                              (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
                              if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
                                primaryShikibetsu = purchaseDetails[0]['式別'];
                              }
                            }

                            if (overallMethod == '通常') {
                              if (primaryShikibetsu.isNotEmpty) {
                                displayString = '$primaryShikibetsu $overallMethod';
                              } else {
                                displayString = overallMethod;
                              }
                            } else if (overallMethod == '応援馬券') {
                              displayString = '応援馬券 単勝+複勝';
                            } else {
                              if (primaryShikibetsu.isNotEmpty) {
                                displayString = '$primaryShikibetsu $overallMethod';
                                if (overallMethod == 'ながし' && _parsedResult!.containsKey('購入内容') && (_parsedResult!['購入内容'] as List).isNotEmpty && (_parsedResult!['購入内容'] as List)[0].containsKey('ながし')) {
                                  final List<Map<String, dynamic>> purchaseDetails =
                                  (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
                                  displayString = '$primaryShikibetsu ${purchaseDetails[0]['ながし']}';
                                }
                              } else {
                                displayString = overallMethod;
                              }
                            }


                            return Text(
                              displayString,
                              style: TextStyle(color: Colors.black, fontSize: 28),
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
                                  children: _buildPurchaseDetails(_parsedResult!['購入内容'], _parsedResult!['式別'] ?? ''),
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
                                  '合計',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '$totalAmount円',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
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