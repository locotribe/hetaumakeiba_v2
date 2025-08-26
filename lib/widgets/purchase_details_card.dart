// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

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

// グループ内の馬番の数に応じて、馬番を囲う枠のサイズを決定する関数
double _getBoxSizeByHorseCount(int count) {
  // 枠の大きさを指定する場所
  if (count == 1) {
    return 34.0;
  }
  if (count >= 2 && count <= 6) {
    return 24.0;
  }
  return 20.0;
}

class PurchaseDetailsCard extends StatefulWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;
  final RaceResult? raceResult;

  const PurchaseDetailsCard({
    super.key,
    required this.parsedResult,
    required this.betType,
    this.raceResult,
  });

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

  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = '', int? horseCountForSizing, Key? key}) {
    List<Widget> widgets = [];
    final int count = horseCountForSizing ?? (horseNumbers is List ? horseNumbers.length : 1);
    final double boxSize = _getBoxSizeByHorseCount(count);

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
            width: boxSize,
            height: boxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: FittedBox(
              fit: BoxFit.fill,
              child: Text(
                numbersToProcess[i].toString(),
                style: const TextStyle(
                  fontSize: 100,      // ① 非常に大きなフォントサイズを指定
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  height: 1.0,         // ② (推奨)行の高さを詰めて上下の余白を最小化
                ),
              ),
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

  Widget _buildHorseNumberGrid(List<int> horseNumbers) {
    List<Widget> gridRows = [];
    final int horseCount = horseNumbers.length;
    for (int i = 0; i < horseNumbers.length; i += 2) {
      List<Widget> rowChildren = [];
      rowChildren.add(_buildHorseNumberDisplay(horseNumbers[i], horseCountForSizing: horseCount).first);
      if (i + 1 < horseNumbers.length) {
        rowChildren.add(const SizedBox(width: 4.0));
        rowChildren.add(_buildHorseNumberDisplay(horseNumbers[i + 1], horseCountForSizing: horseCount).first);
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

    final Widget horseDisplayWidget = isFormation
        ? _buildHorseNumberGrid(horseNumbers)
        : Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      children: _buildHorseNumberDisplay(horseNumbers, symbol: '', horseCountForSizing: horseNumbers.length),
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
            child: Text(symbol, style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
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
  /// 罫線付きのながしレイアウトを生成する
  Widget _buildNagashiWithConnector({required List<int> axisHorses, required List<int> opponentHorses}) {
    _axisKeys.clear();
    _opponentRowKeys.clear();

    // 軸馬ウィジェットリストを生成
    final List<Widget> axisWidgets = axisHorses.map((horse) {
      final key = GlobalKey();
      _axisKeys.add(key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: _buildHorseNumberDisplay(horse, key: key, horseCountForSizing: 1).first,
      );
    }).toList();

    // ★修正点: 相手馬を常に4x5のグリッドで生成し、足りない分は '☆' で埋める
    const int numOpponentRows = 4;
    const int numOpponentCols = 5;
    const int totalCells = numOpponentRows * numOpponentCols;
    final int opponentCount = opponentHorses.length;
    // 枠の大きさを指定する場所
    final double boxSizeForOpponent = _getBoxSizeByHorseCount(opponentCount > 6 ? 7 : opponentCount);


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
          rowChildren.add(_buildHorseNumberDisplay(item, horseCountForSizing: opponentCount).first);
        } else {
          rowChildren.add(
            SizedBox(
              width: boxSizeForOpponent + 4.0,
              height: boxSizeForOpponent,
              child: Center(
                // この場所が何の場合の数字なのか: ながし投票の相手馬が20頭に満たない場合のプレースホルダー('☆')のフォントサイズ
                child: Text('☆', style: TextStyle(fontSize: boxSizeForOpponent * 0.5, color: Colors.black)),
              ),
            ),
          );
        }
      }
      opponentRowWidgets.add(
        Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 1.0),
          child: Wrap(spacing: 6.0, children: rowChildren),
        ),
      );
    }

    final Widget axisColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '(軸)',
          style: TextStyle(
            color: Colors.black,
            fontSize: 11, // この行を追加します
          ),
        ),
        const SizedBox(height: 4),
        Column(children: axisWidgets),
      ],
    );
    final Widget opponentColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '(相手)',
          style: TextStyle(
            color: Colors.black,
            fontSize: 10, // この行を追加します
          ),
        ),
        const SizedBox(height: 2),
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
            const SizedBox(width: 15), // 罫線を描画するスペース
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

  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    if (currentBetType == '応援馬券' && purchaseDetails.isNotEmpty) {
      final detail = purchaseDetails.first;
      final horseNumberData = detail['馬番'];
      final horseNumber = (horseNumberData is List ? horseNumberData[0] : horseNumberData) as int;
      final int? kingaku = detail['購入金額'];

      String horseNameToDisplay = 'キミノアイバ'; // デフォルト値
      if (widget.raceResult != null) {
        try {
          final horseNumberString = horseNumber.toString();
          final horseData = widget.raceResult!.horseResults.firstWhere(
                (h) => h.horseNumber.trim() == horseNumberString,
          );
          horseNameToDisplay = horseData.horseName;
        } catch (e) {
          // レース結果に馬が見つからない場合 (除外など) はデフォルト名のまま
        }
      }

      final Widget horseNumberWidget = _buildHorseNumberDisplay(horseNumber, horseCountForSizing: 1).first;

      const TextStyle amountStyle = TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 20,
        height: 1.0,);
      const TextStyle kiminoAibaStyle = TextStyle(
          color: Colors.black,
          fontWeight:
          FontWeight.bold,
          fontSize: 20);

      // 1行目: 馬番とテキスト
      final Widget firstLine = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          horseNumberWidget,
          Text(' $horseNameToDisplay', style: kiminoAibaStyle),
        ],
      );

      // 2行目: 金額
      Widget amountLine = const SizedBox.shrink();
      if (kingaku != null) {
        const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
        amountLine = Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('各', style: amountStyle),
            Text(_getStars(kingaku), style: starStyle),
            Text('$kingaku円', style: amountStyle),
          ],
        );
      }

      // IntrinsicWidthを削除し、Columnを直接返す
      return [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            firstLine,
            amountLine,
          ],
        )
      ];
    }

    return purchaseDetails.map((detail) {
      final String shikibetsuId = detail['式別'] ?? '';
      final String shikibetsu = bettingDict[shikibetsuId] ?? '';
      Widget content;

      if (currentBetType == 'ながし') {
        if (shikibetsu != '馬単' && shikibetsu != '3連単') {
          final axisData = detail['軸'];
          final opponentData = detail['相手'];
          final List<int> axisHorses = axisData is List ? axisData.cast<int>() : (axisData is int ? [axisData] : []);
          final List<int> opponentHorses = opponentData is List ? opponentData.cast<int>() : (opponentData is int ? [opponentData] : []);
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
        final dynamic horseNumbers = detail['馬番'];
        final int horseCount = horseNumbers is List ? horseNumbers.length : 1;
        final int? kingaku = detail['購入金額'];

        Widget horseDisplayWidget;

        final Widget horseNumbersDisplay = Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [..._buildHorseNumberDisplay(horseNumbers, symbol: currentSymbol, horseCountForSizing: horseCount)],
        );

        if ((shikibetsu == '単勝' || shikibetsu == '複勝') && widget.raceResult != null) {
          String? horseNameToDisplay;
          try {
            // 単勝・複勝の '馬番' は int
            final horseNumberInt = horseNumbers as int;
            final horseNumberString = horseNumberInt.toString();

            final horseData = widget.raceResult!.horseResults.firstWhere(
                  (h) => h.horseNumber.trim() == horseNumberString,
            );
            horseNameToDisplay = horseData.horseName;
          } catch (e) {
            // 馬が見つからない場合は null のまま
          }

          if (horseNameToDisplay != null) {
            horseDisplayWidget = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                horseNumbersDisplay,
                const SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    horseNameToDisplay,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          } else {
            horseDisplayWidget = horseNumbersDisplay; // 検索失敗時は馬番のみ
          }
        } else {
          horseDisplayWidget = horseNumbersDisplay; // その他の券種は馬番のみ
        }

        Widget amountDisplay = const SizedBox.shrink();
        if (kingaku != null && currentBetType == '通常') {
          const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
          const TextStyle amountStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0,);
          amountDisplay = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16.0),
              Text(_getStars(kingaku), style: starStyle),
              Text('$kingaku円', style: amountStyle),
            ],
          );
        }

        content = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            horseDisplayWidget, // ★★★ 馬名表示に対応したウィジェットを使用
            amountDisplay,
          ],
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            if (detail['ウラ'] == 'あり')
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('ウラ: あり', style: TextStyle(color: Colors.black54)),
              ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }

    // ★★★ 購入方式によってレイアウトを分岐 ★★★
    if (widget.betType == '応援馬券') {
      // 応援馬券の場合：中央揃え
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 垂直方向に中央揃え
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildPurchaseDetailsInternal(widget.parsedResult['購入内容'], widget.betType),
        ),
      );
    } else {
      // それ以外の場合：従来のFittedBoxで左上揃えにし、表示崩れを防ぐ
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildPurchaseDetailsInternal(widget.parsedResult['購入内容'], widget.betType),
          ),
        ),
      );
    }
  }
}

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
    ..strokeWidth = 3.0 // 太さを調整
    ..style = PaintingStyle.stroke;

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
    final double spineX = axisPoints.first.dx + 8; // 縦線のX座標
    final double verticalPadding = 1.5; // 上下に延長する長さ（お好みで調整してください）

    // 縦線（背骨）のY座標の範囲を、相手リストを基準に決定
    final double spineTopY = opponentPoints.first.dy;
    final double spineBottomY = opponentPoints.last.dy;

    // 1. 縦線（背骨）を、上下に少し延長して描画
    path.moveTo(spineX, spineTopY - verticalPadding);
    path.lineTo(spineX, spineBottomY + verticalPadding);

    // 2. 軸馬から背骨への水平線を描画
    // これが┏の左から伸びる横線になります
    if (axisPoints.isNotEmpty) {
      path.moveTo(axisPoints.first.dx, axisPoints.first.dy);
      path.lineTo(spineX, axisPoints.first.dy);
    }

    // 3. 背骨から各相手馬の行への水平線を描画
    // このループが┏の上辺、┗の下辺、および中間の横線を描画します
    for (final point in opponentPoints) {
      path.moveTo(spineX, point.dy);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => true;
}

class PurchaseCombinationsCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;

  const PurchaseCombinationsCard({
    super.key,
    required this.parsedResult,
    required this.betType,
  });

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

    const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    const TextStyle amountStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0,);

    String combinationDisplayString = detail['組合せ数_表示用'] as String? ?? '';
    if (combinationDisplayString.isEmpty && combinations > 0) {
      combinationDisplayString = '$combinations';
    }

    List<Widget> widgets = [];

    if (combinationDisplayString.isNotEmpty) {
      widgets.add(
        Text(
          '組合せ数 $combinationDisplayString',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.0, // または 0.9 など、適宜調整してください
            leadingDistribution: TextLeadingDistribution.even, // 上下の余白を均等に分配
          ),
        ),
      );
    }

    if (kingaku != null && isComplexCombinationForPrefix) {
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
                  child: const Text('マルチ', style: TextStyle(color: Colors.white, fontSize: 20, height: 1)),
                ),
              Text(isComplexCombinationForPrefix ? '各組' : '', style: amountStyle),
              Text(_getStars(kingaku), style: starStyle),
              Text('$kingaku円', style: amountStyle),
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
          FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('単勝 ', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
          FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('複勝 ', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
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
    super.key,
    required this.parsedResult,
  });

  @override
  Widget build(BuildContext context) {
    final int totalAmount = parsedResult['合計金額'] as int? ?? 0;
    if (totalAmount == 0) {
      return const SizedBox.shrink();
    }

    String totalStars = _getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();

    const TextStyle totalStarStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    const TextStyle totalAmountTextStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('合計　', style: totalAmountTextStyle),
          Text(totalStars, style: totalStarStyle),
          Text('$totalAmountString円', style: totalAmountTextStyle),
        ],
      ),
    );
  }
}