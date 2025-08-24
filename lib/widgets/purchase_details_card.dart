// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart'; // 組合せ計算ロジックなどをインポート

// NOTE: クラス外に移動したヘルパー関数
// 金額に応じて'☆'マークを生成する
String _getStars(int amount) {
  String amountStr = amount.toString();
  int numDigits = amountStr.length;
  if (numDigits >= 6) return '';
  if (numDigits == 5) return '☆';
  if (numDigits == 4) return '☆☆';
  if (numDigits == 3) return '☆☆☆';
  return '';
}

// 合計金額に応じて'★'マークを生成する
String _getTotalAmountStars(int amount) {
  String amountStr = amount.toString();
  int numDigits = amountStr.length;
  if (numDigits >= 7) return '';
  if (numDigits == 6) return '★';
  if (numDigits == 5) return '★★';
  if (numDigits == 4) return '★★★';
  if (numDigits == 3) return '★★★★';
  return '';
}


// 購入詳細情報（買い目のみ）を表示するためのStatelessWidget
class PurchaseDetailsCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;

  const PurchaseDetailsCard({
    Key? key,
    required this.parsedResult,
    required this.betType,
  }) : super(key: key);

  // 式別と購入方法に応じて、馬番間の記号を返す
  String _getHorseNumberSymbol(String shikibetsu, String betType, {String? uraStatus}) {
    if (uraStatus == 'あり') return '◀ ▶';
    if (betType == '通常') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') return '▶';
      if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') return '-';
      if (shikibetsu == 'ワイド') return '◆';
    }
    return '';
  }

  // 馬番リストから、枠付きの馬番表示ウィジェットのリストを生成する
  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = '', double? fontSize}) {
    List<Widget> widgets = [];
    final double dynamicWidth = (fontSize ?? 16.0) * 1.8;
    List<int> numbersToProcess = [];

    if (horseNumbers is List) {
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
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Text(
              numbersToProcess[i].toString(),
              style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
      if (symbol.isNotEmpty && i < numbersToProcess.length - 1) {
        widgets.add(Text(symbol, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
      }
    }
    return widgets;
  }

  // 馬番の数に応じてフォントサイズを調整する
  double _getFontSizeByHorseCount(int count) {
    if (count == 1) return 18.0;
    if (count >= 2 && count <= 6) return 14.0;
    return 8.0;
  }

  // フォーメーション表示用に、馬番を2列のグリッド形式で表示する
  Widget _buildHorseNumberGrid(List<int> horseNumbers, double fontSize) {
    List<Widget> gridRows = [];
    for (int i = 0; i < horseNumbers.length; i += 2) {
      List<Widget> rowChildren = [];
      rowChildren.add(_buildHorseNumberDisplay(horseNumbers[i], fontSize: fontSize).first);
      if (i + 1 < horseNumbers.length) {
        rowChildren.add(const SizedBox(width: 4.0));
        rowChildren.add(_buildHorseNumberDisplay(horseNumbers[i + 1], fontSize: fontSize).first);
      }
      gridRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: rowChildren),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: gridRows);
  }

  // 「軸」や「1着」などのラベルと馬番のグループを表示する
  Widget _buildGroupLayoutItem(Map<String, dynamic> group, {required bool isFormation}) {
    final String label = group['label'] as String? ?? '';
    final List<int> horseNumbers = group['horseNumbers'] as List<int>? ?? [];
    final double fontSize = _getFontSizeByHorseCount(horseNumbers.length);

    return Column(
      children: [
        if (label.isNotEmpty) Text(label, style: TextStyle(color: Colors.black54)),
        if (label.isNotEmpty) const SizedBox(height: 4),
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

  // 複数の馬番グループを水平に並べて表示する
  Widget _buildHorizontalGroupLayout(List<Map<String, dynamic>> groups, {required bool isFormation}) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) {
        return Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildGroupLayoutItem(group, isFormation: isFormation),
          ),
        );
      }).toList(),
    );
  }

  // 購入内容のデータ構造を解析し、表示用のウィジェットリストを生成する
  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    return purchaseDetails.map((detail) {
      final String shikibetsuId = detail['式別'] ?? '';
      final String shikibetsu = bettingDict[shikibetsuId] ?? '';
      Widget content;

      // ながし
      if (currentBetType == 'ながし') {
        final List<Map<String, dynamic>> groupsData = [];
        if (shikibetsu == '3連単') {
          final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final labels = ['1着', '2着', '3着'];
          for (int i = 0; i < horseGroups.length; i++) {
            if (horseGroups[i].isNotEmpty) {
              groupsData.add({'label': labels[i], 'horseNumbers': horseGroups[i]});
            }
          }
        } else {
          if (detail.containsKey('軸')) groupsData.add({'label': '軸', 'horseNumbers': (detail['軸'] as List).cast<int>()});
          if (detail.containsKey('相手')) groupsData.add({'label': '相手', 'horseNumbers': (detail['相手'] as List).cast<int>()});
        }
        content = _buildHorizontalGroupLayout(groupsData, isFormation: false);
      }
      // フォーメーション
      else if (currentBetType == 'フォーメーション') {
        final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
        final List<Map<String, dynamic>> groupsData = [];
        if (shikibetsu == '3連単') {
          groupsData.addAll([
            {'label': '1着', 'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
            {'label': '2着', 'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
            {'label': '3着', 'horseNumbers': horseGroups.length > 2 ? horseGroups[2] : <int>[]},
          ]);
        } else if (shikibetsu == '3連複') {
          for (int i = 0; i < horseGroups.length; i++) {
            groupsData.add({'label': '${i + 1}頭目', 'horseNumbers': horseGroups[i]});
          }
        } else if (shikibetsu == '馬単') {
          groupsData.addAll([
            {'label': '1着', 'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
            {'label': '2着', 'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
          ]);
        }
        content = _buildHorizontalGroupLayout(groupsData, isFormation: true);
      }
      // 通常、ボックス、応援馬券など
      else {
        String currentSymbol = _getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);
        content = Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children: [..._buildHorseNumberDisplay(detail['馬番'], symbol: currentSymbol)],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (detail['ウラ'] == 'あり')
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text('ウラ: あり', style: TextStyle(color: Colors.black54)),
            ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildPurchaseDetailsInternal(parsedResult['購入内容'], betType),
      ),
    );
  }
}

/// 組合せ数と各組の金額を表示するためのウィジェット
class PurchaseCombinationsCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;

  const PurchaseCombinationsCard({
    Key? key,
    required this.parsedResult,
    required this.betType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }
    List<Map<String, dynamic>> purchaseDetails = (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
    if (purchaseDetails.isEmpty) {
      return const SizedBox.shrink();
    }
    final detail = purchaseDetails.first;

    final int? kingaku = detail['購入金額'];
    final int combinations = detail['組合せ数'] as int? ?? 0;
    final bool isComplexCombinationForPrefix = (betType == 'ボックス' || betType == 'ながし' || betType == 'フォーメーション');

    final TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    final TextStyle amountStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);

    String combinationDisplayString = detail['組合せ数_表示用'] as String? ?? '';
    if (combinationDisplayString.isEmpty && combinations > 0) {
      combinationDisplayString = '$combinations';
    }

    List<Widget> widgets = [];

    if (combinationDisplayString.isNotEmpty) {
      widgets.add(
        Text(
          '組合せ数 $combinationDisplayString',
          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (kingaku != null) {
      widgets.add(
        FittedBox(
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
              Text(_getStars(kingaku), style: starStyle),
              Text('${kingaku}円', style: amountStyle),
            ],
          ),
        ),
      );
    }

    if (betType == '応援馬券' && purchaseDetails.length >= 2) {
      int kingaku = detail['購入金額'] as int;
      String starsForAmount = _getStars(kingaku);
      String amountValue = kingaku.toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('各', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
          FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('単勝 ', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
          FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('複勝 ', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widgets,
    );
  }
}


/// 合計金額を表示するためのウィジェット
class PurchaseTotalAmountCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult;

  const PurchaseTotalAmountCard({
    Key? key,
    required this.parsedResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int totalAmount = parsedResult['合計金額'] as int? ?? 0;
    if (totalAmount == 0) {
      return const SizedBox.shrink();
    }

    String totalStars = _getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();

    final TextStyle totalStarStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    final TextStyle totalAmountTextStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('合計　', style: totalAmountTextStyle),
          Text(totalStars, style: totalStarStyle),
          Text('${totalAmountString}円', style: totalAmountTextStyle),
        ],
      ),
    );
  }
}
