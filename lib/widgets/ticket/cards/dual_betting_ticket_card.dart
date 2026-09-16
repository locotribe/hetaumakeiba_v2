// lib/widgets/ticket/cards/dual_betting_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/ticket_common_layer.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/shikibetsu_band_spec.dart';

/// 1枚の馬券に2種類の式別（例: ワイド + 3連複）が含まれる通常馬券用カードウィジェット
class DualBettingTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticketData;
  final RaceResult? raceResult;

  const DualBettingTicketCard({
    super.key,
    required this.ticketData,
    this.raceResult,
  });

  // [追加] 右側領域の設計図の固定幅 (v.2026.9.16+26091601)
  static const double _kCanvasWidth = 420.0;
  static const double _kHorseAreaLeft = _kCanvasWidth * 0.022;
  static const double _kHorseAreaWidth = _kCanvasWidth * 0.45;
  static const double _kStarLeftX = _kCanvasWidth * 0.524;
  static const double _kAmountRightX = _kCanvasWidth * 0.924;
  static const double _kEnLeftX = _kCanvasWidth * 0.935;
  static const double _kEnRightX = _kCanvasWidth * 0.983;

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> purchaseDetails = [];
    if (ticketData.containsKey('購入内容')) {
      final rawList = ticketData['購入内容'];
      if (rawList is List) {
        purchaseDetails = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    // 式別コードごとにグループ分け
    final Map<String, List<Map<String, dynamic>>> groupedDetails = {};
    for (var detail in purchaseDetails) {
      final rawCode = detail['式別']?.toString() ?? '';
      String code = rawCode;
      if (rawCode.isNotEmpty) {
        try {
          code = int.parse(rawCode).toString();
        } catch (_) {}
      }
      groupedDetails.putIfAbsent(code, () => []).add(detail);
    }

    final List<String> betCodes = groupedDetails.keys.toList();
    final String code1 = betCodes.isNotEmpty ? betCodes[0] : '';
    final String code2 = betCodes.length > 1 ? betCodes[1] : '';

    final List<Map<String, dynamic>> group1Details = groupedDetails[code1] ?? [];
    final List<Map<String, dynamic>> group2Details = groupedDetails[code2] ?? [];

    // [追加] 上下ブロックを同じ行数に揃えるためのスロット数 (v.2026.9.16+26091601)
    final int slotsPerBlock = group1Details.length > group2Details.length
        ? group1Details.length
        : group2Details.length;

    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return AspectRatio(
      aspectRatio: 86 / 53,
      child: DefaultTextStyle.merge(
        style: ticketMincho(),
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          image: const DecorationImage(
            image: AssetImage('assets/images/baken_bg.png'),
            fit: BoxFit.cover,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return Stack(
                children: [
                  ...buildTicketCommonLayer(
                    w: w,
                    h: h,
                    ticketData: ticketData,
                    raceResult: raceResult,
                  ),

                  // [修正] 上の帯: Y 0%〜40% (v.2026.9.16+26091601)
                  _buildSingleShikibetsuBand(
                    left: w * 0.36,
                    top: 0,
                    width: w * 0.11,
                    height: h * 0.40,
                    shikibetsuCode: code1,
                  ),

                  // [修正] 下の帯: Y 42%〜82%（上下の帯の間にすき間を空ける） (v.2026.9.16+26091601)
                  _buildSingleShikibetsuBand(
                    left: w * 0.36,
                    top: h * 0.42,
                    width: w * 0.11,
                    height: h * 0.40,
                    shikibetsuCode: code2,
                  ),

                  // [修正] 右側（購入内容）は上下を分けず1つの領域として全行等分する (v.2026.9.16+26091601)
                  Positioned(
                    left: w * 0.47,
                    top: 0,
                    width: w * 0.53,
                    height: h * 0.82,
                    child: _buildRightSideContent(
                      group1Details: group1Details,
                      group2Details: group2Details,
                      slotsPerBlock: slotsPerBlock,
                      shikibetsuName1: _shikibetsuNameForCode(code1),
                      shikibetsuName2: _shikibetsuNameForCode(code2),
                      rightWidth: w * 0.53,
                      rightHeight: h * 0.82,
                      textScaler: textScaler,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  /// 式別コード（数字文字列）から式別名を求める
  String _shikibetsuNameForCode(String code) {
    String normalizedCode = code;
    if (int.tryParse(code) != null) {
      normalizedCode = int.parse(code).toString();
    }
    return bettingDict[normalizedCode] ?? bettingDict[code] ?? '';
  }

  /// 既存の帯の分岐スタイルを保持したまま、指定された領域(高さ)に帯を描画するヘルパー
  /// [修正] 実物馬券に合わせ、上のラベルは描かず下ラベルのみとする (v.2026.9.16+26091601)
  Widget _buildSingleShikibetsuBand({
    required double left,
    required double top,
    required double width,
    required double height,
    required String shikibetsuCode,
  }) {
    final String shikibetsuName = _shikibetsuNameForCode(shikibetsuCode);

    Widget bottomWidget = const SizedBox.shrink();
    Color bottomBg = Colors.black;
    Color middleBg = Colors.transparent;
    Color middleTextColor = Colors.black;
    double bottomHeightRatio = 0.13;

    final ShikibetsuBandSpec? bandSpec = resolveShikibetsuBandSpec(shikibetsuName);
    if (bandSpec != null) {
      bottomWidget = FittedBox(
        fit: BoxFit.contain,
        child: Text(bandSpec.label, style: ticketGothic(color: bandSpec.labelColor)),
      );
      bottomBg = bandSpec.labelBackgroundColor;
      middleBg = bandSpec.middleBackgroundColor;
      middleTextColor = bandSpec.middleTextColor;
      // [追加] singleLabelHeightが2行(30.0)なら帯高さの約25%、1行(15.0)なら約13% (v.2026.9.16+26091601)
      bottomHeightRatio = bandSpec.singleLabelHeight >= 30.0 ? 0.25 : 0.13;
    }

    final String fullWidthName = convertHalfWidthNumbersToFullWidth(shikibetsuName);
    final double bottomHeight = height * bottomHeightRatio;
    final double middleHeight = height - bottomHeight;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                color: middleBg,
                child: SizedBox(
                  // [追加] 中央の式別名は中央領域の幅42%・高さ75%の範囲に収める (v.2026.9.16+26091601)
                  width: width * 0.42,
                  height: middleHeight * 0.75,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < fullWidthName.characters.length; i++) ...[
                          if (i > 0) const SizedBox(height: 1),
                          Text(
                            fullWidthName.characters.elementAt(i),
                            style: ticketMincho(color: middleTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: bottomBg,
              padding: const EdgeInsets.symmetric(vertical: 0.5),
              child: SizedBox(height: bottomHeight, child: Center(child: bottomWidget)),
            ),
          ],
        ),
      ),
    );
  }

  /// 右側（購入内容）領域全体を、固定幅420の設計図として組み立て、1つのFittedBoxで実領域に合わせる
  /// [追加] 行ごとのFittedBoxはやめ、設計図全体を1つのFittedBoxで縮小拡大する (v.2026.9.16+26091601)
  Widget _buildRightSideContent({
    required List<Map<String, dynamic>> group1Details,
    required List<Map<String, dynamic>> group2Details,
    required int slotsPerBlock,
    required String shikibetsuName1,
    required String shikibetsuName2,
    required double rightWidth,
    required double rightHeight,
    required TextScaler textScaler,
  }) {
    if (slotsPerBlock <= 0 || rightWidth <= 0) {
      return const SizedBox.shrink();
    }

    // [追加] 右側領域の実際の縦横比に合わせて設計図の高さを決める (v.2026.9.16+26091601)
    final double canvasH = _kCanvasWidth * (rightHeight / rightWidth);
    final double rowH = canvasH / (slotsPerBlock * 2);

    final String symbol1 = _dualSeparatorSymbol(shikibetsuName1);
    final String symbol2 = _dualSeparatorSymbol(shikibetsuName2);
    final int horseCount1 = _dualHorseCountFor(shikibetsuName1);
    final int horseCount2 = _dualHorseCountFor(shikibetsuName2);

    final List<Widget> rows = [
      for (int i = 0; i < slotsPerBlock; i++)
        _buildCanvasRow(
          detail: i < group1Details.length ? group1Details[i] : null,
          symbol: symbol1,
          horseCount: horseCount1,
          rowHeight: rowH,
          textScaler: textScaler,
        ),
      for (int i = 0; i < slotsPerBlock; i++)
        _buildCanvasRow(
          detail: i < group2Details.length ? group2Details[i] : null,
          symbol: symbol2,
          horseCount: horseCount2,
          rowHeight: rowH,
          textScaler: textScaler,
        ),
    ];

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _kCanvasWidth,
        height: canvasH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  /// 設計図上の1行分（実データ行、または不足分を埋める☆行）を描画する
  Widget _buildCanvasRow({
    required Map<String, dynamic>? detail,
    required String symbol,
    required int horseCount,
    required double rowHeight,
    required TextScaler textScaler,
  }) {
    final bool isFiller = detail == null;

    List<int> numbers = [];
    int? amount;
    if (!isFiller) {
      final horseNumbers = detail['馬番'];
      if (horseNumbers is List) {
        numbers = horseNumbers.cast<int>();
      } else if (horseNumbers is int) {
        numbers = [horseNumbers];
      }
      amount = detail['購入金額'] as int?;
    }

    // [追加] amountがnullの実データ行は☆・金額・円を表示しない（既存の挙動と同じ） (v.2026.9.16+26091601)
    final bool showAmountArea = isFiller || amount != null;
    final String starText = isFiller ? '☆☆☆☆☆☆' : (amount != null ? getStars(amount) : '');
    final String amountText = (!isFiller && amount != null) ? _formatAmountWithCommas(amount) : '';

    return SizedBox(
      width: _kCanvasWidth,
      height: rowHeight,
      child: Stack(
        children: [
          Positioned(
            left: _kHorseAreaLeft,
            top: 0,
            width: _kHorseAreaWidth,
            height: rowHeight,
            child: _buildHorseNumberArea(
              numbers: numbers,
              isFiller: isFiller,
              horseCount: horseCount,
              symbol: symbol,
              areaWidth: _kHorseAreaWidth,
              rowHeight: rowHeight,
              textScaler: textScaler,
            ),
          ),
          if (showAmountArea) ...[
            Positioned(
              left: _kStarLeftX,
              right: _kCanvasWidth - _kAmountRightX,
              top: 0,
              height: rowHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  starText,
                  style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: rowHeight * 0.28),
                ),
              ),
            ),
            if (amountText.isNotEmpty)
              Positioned(
                left: _kStarLeftX,
                right: _kCanvasWidth - _kAmountRightX,
                top: 0,
                height: rowHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    amountText,
                    style: ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: rowHeight * 0.5),
                  ),
                ),
              ),
            Positioned(
              left: _kEnLeftX,
              width: _kEnRightX - _kEnLeftX,
              top: 0,
              height: rowHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Text('円', style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: rowHeight * 0.25)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 馬番列（実データなら馬番の枠、☆行なら☆のセル）を描画する
  Widget _buildHorseNumberArea({
    required List<int> numbers,
    required bool isFiller,
    required int horseCount,
    required String symbol,
    required double areaWidth,
    required double rowHeight,
    required TextScaler textScaler,
  }) {
    // [追加] 実データは実際の頭数、☆行は式別ごとの想定頭数でセル数を決める (v.2026.9.16+26091601)
    final int count = (!isFiller && numbers.isNotEmpty) ? numbers.length : horseCount;
    final double boxWidth = areaWidth * (count == 3 ? 0.25 : 0.34);
    final double boxHeight = rowHeight * 0.65;
    final double gapWidth = count > 1 ? (areaWidth - boxWidth * count) / (count - 1) : 0.0;

    final List<Widget> children = [];
    for (int i = 0; i < count; i++) {
      if (isFiller) {
        children.add(_buildDualStarCell(boxWidth: boxWidth, boxHeight: boxHeight));
      } else {
        children.add(_buildDualNumberCell(
          number: numbers[i],
          boxWidth: boxWidth,
          boxHeight: boxHeight,
          textScaler: textScaler,
        ));
      }
      if (i < count - 1) {
        children.add(_buildDualSymbolCell(symbol: symbol, cellWidth: gapWidth, rowHeight: rowHeight));
      }
    }

    return SizedBox(
      width: areaWidth,
      height: rowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  /// 馬番の枠1つを描画する。2桁など横幅が収まらない場合は横方向だけ縮める（長体）
  Widget _buildDualNumberCell({
    required int number,
    required double boxWidth,
    required double boxHeight,
    required TextScaler textScaler,
  }) {
    final String numberStr = number.toString();
    final TextStyle style = ticketGothic(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: boxHeight * 0.82,
      height: 1.0,
    );

    Widget numberText = Text(numberStr, maxLines: 1, softWrap: false, style: style);

    // [追加] 実際に描くTextと同じtextScalerで文字幅を測り、収まらない分だけ横方向に縮める (v.2026.9.16+26091601)
    final double availableWidth = boxWidth - 4.0;
    final double measuredWidth = _measureTextWidth(numberStr, style, textScaler);
    if (measuredWidth > availableWidth && measuredWidth > 0) {
      final double scaleX = availableWidth / measuredWidth;
      numberText = Transform.scale(scaleX: scaleX, child: numberText);
    }

    return Container(
      width: boxWidth,
      height: boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: numberText,
      ),
    );
  }

  /// 馬番の枠と同じ大きさで☆を中央に描画するセル（枠線なし）
  Widget _buildDualStarCell({required double boxWidth, required double boxHeight}) {
    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('☆', style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: boxHeight * 0.5)),
        ),
      ),
    );
  }

  /// 枠と枠の間（記号を置く部分）の中央に区切り記号を描画するセル
  Widget _buildDualSymbolCell({
    required String symbol,
    required double cellWidth,
    required double rowHeight,
  }) {
    final double fontSize = symbol == '▶' ? rowHeight * 0.7 : rowHeight * 0.4;
    return SizedBox(
      width: cellWidth,
      height: rowHeight,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(symbol, style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: fontSize)),
        ),
      ),
    );
  }

  /// 式別ごとの頭数（3連複・3連単は3頭、それ以外は2頭）
  int _dualHorseCountFor(String shikibetsuName) {
    if (shikibetsuName == '3連複' || shikibetsuName == '3連単') return 3;
    return 2;
  }

  /// 式別ごとの区切り記号。共通のgetHorseNumberSymbolは使わずDualファイル内だけで決める
  String _dualSeparatorSymbol(String shikibetsuName) {
    if (shikibetsuName == '3連単' || shikibetsuName == '馬単') return '▶';
    if (shikibetsuName == 'ワイド') return '◆';
    return '-';
  }

  /// 金額をカンマ区切り文字列にする（例: 1000 → "1,000"）
  String _formatAmountWithCommas(int amount) {
    final String digits = amount.toString();
    final StringBuffer buffer = StringBuffer();
    final int len = digits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// 指定したtextScalerで実際に描くTextと同じ条件で文字幅を測る
  double _measureTextWidth(String text, TextStyle style, TextScaler textScaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.width;
  }
}
