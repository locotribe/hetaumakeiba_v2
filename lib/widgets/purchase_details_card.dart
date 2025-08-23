// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

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

  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = '', double? fontSize}) {
    List<Widget> widgets = [];
    final double dynamicWidth = (fontSize ?? 16.0) * 1.8;

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
            width: dynamicWidth,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Text(
              numbersToProcess[i].toString(),
              style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: FontWeight.bold),
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

  // ### 修正箇所: _combinations ヘルパー関数を削除 ###
  // この関数はパーサー側で処理が完結しているため不要

  double _getFontSizeByHorseCount(int count) {
    if (count == 1) {
      return 18.0;
    } else if (count >= 2 && count <= 6) {
      return 14.0;
    } else {
      return 8.0;
    }
  }

  // ▼▼▼ このメソッドが馬番を2列グリッドで表示します ▼▼▼
  Widget _buildHorseNumberGrid(List<int> horseNumbers, double fontSize) {
    List<Widget> gridRows = [];
    for (int i = 0; i < horseNumbers.length; i += 2) {
      List<Widget> rowChildren = [];

      // 1つ目の馬番ボックス
      rowChildren.add(
        _buildHorseNumberDisplay(horseNumbers[i], fontSize: fontSize).first,
      );

      // 2つ目の馬番ボックス（存在する場合）
      if (i + 1 < horseNumbers.length) {
        rowChildren.add(const SizedBox(width: 4.0)); // ボックス間のスペース
        rowChildren.add(
          _buildHorseNumberDisplay(horseNumbers[i + 1], fontSize: fontSize).first,
        );
      }

      gridRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: rowChildren,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // ← この行を追加
      children: gridRows,
    );
  }

  Widget _buildGroupLayoutItem(Map<String, dynamic> group, {required bool isFormation}) {
    final String label = group['label'] as String? ?? '';
    final List<int> horseNumbers = group['horseNumbers'] as List<int>? ?? [];
    final double fontSize = _getFontSizeByHorseCount(horseNumbers.length);

    return Column(
      children: [
        if (label.isNotEmpty)
          Text(label, style: TextStyle(color: Colors.black54)),
        if (label.isNotEmpty)
          const SizedBox(height: 4),
        isFormation
            ? _buildHorseNumberGrid(horseNumbers, fontSize)
            : Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children: _buildHorseNumberDisplay(horseNumbers, symbol: '', fontSize: fontSize),
        ),
      ],
    );
  }

  // ▼▼▼ 修正: isFormationフラグを受け取るように変更 ▼▼▼
  Widget _buildHorizontalGroupLayout(List<Map<String, dynamic>> groups, {required bool isFormation}) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.map((group) {
          return Flexible(
            child: Padding( // 各グループ間のスペースを確保
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildGroupLayoutItem(group, isFormation: isFormation),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ▼▼▼ このメソッドは不要になったため削除 ▼▼▼
  // Widget _buildWrappingFormationLayout(...) { ... }


  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();
    const double labelWidth = 80.0;

    final TextStyle starStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );

    final TextStyle amountStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14,
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
        final String shikibetsuId = detail['式別'] ?? '';
        final String shikibetsu = bettingDict[shikibetsuId] ?? '';
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

        // ▼▼▼ 修正箇所: isFormationフラグを渡すように変更 ▼▼▼
        if (shikibetsu == '3連単' && currentBetType == 'フォーメーション') {
          final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final List<Map<String, dynamic>> groupsData = [
            {'label': '1着', 'horseNumbers': horseGroups.length > 0 ? horseGroups[0] : <int>[]},
            {'label': '2着', 'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
            {'label': '3着', 'horseNumbers': horseGroups.length > 2 ? horseGroups[2] : <int>[]},
          ];
          detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: true));
        } else if (shikibetsu == '3連複' && currentBetType == 'フォーメーション') {
          final List<List<int>> horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final List<Map<String, dynamic>> groupsData = [];
          for (int i = 0; i < horseGroups.length; i++) {
            groupsData.add({'label': '${i + 1}頭目', 'horseNumbers': horseGroups[i]});
          }
          detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: true));
        } else if (shikibetsu == '馬単' && currentBetType == 'フォーメーション') {
          final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final List<Map<String, dynamic>> groupsData = [
            {'label': '1着', 'horseNumbers': horseGroups.length > 0 ? horseGroups[0] : <int>[]},
            {'label': '2着', 'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
          ];
          detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: true));
        } else if (currentBetType == 'ながし') {
          if (shikibetsu == '3連単') {
            final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            final List<Map<String, dynamic>> groupsData = [];
            final labels = ['1着', '2着', '3着'];
            for (int i = 0; i < horseGroups.length; i++) {
              if (horseGroups[i].isNotEmpty) {
                groupsData.add({'label': labels[i], 'horseNumbers': horseGroups[i]});
              }
            }
            detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: false));
          } else {
            final List<Map<String, dynamic>> groupsData = [];
            if (detail.containsKey('軸')) {
              groupsData.add({'label': '軸', 'horseNumbers': (detail['軸'] as List).cast<int>()});
            }
            if (detail.containsKey('相手')) {
              groupsData.add({'label': '相手', 'horseNumbers': (detail['相手'] as List).cast<int>()});
            }
            detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: false));
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
              padding: const EdgeInsets.only(left: 16.0, right: 0.0, top: 0.0, bottom: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '組合せ数 $combinationDisplayString',
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
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

    final int totalAmount = parsedResult['合計金額'] as int? ?? 0;

    String totalStars = _getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();

    final TextStyle totalStarStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );

    final TextStyle totalAmountTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Paddingを削除し、中のColumnを直接配置
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildPurchaseDetailsInternal(parsedResult['購入内容'], betType),
        ),
        // Paddingを削除し、中のRowを直接配置
        Row(
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
      ],
    );
  }
}