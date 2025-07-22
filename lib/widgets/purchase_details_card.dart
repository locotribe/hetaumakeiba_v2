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

  // ResultPageから_getStars, _getHorseNumberSymbol, _buildHorseNumberDisplayを移動
  String _getStars(int amount) { /* 既存のロジックをそのままコピー */
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

  String _getHorseNumberSymbol(String shikibetsu, String betType, {String? uraStatus}) { /* 既存のロジックをそのままコピー */
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

  // _buildHorseNumberDisplayの修正点: horseNumbersの型をdynamicに変更し、内部でList<int>とList<List<int>>の両方を処理できるようにする
  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = ''}) {
    List<Widget> widgets = [];
    const double fixedWidth = 30.0;

    List<int> numbersToProcess = [];

    // リストのリスト（一部の馬券タイプ、特に枠連などで発生する可能性のある構造）を平坦化する
    if (horseNumbers is List) {
      for (var item in horseNumbers) {
        if (item is int) {
          numbersToProcess.add(item);
        } else if (item is List) {
          // 内部のリストがintのリストであると仮定して追加
          numbersToProcess.addAll(item.cast<int>());
        }
        // 他の型の場合は無視するか、エラー処理を追加することができます
      }
    } else if (horseNumbers is int) {
      numbersToProcess.add(horseNumbers);
    }
    // else, 予期しない型の場合、これはそのままでは表示されないか、さらなるエラーを引き起こす可能性があります。

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
              // ここでnumbersToProcess[i]は常にint型であるはず
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

  // ResultPageの_buildPurchaseDetailsメソッドのロジックをここに移植
  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();
    const double labelWidth = 80.0;

    if (currentBetType == '応援馬券' && purchaseDetails.length >= 2) {
      final firstDetail = purchaseDetails[0];
      // horseNumbersの型はList<int>またはList<dynamic>が適切であり、_buildHorseNumberDisplayが処理するように変更された
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
        if (currentBetType == 'クイックピック') {
          combinations = parsedResult['組合せ数'] as int? ?? 0; // parsedResultを使用
        } else {
          combinations = detail['組合せ数'] as int? ?? 0;
        }

        print('DEBUG_RESULT_PAGE: combinations for $shikibetsu (overall betType: $currentBetType): $combinations');

        bool isComplexCombinationForPrefix =
            (shikibetsu == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
                detail.containsKey('ながし') ||
                (currentBetType == 'ボックス'); // betTypeを使用

        String prefixForAmount = '';
        if (kingaku != null) {
          if (isComplexCombinationForPrefix) {
            prefixForAmount = '　各組${_getStars(kingaku)}';
          } else {
            prefixForAmount = '${_getStars(kingaku)}';
          }
        }

        List<Widget> detailWidgets = [];

        String combinationDisplay = '$combinations';

        if (detail.containsKey('表示用相手頭数') && detail.containsKey('表示用乗数')) {
          final int opponentCountForDisplay = detail['表示用相手頭数'] as int;
          final int multiplierForDisplay = detail['表示用乗数'] as int;
          combinationDisplay = '${opponentCountForDisplay}×$multiplierForDisplay';
        }


        bool amountHandledInline = false; // Initialize here for each detail map

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
          // ながしの場合の軸と相手の表示
          if (detail.containsKey('軸')) {
            // 軸が単一の数値の場合とリストの場合に対応
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
          // 馬単ながしの場合にのみ組合せ数と購入金額を表示
          if (shikibetsu == '馬単' && kingaku != null) { // 馬単の流しのみに限定
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
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
            amountHandledInline = true; // 金額表示を処理済みとしてマーク
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
                            // _buildHorseNumberDisplayはdynamicな入力を処理するように変更されたため、ここでcast<int>()は安全
                            ..._buildHorseNumberDisplay(detail['馬番'], symbol: currentSymbol),
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
                      children: [..._buildHorseNumberDisplay(detail['馬番'], symbol: '')],
                    ),
                  ),
                ],
              ),
            ));
          }
        }

        // ながし以外のケース、かつ金額表示がまだされていない場合に、組合せ数と購入金額を表示
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
          print('DEBUG_RESULT_PAGE: Added combination count widget for $shikibetsu (betType: $currentBetType). Current detailWidgets length: ${detailWidgets.length}');


          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink(); // 購入内容がない場合は何も表示しない
    }

    return Column(
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
            children: _buildPurchaseDetailsInternal(parsedResult['購入内容'], betType),
          ),
        ),
      ],
    );
  }
}