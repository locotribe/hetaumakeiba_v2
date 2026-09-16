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

                  // === 上段（第1式別ブロック: Y 0% 〜 41%）===
                  _buildSingleShikibetsuBand(
                    left: w * 0.36,
                    top: 0,
                    width: w * 0.11,
                    height: h * 0.41,
                    shikibetsuCode: code1,
                  ),
                  Positioned(
                    left: w * 0.47,
                    top: 0,
                    width: w * 0.53,
                    height: h * 0.41,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildDetailsListForGroup(group1Details, h * 0.41),
                    ),
                  ),

                  // === 下段（第2式別ブロック: Y 41% 〜 82%）===
                  _buildSingleShikibetsuBand(
                    left: w * 0.36,
                    top: h * 0.41,
                    width: w * 0.11,
                    height: h * 0.41,
                    shikibetsuCode: code2,
                  ),
                  Positioned(
                    left: w * 0.47,
                    top: h * 0.41,
                    width: w * 0.53,
                    height: h * 0.41,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildDetailsListForGroup(group2Details, h * 0.41),
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

  /// 既存の帯の分岐スタイルを100%保持したまま、指定された領域(高さ)に帯を描画するヘルパー
  Widget _buildSingleShikibetsuBand({
    required double left,
    required double top,
    required double width,
    required double height,
    required String shikibetsuCode,
  }) {
    String normalizedCode = shikibetsuCode;
    if (int.tryParse(shikibetsuCode) != null) {
      normalizedCode = int.parse(shikibetsuCode).toString();
    }
    final String shikibetsuName = bettingDict[normalizedCode] ?? bettingDict[shikibetsuCode] ?? '';
    Widget topWidget = const SizedBox.shrink();
    Widget bottomWidget = const SizedBox.shrink();
    Color topBg = Colors.black;
    Color bottomBg = Colors.black;
    Color middleBg = Colors.transparent;
    Color middleTextColor = Colors.black;

    final ShikibetsuBandSpec? bandSpec = resolveShikibetsuBandSpec(shikibetsuName);
    if (bandSpec != null) {
      topWidget = bottomWidget = FittedBox(
        fit: BoxFit.contain,
        child: Text(bandSpec.label, style: ticketGothic(color: bandSpec.labelColor)),
      );
      topBg = bottomBg = bandSpec.labelBackgroundColor;
      middleBg = bandSpec.middleBackgroundColor;
      middleTextColor = bandSpec.middleTextColor;
    }

    final String fullWidthName = convertHalfWidthNumbersToFullWidth(shikibetsuName);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: topBg,
              padding: const EdgeInsets.symmetric(vertical: 0.5),
              child: SizedBox(height: height * 0.22, child: Center(child: topWidget)),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                color: middleBg,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
            Container(
              width: double.infinity,
              color: bottomBg,
              padding: const EdgeInsets.symmetric(vertical: 0.5),
              child: SizedBox(height: height * 0.22, child: Center(child: bottomWidget)),
            ),
          ],
        ),
      ),
    );
  }

  /// 1つの式別グループ内の購入リストを描画するヘルパー
  Widget _buildDetailsListForGroup(List<Map<String, dynamic>> groupDetails, double availableHeight) {
    if (groupDetails.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var detail in groupDetails) ...[
          _buildGroupItemRow(detail),
        ]
      ],
    );
  }

  Widget _buildGroupItemRow(Map<String, dynamic> detail) {
    final String rawCode = detail['式別']?.toString() ?? '';
    String normalizedCode = rawCode;
    if (int.tryParse(rawCode) != null) {
      normalizedCode = int.parse(rawCode).toString();
    }
    final String shikibetsu = bettingDict[normalizedCode] ?? bettingDict[rawCode] ?? '';
    final horseNumbers = detail['馬番'];
    final int? amount = detail['購入金額'];

    String symbol = '━';
    if (shikibetsu == '馬単' || shikibetsu == '3連単') symbol = '▶';
    if (shikibetsu == 'ワイド') symbol = '◆';

    List<int> numbers = [];
    if (horseNumbers is List) {
      numbers = horseNumbers.cast<int>();
    } else if (horseNumbers is int) {
      numbers = [horseNumbers];
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < numbers.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
              child: Text(
                '${numbers[i]}',
                style: ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (i < numbers.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(symbol, style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
          const SizedBox(width: 8),
          if (amount != null) ...[
            Text(getStars(amount), style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$amount', style: ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  TextSpan(text: '円', style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
