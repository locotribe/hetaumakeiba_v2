// lib/widgets/ticket/cards/betting_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/purchase_combinations_card.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/ticket_common_layer.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/shikibetsu_band_spec.dart';

/// JRAの馬券を模したUIを表示するウィジェット
class BettingTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticketData;
  final RaceResult? raceResult;

  const BettingTicketCard({
    super.key,
    required this.ticketData,
    this.raceResult,
  });

  @override
  Widget build(BuildContext context) {
    String shikibetsuToDisplay = '';
    String hoshikiToDisplay = '';
    String primaryShikibetsuFromDetails = '';
    String overallMethod = '';
    Widget topWidget = Text('Top', textAlign: TextAlign.center, style: ticketGothic(fontSize: 12, color: Colors.white));
    Widget bottomWidget = Text('Bottom', textAlign: TextAlign.center, style: ticketGothic(fontSize: 12, color: Colors.white));
    Color topContainerColor = Colors.black;
    Color bottomContainerColor = Colors.black;
    Color middleContainerColor = Colors.transparent;
    Color middleTextColor = Colors.black;

    if (ticketData.containsKey('方式')) {
      overallMethod = ticketData['方式'] ?? '';
      List<Map<String, dynamic>> purchaseDetails = [];
      if (ticketData.containsKey('購入内容')) {
        purchaseDetails = (ticketData['購入内容'] as List).cast<Map<String, dynamic>>();
        if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
          final shikibetsuId = purchaseDetails[0]['式別'];
          primaryShikibetsuFromDetails = bettingDict[shikibetsuId] ?? '';
        }
      }

      if (overallMethod == '通常') {
        shikibetsuToDisplay = purchaseDetails.map((p) => bettingDict[p['式別']] ?? '').toSet().join(',');
        hoshikiToDisplay = '';
      } else {
        shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : overallMethod;
        if (overallMethod == 'ながし' && purchaseDetails.isNotEmpty) {
          final detail = purchaseDetails[0];
          if (detail.containsKey('ながし種別')) {
            hoshikiToDisplay = detail['ながし種別'];
          } else if (detail.containsKey('ながし')) {
            hoshikiToDisplay = detail['ながし'];
          } else {
            hoshikiToDisplay = overallMethod;
          }
        } else {
          hoshikiToDisplay = overallMethod;
        }
      }
      shikibetsuToDisplay = convertHalfWidthNumbersToFullWidth(shikibetsuToDisplay);

      final ShikibetsuBandSpec? bandSpec = resolveShikibetsuBandSpec(primaryShikibetsuFromDetails);
      if (bandSpec != null) {
        topWidget = bottomWidget = SizedBox(
          height: bandSpec.singleLabelHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              bandSpec.label,
              textAlign: TextAlign.center,
              style: ticketGothic(color: bandSpec.labelColor),
            ),
          ),
        );
        topContainerColor = bottomContainerColor = bandSpec.labelBackgroundColor;
        middleContainerColor = bandSpec.middleBackgroundColor;
        middleTextColor = bandSpec.middleTextColor;
      }
    }

    // [追加] 単勝・複勝で馬名が表示される場合、組合せ欄が空になるため購入内容の枠を下まで広げる (v.2026.9.14+26091401)
    final bool isHorseNameLayout = overallMethod == '通常' &&
        raceResult != null &&
        (primaryShikibetsuFromDetails == '単勝' || primaryShikibetsuFromDetails == '複勝');

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

                  // === 中央列: 式別 (36%, 0%, 11%, 82%) ===
                  Positioned(
                    left: w * 0.36,
                    top: 0,
                    width: w * 0.11,
                    height: h * 0.82,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            color: topContainerColor,
                            padding: const EdgeInsets.symmetric(vertical: 0.5),
                            child: Center(child: topWidget),
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              color: middleContainerColor,
                              padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                              child: (ticketData.containsKey('方式'))
                                  ? FittedBox(
                                fit: BoxFit.fitWidth, // ← 横幅いっぱいにフィットさせる設定
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0; i < shikibetsuToDisplay.characters.length; i++) ...[
                                      // [修正] 実物馬券に合わせ、2文字の式別(単勝・複勝等)の時は文字間を1文字分(18px)空ける (v.2026.9.14+26091401)
                                      if (i > 0) SizedBox(height: shikibetsuToDisplay.characters.length == 2 ? 18.0 : 2.0),
                                      Text(
                                        shikibetsuToDisplay.characters.elementAt(i),
                                        style: ticketMincho(
                                          color: middleTextColor,
                                          fontSize: 30, // ← 基準サイズを 36 など大きめにする
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            color: bottomContainerColor,
                            padding: const EdgeInsets.symmetric(vertical: 0.5),
                            child: Center(child: bottomWidget),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // === 右列1: 上部方式等 (47%, 0%, 53%, 33%) ===
                  Positioned(
                    left: w * 0.47,
                    top: 0,
                    width: w * 0.53,
                    height: h * 0.15,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0, right: 2.0, top: 1.0),
                      child: Column(
                        children: [
                          if (hoshikiToDisplay.isNotEmpty)
                            DecoratedBox(
                              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)),
                              child: SizedBox(
                                height: h * 0.12,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(hoshikiToDisplay, style: ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // === 右列2: 購入内容 (47%, 33%, 53%, 22%) ===
                  Positioned(
                    left: w * 0.47,
                    top: hoshikiToDisplay.isNotEmpty ? h * 0.15 : h * 0.02,
                    width: w * 0.53,
                    // [修正] 単勝・複勝は組合せ欄が空になるため、その分まで枠を広げて縦中央を正す (v.2026.9.14+26091401)
                    height: isHorseNameLayout
                        ? h * 0.80
                        : (hoshikiToDisplay.isNotEmpty ? h * 0.45 : h * 0.53),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: PurchaseDetailsCard(
                        parsedResult: ticketData,
                        betType: overallMethod,
                        raceResult: raceResult,
                      ),
                    ),
                  ),

                  // === 右列3: 組合せ・金額 (47%, 55%, 53%, 27%) ===
                  // [修正] 単勝・複勝では組合せ欄が空になるため、領域ごと描画しない (v.2026.9.14+26091401)
                  if (!isHorseNameLayout)
                    Positioned(
                      left: w * 0.47,
                      top: h * 0.60,
                      width: w * 0.53,
                      height: h * 0.22,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: PurchaseCombinationsCard(
                          parsedResult: ticketData,
                          betType: overallMethod,
                        ),
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
}