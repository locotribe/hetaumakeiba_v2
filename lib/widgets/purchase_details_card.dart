// lib/widgets/purchase_details_card.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart'; // 組合せ計算ロジックなどをインポート

// NOTE: クラス外に移動したヘルパー関数
String _getStars(int amount) {
  String amountStr = amount.toString();
  int numDigits = amountStr.length;
  if (numDigits >= 6) return '';
  if (numDigits == 5) return '☆';
  if (numDigits == 4) return '☆☆';
  if (numDigits == 3) return '☆☆☆';
  return '';
}

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

class PurchaseDetailsCard extends StatefulWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;

  const PurchaseDetailsCard({
    Key? key,
    required this.parsedResult,
    required this.betType,
  }) : super(key: key);

  @override
  State<PurchaseDetailsCard> createState() => _PurchaseDetailsCardState();
}

class _PurchaseDetailsCardState extends State<PurchaseDetailsCard> {
  final GlobalKey _paintAreaKey = GlobalKey();
  final List<GlobalKey> _axisKeys = [];
  final List<GlobalKey> _opponentRowKeys = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _getHorseNumberSymbol(String shikibetsu, String betType, {String? uraStatus}) {
    if (uraStatus == 'あり') return '◀ ▶';
    if (betType == '通常' || betType == 'フォーメーション' || betType == 'ながし') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') return '▶';
      if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') return '━';
      if (shikibetsu == 'ワイド') return '◆';
    }
    return '';
  }

  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = '', double? fontSize, Key? key}) {
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
            key: key,
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
        widgets.add(Text(symbol, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
      }
    }
    return widgets;
  }

  double _getFontSizeByHorseCount(int count) {
    if (count == 1) return 18.0;
    if (count >= 2 && count <= 6) return 12.0;
    return 10.0;
  }

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

  Widget _buildGroupLayoutItem(Map<String, dynamic> group, {required bool isFormation}) {
    final String label = group['label'] as String? ?? '';
    final List<int> horseNumbers = group['horseNumbers'] as List<int>? ?? [];
    final double fontSize = _getFontSizeByHorseCount(horseNumbers.length);

    final Widget horseDisplayWidget = isFormation
        ? _buildHorseNumberGrid(horseNumbers, fontSize)
        : Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      children: _buildHorseNumberDisplay(horseNumbers, symbol: '', fontSize: fontSize),
    );

    if (label.isNotEmpty) {
      return Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          horseDisplayWidget,
        ],
      );
    }
    return horseDisplayWidget;
  }

  Widget _buildHorizontalGroupLayout(
      List<Map<String, dynamic>> groups, {
        required bool isFormation,
        required String shikibetsu,
        required String betType,
      }) {
    if (groups.isEmpty) return const SizedBox.shrink();

    List<Widget> children = [];
    final bool shouldShowSymbol = isFormation || (betType == 'ながし' && shikibetsu == '3連単');
    final String symbol = _getHorseNumberSymbol(shikibetsu, betType);

    for (int i = 0; i < groups.length; i++) {
      children.add(Flexible(child: _buildGroupLayoutItem(groups[i], isFormation: isFormation)));
      if (shouldShowSymbol && symbol.isNotEmpty && i < groups.length - 1) {
        children.add(
          Transform.scale(
            scaleX: 0.5,
            scaleY: 1.5,
            child: Text(symbol, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }
    final bool isCenterAligned = isFormation || (betType == 'ながし' && shikibetsu == '3連単');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isCenterAligned ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: children,
    );
  }

  // ★★★ START: REVISED CONNECTOR LAYOUT METHODS ★★★

  /// 罫線付きのながしレイアウトを生成する
  Widget _buildNagashiWithConnector({required List<int> axisHorses, required List<int> opponentHorses}) {
    _axisKeys.clear();
    _opponentRowKeys.clear();

    // 軸馬ウィジェットリストを生成
    final double axisFontSize = _getFontSizeByHorseCount(1);
    final List<Widget> axisWidgets = axisHorses.map((horse) {
      final key = GlobalKey();
      _axisKeys.add(key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: _buildHorseNumberDisplay(horse, fontSize: axisFontSize, key: key).first,
      );
    }).toList();

    // ★修正点: 相手馬を常に4x5のグリッドで生成し、足りない分は '☆' で埋める
    const int numOpponentRows = 4;
    const int numOpponentCols = 5;
    const int totalCells = numOpponentRows * numOpponentCols;
    final double opponentFontSize = _getFontSizeByHorseCount(opponentHorses.length > 5 ? 10 : 5);

    List<dynamic> opponentItems = List.from(opponentHorses);
    while (opponentItems.length < totalCells) {
      opponentItems.add('☆');
    }

    List<Widget> opponentRowWidgets = [];
    for (int i = 0; i < numOpponentRows; i++) {
      final key = GlobalKey();
      _opponentRowKeys.add(key);
      List<Widget> rowChildren = [];
      for (int j = 0; j < numOpponentCols; j++) {
        final item = opponentItems[i * numOpponentCols + j];
        if (item is int) {
          rowChildren.add(_buildHorseNumberDisplay(item, fontSize: opponentFontSize).first);
        } else {
          final double dynamicWidth = (opponentFontSize * 1.8) + 4.0; // 番号の横幅と合わせる
          rowChildren.add(
            SizedBox(
              width: dynamicWidth,
              height: 30, // 番号の高さと概ね合わせる
              child: Center(
                child: Text('☆', style: TextStyle(fontSize: opponentFontSize * 1.5, color: Colors.black45)),
              ),
            ),
          );
        }
      }
      opponentRowWidgets.add(
        Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Wrap(spacing: 4.0, children: rowChildren),
        ),
      );
    }

    final Widget axisColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('(軸)', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Column(children: axisWidgets),
      ],
    );
    final Widget opponentColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('(相手)', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: opponentRowWidgets),
      ],
    );

    return Stack(
      key: _paintAreaKey,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            axisColumn,
            const SizedBox(width: 24), // 罫線を描画するスペース
            Flexible(child: opponentColumn),
          ],
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConnectorPainter(
              canvasKey: _paintAreaKey,
              axisKeys: _axisKeys,
              opponentRowKeys: _opponentRowKeys,
            ),
          ),
        ),
      ],
    );
  }

  // ★★★ END: REVISED CONNECTOR LAYOUT METHODS ★★★

  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    return purchaseDetails.map((detail) {
      final String shikibetsuId = detail['式別'] ?? '';
      final String shikibetsu = bettingDict[shikibetsuId] ?? '';
      Widget content;

      if (currentBetType == 'ながし') {
        if (shikibetsu != '馬単' && shikibetsu != '3連単') {
          final List<int> axisHorses = detail.containsKey('軸') ? (detail['軸'] as List).cast<int>() : [];
          final List<int> opponentHorses = detail.containsKey('相手') ? (detail['相手'] as List).cast<int>() : [];
          content = _buildNagashiWithConnector(axisHorses: axisHorses, opponentHorses: opponentHorses);
        } else {
          final List<Map<String, dynamic>> groupsData = [];
          if (shikibetsu == '3連単') {
            final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            final int axisGroupCount = horseGroups.where((group) => group.length == 1).length;
            final bool isJikuNagashi = axisGroupCount == 1 || axisGroupCount == 2;
            for (final currentGroup in horseGroups) {
              if (currentGroup.isNotEmpty) {
                final bool isAxisGroup = isJikuNagashi && currentGroup.length == 1;
                groupsData.add({'label': isAxisGroup ? '(軸)' : '', 'horseNumbers': currentGroup});
              }
            }
          } else {
            if (detail.containsKey('軸')) groupsData.add({'label': '(軸)', 'horseNumbers': (detail['軸'] as List).cast<int>()});
            if (detail.containsKey('相手')) groupsData.add({'label': '(相手)', 'horseNumbers': (detail['相手'] as List).cast<int>()});
          }
          content = _buildHorizontalGroupLayout(
            groupsData,
            isFormation: false,
            shikibetsu: shikibetsu,
            betType: currentBetType,
          );
        }
      } else if (currentBetType == 'フォーメーション') {
        final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
        final List<Map<String, dynamic>> groupsData = [];
        if (shikibetsu == '3連単') {
          groupsData.addAll([
            {'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
            {'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
            {'horseNumbers': horseGroups.length > 2 ? horseGroups[2] : <int>[]},
          ]);
        } else if (shikibetsu == '3連複') {
          for (var group in horseGroups) {
            groupsData.add({'horseNumbers': group});
          }
        } else if (shikibetsu == '馬単') {
          groupsData.addAll([
            {'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
            {'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
          ]);
        }
        content = _buildHorizontalGroupLayout(
          groupsData,
          isFormation: true,
          shikibetsu: shikibetsu,
          betType: currentBetType,
        );
      } else {
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
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Text('ウラ: あり', style: TextStyle(color: Colors.black54)),
            ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildPurchaseDetailsInternal(widget.parsedResult['購入内容'], widget.betType),
      ),
    );
  }
}

// ★★★ START: REVISED PAINTER CLASS ★★★
class _ConnectorPainter extends CustomPainter {
  final GlobalKey canvasKey;
  final List<GlobalKey> axisKeys;
  final List<GlobalKey> opponentRowKeys;
  final Paint linePaint;

  _ConnectorPainter({
    required this.canvasKey,
    required this.axisKeys,
    required this.opponentRowKeys,
  }) : linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 3.5 // 太さを調整
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round // 線の端を丸くする
    ..strokeJoin = StrokeJoin.round; // 線の接合部を丸くする

  @override
  void paint(Canvas canvas, Size size) {
    final canvasBox = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;

    final axisBoxes = axisKeys.map((key) => key.currentContext?.findRenderObject() as RenderBox?).toList();
    final opponentRowBoxes = opponentRowKeys.map((key) => key.currentContext?.findRenderObject() as RenderBox?).toList();

    if (axisBoxes.isEmpty || opponentRowBoxes.isEmpty || axisBoxes.contains(null) || opponentRowBoxes.contains(null)) {
      return;
    }

    final axisPoints = axisBoxes
        .map((box) {
      final position = box!.localToGlobal(Offset.zero);
      final localPosition = canvasBox.globalToLocal(position);
      return Offset(localPosition.dx + box.size.width, localPosition.dy + box.size.height / 2);
    })
        .where((p) => p.isFinite)
        .toList();

    final opponentPoints = opponentRowBoxes
        .map((box) {
      final position = box!.localToGlobal(Offset.zero);
      final localPosition = canvasBox.globalToLocal(position);
      return Offset(localPosition.dx, localPosition.dy + box.size.height / 2);
    })
        .where((p) => p.isFinite)
        .toList();

    if (axisPoints.isEmpty || opponentPoints.isEmpty) return;

    final path = Path();
    final double spineX = axisPoints.first.dx + 12; // 縦線のX座標

    // 縦線（背骨）のY座標の範囲を決定
    final double spineTopY = axisPoints.first.dy;
    final double spineBottomY = opponentPoints.last.dy;

    // 縦線（背骨）を描画
    path.moveTo(spineX, spineTopY);
    path.lineTo(spineX, spineBottomY);

    // 各軸馬から背骨への水平線を描画
    for (final point in axisPoints) {
      path.moveTo(point.dx, point.dy);
      path.lineTo(spineX, point.dy);
    }

    // 背骨から各相手馬の行への水平線を描画
    for (final point in opponentPoints) {
      path.moveTo(spineX, point.dy);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => true;
}

// ★★★ END: REVISED PAINTER CLASS ★★★

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

    final TextStyle starStyle = const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    final TextStyle amountStyle = const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);

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

    final TextStyle totalStarStyle = const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    final TextStyle totalAmountTextStyle = const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);

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