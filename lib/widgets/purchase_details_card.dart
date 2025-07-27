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
    if (numDigits >= 7) {
      return '';
    } else if (numDigits == 6) {
      return '★';
    } else if (numDigits == 5) {
      return '★★';
    } else if (numDigits == 4) {
      return '★★★';
    } else if (numDigits == 3) {
      return '★★★★';
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

  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = ''}) {
    List<Widget> widgets = [];
    const double fixedWidth = 30.0;

    List<int> numbersToProcess = [];

    if (horseNumbers is List) {
      // この関数は常にフラットなリストを受け取る想定
      numbersToProcess.addAll(horseNumbers.cast<int>());
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
              border: Border.all(color: Colors.black54),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              numbersToProcess[i].toString(),
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
      if (symbol.isNotEmpty && i < numbersToProcess.length - 1) {
        widgets.add(
          Text(symbol, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
        );
      }
    }
    return widgets;
  }

  // ### 修正箇所: _combinations ヘルパー関数を削除 ###
  // この関数はパーサー側で処理が完結しているため不要

  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();
    const double labelWidth = 80.0;

    final TextStyle starStyle = TextStyle(
      color: Colors.black54,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    final TextStyle amountStyle = TextStyle(
      color: Colors.black54,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    );

    if (currentBetType == '応援馬券' && purchaseDetails.length >= 2) {
      // (応援馬券のロジックは変更なし)
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
              child: Text('馬番', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end,),
            ),
            Expanded(
              child: Wrap(children: [..._buildHorseNumberDisplay(umanbanList, symbol: '')],),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('各', style: amountStyle,),
                Text(starsForAmount, style: starStyle,),
                Text('${amountValue}円', style: amountStyle,),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('単勝 ', style: amountStyle,),
                Text(starsForAmount, style: starStyle,),
                Text('${amountValue}円', style: amountStyle,),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('複勝 ', style: amountStyle,),
                Text(starsForAmount, style: starStyle,),
                Text('${amountValue}円', style: amountStyle,),
              ],
            ),
          ),
        ),
      ];
    } else {
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        int? kingaku = detail['購入金額'];
        String uraDisplay = (detail['ウラ'] == 'あり') ? 'ウラ: あり' : '';
        int combinations = detail['組合せ数'] as int? ?? 0;

        bool isComplexCombinationForPrefix = (currentBetType == 'ボックス' || currentBetType == 'ながし' || currentBetType == 'フォーメーション');

        String starsForPrefix = '';
        String amountValueForPrefix = '';
        if (kingaku != null) {
          starsForPrefix = _getStars(kingaku);
          amountValueForPrefix = kingaku.toString();
        }

        List<Widget> detailWidgets = [];
        bool amountHandledInline = false;

        // 馬番表示を先に処理
        if (shikibetsu == '3連単' && currentBetType == 'フォーメーション') {
          final List<List<int>> horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          if (horseGroups.length >= 1) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('1着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[0], symbol: '')])),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 2) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('2着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[1], symbol: '')])),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 3) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('3着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[2], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (shikibetsu == '3連複' && currentBetType == 'フォーメーション') {
          final List<List<int>> horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          for (int i = 0; i < horseGroups.length; i++) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('${i + 1}頭目', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[i], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (shikibetsu == '馬単' && currentBetType == 'フォーメーション') {
          final List<List<int>> horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          if (horseGroups.isNotEmpty) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('1着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[0], symbol: '')])),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 2) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('2着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[1], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (currentBetType == 'ながし') {
          if (shikibetsu == '3連単') {
            final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            final labels = ['1着', '2着', '3着'];
            for (int i = 0; i < horseGroups.length; i++) {
              if (horseGroups[i].isNotEmpty) {
                detailWidgets.add(Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: labelWidth, child: Text(labels[i], style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                      Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(horseGroups[i], symbol: '')])),
                    ],
                  ),
                ));
              }
            }
          } else {
            if (detail.containsKey('軸')) {
              detailWidgets.add(Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: labelWidth, child: Text('軸', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                    Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(detail['軸'], symbol: '')])),
                  ],
                ),
              ));
            }
            if (detail.containsKey('相手')) {
              detailWidgets.add(Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: labelWidth, child: Text('相手', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                    Expanded(child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [..._buildHorseNumberDisplay(detail['相手'], symbol: '')])),
                  ],
                ),
              ));
            }
          }
        } else {
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4.0, runSpacing: 4.0,
                    children: [..._buildHorseNumberDisplay(detail['馬番'], symbol: currentSymbol)],
                  ),
                ),
              ],
            ),
          ));
        }

        // ### 修正箇所: 統一的な組合せ数表示ロジック ###
        // パーサーが生成した表示用の文字列を優先して使用するように変更
        String combinationDisplayString = detail['組合せ数_表示用'] as String? ?? '';
        if (combinationDisplayString.isEmpty && combinations > 1) {
          combinationDisplayString = '$combinations';
        }

        if (combinationDisplayString.isNotEmpty) {
          detailWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 0.0, top: 8.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '組合せ数 $combinationDisplayString',
                    style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        // 共通の金額表示ロジック
        if (kingaku != null && !amountHandledInline) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (detail['マルチ'] == 'あり')
                            Container(
                              margin: const EdgeInsets.only(right: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                              decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(0))),
                              child: const Text('マルチ', style: TextStyle(color: Colors.white, fontSize: 22, height: 1)),
                            ),
                          Text(isComplexCombinationForPrefix ? '各組' : '', style: amountStyle),
                          Text(starsForPrefix, style: starStyle),
                          Text('${amountValueForPrefix}円', style: amountStyle),
                        ],
                      ),
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
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }

    // ★★★ 修正: 計算ループを削除し、パーサーからの値を直接利用 ★★★
    final int totalAmount = parsedResult['合計金額'] as int? ?? 0;

    String totalStars = _getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();

    final TextStyle totalStarStyle = TextStyle(
      color: Colors.black54,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    final TextStyle totalAmountTextStyle = TextStyle(
      color: Colors.black54,
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('合計　', style: totalAmountTextStyle,),
                        Text(totalStars, style: totalStarStyle,),
                        Text('${totalAmountString}円', style: totalAmountTextStyle,),
                      ],
                    ),
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
