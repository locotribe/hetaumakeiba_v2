// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';

class PurchaseDetailsCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult; // 全体の解析結果を渡す
  final String betType; // 式別 (通常、応援馬券など)

  const PurchaseDetailsCard({
    Key? key,
    required this.parsedResult,
    required this.betType,
  }) : super(key: key);

  // 既存の _getStars メソッド (☆を使用)
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

  // 合計金額表示用の _getTotalAmountStars メソッド (★を使用)
  String _getTotalAmountStars(int amount) {
    String amountStr = amount.toString();
    int numDigits = amountStr.length;
    // 7桁の場合は何も表示しない
    if (numDigits >= 7) {
      return '';
    } else if (numDigits == 6) {
      return '★'; // 6桁の場合、★を1つ表示
    } else if (numDigits == 5) {
      return '★★'; // 5桁の場合、★★を2つ表示
    } else if (numDigits == 4) {
      return '★★★'; // 4桁の場合、★★★を3つ表示
    } else if (numDigits == 3) {
      return '★★★★'; // 3桁の場合、★★★★を4つ表示
    }
    return ''; // それ以外の場合（2桁以下）は何も表示しない
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

  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = ''}) {
    List<Widget> widgets = [];
    const double fixedWidth = 30.0;

    List<int> numbersToProcess = [];

    if (horseNumbers is List) {
      for (var item in horseNumbers) {
        if (item is int) {
          numbersToProcess.add(item);
        } else if (item is List) {
          numbersToProcess.addAll(item.cast<int>());
        }
      }
    } else if (horseNumbers is int) {
      numbersToProcess.add(horseNumbers);
    }

    for (int i = 0; i < numbersToProcess.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Container(
            width: fixedWidth,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Text(
              numbersToProcess[i].toString(),
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      );
      if (symbol.isNotEmpty && i < numbersToProcess.length - 1) {
        widgets.add(
          Text(symbol, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();
    const double labelWidth = 80.0;

    // ☆の部分のスタイル定義（heightを削除し、必要に応じてTextウィジェットのCrossAxisAlignmentで調整）
    final TextStyle starStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 12,
      // height: 0.9, // Text.richでなくRowでAlignするためheightは削除
    );

    // 金額部分のスタイル定義
    final TextStyle amountStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    );

    if (currentBetType == '応援馬券' && purchaseDetails.length >= 2) {
      final firstDetail = purchaseDetails[0];
      List<int> umanbanList = (firstDetail['馬番'] as List).cast<int>();

      int kingaku = firstDetail['購入金額'] as int;
      String starsForAmount = _getStars(kingaku);
      String amountValue = kingaku.toString();

      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                '　',
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
        // 各組の金額表示（RowとCrossAxisAlignment.centerで垂直方向を中央揃え）
        Align(
          alignment: Alignment.center, // 水平方向も中央
          child: Row(
            mainAxisSize: MainAxisSize.min, // 内容に合わせて幅を最小限に
            crossAxisAlignment: CrossAxisAlignment.center, // 垂直方向の中央揃え
            children: [
              Text(
                '各',
                style: amountStyle,
              ),
              Text(
                starsForAmount,
                style: starStyle,
              ),
              Text(
                '${amountValue}円',
                style: amountStyle,
              ),
            ],
          ),
        ),
        // 単勝の金額表示（RowとCrossAxisAlignment.centerで垂直方向を中央揃え）
        Align(
          alignment: Alignment.center, // 水平方向も中央
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '単勝 ',
                style: amountStyle,
              ),
              Text(
                starsForAmount,
                style: starStyle,
              ),
              Text(
                '${amountValue}円',
                style: amountStyle,
              ),
            ],
          ),
        ),
        // 複勝の金額表示（RowとCrossAxisAlignment.centerで垂直方向を中央揃え）
        Align(
          alignment: Alignment.center, // 水平方向も中央
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '複勝 ',
                style: amountStyle,
              ),
              Text(
                starsForAmount,
                style: starStyle,
              ),
              Text(
                '${amountValue}円',
                style: amountStyle,
              ),
            ],
          ),
        ),
      ];
    } else {
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        int? kingaku = detail['購入金額'];
        String kingakuDisplay = kingaku != null ? '${kingaku}円' : '';
        String uraDisplay = (detail['ウラ'] == 'あり') ? 'ウラ: あり' : '';

        int combinations = 0;
        if (currentBetType == 'クイックピック') {
          combinations = parsedResult['組合せ数'] as int? ?? 0;
        } else {
          combinations = detail['組合せ数'] as int? ?? 0;
        }

        bool isComplexCombinationForPrefix =
            (shikibetsu == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
                detail.containsKey('ながし') ||
                (currentBetType == 'ボックス');

        String starsForPrefix = '';
        String amountValueForPrefix = '';

        if (kingaku != null) {
          starsForPrefix = _getStars(kingaku);
          amountValueForPrefix = kingaku.toString();
        }

        List<Widget> detailWidgets = [];

        String combinationDisplay = '$combinations';

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
            List<int> axisHorses;
            if (detail['軸'] is int) {
              axisHorses = [detail['軸'] as int];
            } else if (detail['軸'] is List) {
              axisHorses = (detail['軸'] as List).cast<int>();
            } else {
              axisHorses = [];
            }

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
          if (shikibetsu == '馬単' && kingaku != null) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '組合せ数 $combinationDisplay',
                        style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ));
            detailWidgets.add(const SizedBox(height: 8.0));

            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight, // 水平方向は右寄せ
                      child: Row( // RowとCrossAxisAlignment.centerで垂直方向を中央揃え
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                          Text( // '各組'の部分
                            isComplexCombinationForPrefix ? '　各組' : '',
                            style: amountStyle,
                          ),
                          Text( // ☆の部分
                            starsForPrefix,
                            style: starStyle,
                          ),
                          Text( // 金額の部分
                            '${amountValueForPrefix}円',
                            style: amountStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ));
            amountHandledInline = true;
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List) {
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);

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
                            ..._buildHorseNumberDisplay(detail['馬番'], symbol: currentSymbol),
                          ],
                        ),
                        if (kingaku != null)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight, // 水平方向は右寄せ
                              child: Row( // RowとCrossAxisAlignment.centerで垂直方向を中央揃え
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text( // ☆の部分
                                    starsForPrefix,
                                    style: starStyle,
                                  ),
                                  Text( // 金額の部分
                                    '${amountValueForPrefix}円',
                                    style: amountStyle,
                                  ),
                                ],
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
                      style: TextStyle(color: Colors.black),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [..._buildHorseNumberDisplay(detail['馬番'], symbol: '')],
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

          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight, // 水平方向は右寄せ
                    child: Row( // RowとCrossAxisAlignment.centerで垂直方向を中央揃え
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                        Text( // '各組'の部分
                          isComplexCombinationForPrefix ? '　各組' : '',
                          style: amountStyle,
                        ),
                        Text( // ☆の部分
                          starsForPrefix,
                          style: starStyle,
                        ),
                        Text( // 金額の部分
                          '${amountValueForPrefix}円',
                          style: amountStyle,
                        ),
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
            child: Text(uraDisplay, style: TextStyle(color: Colors.black)),
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
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }

    int totalAmount = 0;
    if (parsedResult['購入内容'] is List) {
      for (var item in parsedResult['購入内容']) {
        if (item is Map<String, dynamic> && item.containsKey('購入金額') && item['購入金額'] is int) {
          totalAmount += item['購入金額'] as int;
        }
      }
    }

    String totalStars = _getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();

    // 合計金額の★の部分のスタイル（heightを削除）
    final TextStyle totalStarStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 12,
      // height: 0.9, // RowでAlignするためheightは削除
    );

    // 合計金額の通常テキストのスタイル
    final TextStyle totalAmountTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildPurchaseDetailsInternal(parsedResult['購入内容'], betType),
          ),
        ),
        // 合計金額の表示部分
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight, // 水平方向は右寄せを維持
                  child: Row( // Text.richの代わりにRowを使用
                    mainAxisSize: MainAxisSize.min, // 内容に合わせて幅を最小限に
                    crossAxisAlignment: CrossAxisAlignment.center, // 垂直方向の中央揃え
                    children: [
                      Text(
                        '合計　　',
                        style: totalAmountTextStyle,
                      ),
                      Text(
                        totalStars,
                        style: totalStarStyle,
                      ),
                      Text(
                        '${totalAmountString}円',
                        style: totalAmountTextStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}