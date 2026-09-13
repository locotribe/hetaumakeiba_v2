// lib/widgets/ticket/cards/betting_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/purchase_combinations_card.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/ticket_common_layer.dart';

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
    Widget topWidget = const Text('Top', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white));
    Widget bottomWidget = const Text('Bottom', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white));
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

      switch (primaryShikibetsuFromDetails) {
        case '単勝':
          topWidget = bottomWidget = const SizedBox(height: 15.0, child: FittedBox(fit: BoxFit.contain, child: Text('WIN', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))));
          topContainerColor = bottomContainerColor = Colors.transparent;
          break;
        case '複勝':
          topWidget = bottomWidget = const SizedBox(height: 30.0, child: FittedBox(fit: BoxFit.contain, child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))));
          topContainerColor = bottomContainerColor = Colors.black;
          break;
        case '馬連':
          topWidget = bottomWidget = const SizedBox(height: 15.0, child: FittedBox(fit: BoxFit.contain, child: Text('QUINELLA', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))));
          topContainerColor = bottomContainerColor = Colors.transparent;
          break;
        case '馬単':
          topWidget = bottomWidget = const SizedBox(height: 15.0, child: FittedBox(fit: BoxFit.contain, child: Text('EXACTA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))));
          topContainerColor = bottomContainerColor = Colors.black;
          break;
        case 'ワイド':
          topWidget = bottomWidget = const SizedBox(height: 30.0, child: FittedBox(fit: BoxFit.contain, child: Text('QUINELLA\nPLACE', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))));
          topContainerColor = bottomContainerColor = Colors.black;
          break;
        case '枠連':
          Widget wakurenText = const Text('BRACKET\nQUINELLA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white));
          topWidget = bottomWidget = SizedBox(height: 30.0, child: FittedBox(fit: BoxFit.contain, child: wakurenText));
          topContainerColor = bottomContainerColor = Colors.black;
          middleContainerColor = Colors.black;
          middleTextColor = Colors.white;
          break;
        case '3連複':
          topWidget = bottomWidget = const SizedBox(height: 15.0, child: FittedBox(fit: BoxFit.contain, child: Text('TRIO', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))));
          topContainerColor = bottomContainerColor = Colors.transparent;
          break;
        case '3連単':
          topWidget = bottomWidget = const SizedBox(height: 15.0, child: FittedBox(fit: BoxFit.contain, child: Text('TRIFECTA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))));
          topContainerColor = bottomContainerColor = Colors.black;
          break;
      }
    }

    return AspectRatio(
      aspectRatio: 86 / 53,
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
                                      if (i > 0) const SizedBox(height: 2),
                                      Text(
                                        shikibetsuToDisplay.characters.elementAt(i),
                                        style: GoogleFonts.notoSerifJp(
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
                    height: h * 0.33,
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
                                    child: Text(hoshikiToDisplay, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
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
                    top: hoshikiToDisplay.isNotEmpty ? h * 0.33 : h * 0.02,
                    width: w * 0.53,
                    height: hoshikiToDisplay.isNotEmpty ? h * 0.22 : h * 0.53,
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
                  Positioned(
                    left: w * 0.47,
                    top: h * 0.55,
                    width: w * 0.53,
                    height: h * 0.27,
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
    );
  }
}