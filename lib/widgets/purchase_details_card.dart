// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart'; // ★追加: app_styles.dart をインポート

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

  List<Widget> _buildHorseNumberDisplay(List<int> horseNumbers, {String symbol = ''}) { /* 既存のロジックをそのままコピー */
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
              border: Border.all(color: AppStyles.horseNumberBorderColor), // ★スタイル適用
              borderRadius: BorderRadius.circular(4.0),
              color: AppStyles.horseNumberBackgroundColor, // ★スタイル適用
            ),
            child: Text(
              horseNumbers[i].toString(),
              style: AppStyles.horseNumberTextStyle, // ★スタイル適用
            ),
          ),
        ),
      );
      if (symbol.isNotEmpty && i < horseNumbers.length - 1) {
        widgets.add(
          Text(symbol, style: AppStyles.horseNumberSymbolTextStyle), // ★スタイル適用
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
                style: AppStyles.totalLabelStyle, // ★スタイル適用 (既存のスタイルを流用)
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
          style: AppStyles.purchaseAmountTextStyle, // ★スタイル適用
        ),
        Text(
          '単勝 ${_getStars(kingaku)}${kingaku}円',
          style: AppStyles.purchaseAmountTextStyle, // ★スタイル適用
        ),
        Text(
          '複勝 ${_getStars(kingaku)}${kingaku}円',
          style: AppStyles.purchaseAmountTextStyle, // ★スタイル適用
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


        bool amountHandledInline = false;

        if (shikibetsu == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          final List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (horseGroups.length >= 1) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('1着', style: AppStyles.totalLabelStyle, textAlign: TextAlign.end)), // ★スタイル適用
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
                  SizedBox(width: labelWidth, child: Text('2着', style: AppStyles.totalLabelStyle, textAlign: TextAlign.end)), // ★スタイル適用
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
                  SizedBox(width: labelWidth, child: Text('3着', style: AppStyles.totalLabelStyle, textAlign: TextAlign.end)), // ★スタイル適用
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[2], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('ながし')) {
          if (detail.containsKey('軸')) {
            List<int> axisHorses = detail['軸'] is List ? (detail['軸'] as List<dynamic>).cast<int>() : [(detail['軸'] as int)];
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('軸', style: AppStyles.totalLabelStyle, textAlign: TextAlign.end)), // ★スタイル適用
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
                  SizedBox(width: labelWidth, child: Text('相手', style: AppStyles.totalLabelStyle, textAlign: TextAlign.end)), // ★スタイル適用
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay((detail['相手'] as List).cast<int>(), symbol: '')])),
                ],
              ),
            ));
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
                            ..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: currentSymbol),
                          ],
                        ),
                        if (kingaku != null)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$prefixForAmount$kingakuDisplay',
                                style: AppStyles.purchaseAmountTextStyle, // ★スタイル適用
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
                      style: AppStyles.totalLabelStyle, // ★スタイル適用
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
                      style: AppStyles.purchaseAmountTextStyle, // ★スタイル適用 (金額と同じスタイルを流用)
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
                            child: const Text('マルチ', style: AppStyles.multiTextStyle), // ★スタイル適用
                          ),
                        Text('$prefixForAmount$kingakuDisplay', style: AppStyles.purchaseAmountTextStyle), // ★スタイル適用
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
            child: Text(uraDisplay, style: AppStyles.uraDisplayTextStyle), // ★スタイル適用
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
        // ★ここを削除: Text('購入内容', ...) を削除
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