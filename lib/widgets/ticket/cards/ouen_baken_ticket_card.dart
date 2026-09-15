// lib/widgets/ticket/cards/ouen_baken_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/ticket_common_layer.dart';

/// 応援馬券専用のJRAの馬券を模したUIを表示するウィジェット
class OuenBakenTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticketData;
  final RaceResult? raceResult;

  const OuenBakenTicketCard({
    super.key,
    required this.ticketData,
    this.raceResult,
  });

  @override
  Widget build(BuildContext context) {
    String shikibetsuToDisplay = '単勝✙複勝';
    String hoshikiToDisplay = 'が　ん　ば　れ！';
    String overallMethod = '';
    Widget topWidget = const SizedBox(
      height: 15.0,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text('WIN', textAlign: TextAlign.center, style: TextStyle(color: Colors.black)),
      ),
    );
    Widget bottomWidget = const SizedBox(
      height: 30.0,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
      ),
    );
    Color topContainerColor = Colors.transparent;
    Color bottomContainerColor = Colors.black;
    Color middleContainerColor = Colors.transparent;
    Color middleTextColor = Colors.black;

    if (ticketData.containsKey('方式')) {
      overallMethod = ticketData['方式'] ?? '';
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

                  // ★【右列1】「が　ん　ば　れ！」枠の配置領域 (横幅: 53%, 高さ: 18%)
                  Positioned(
                    left: w * 0.47,   // 左端から 47% の位置
                    top: 0,           // 最上部
                    width: w * 0.53,  // 横幅 53%
                    height: h * 0.18, // 高さ 18%
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0, right: 2.0, top: 1.0),
                      child: Column(
                        children: [
                          if (hoshikiToDisplay.isNotEmpty)
                            DecoratedBox(
                              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)), // 「がんばれ！」の黒い囲み枠
                              child: SizedBox(
                                height: h * 0.12, // 枠の高さ
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      hoshikiToDisplay, 
                                      style: const TextStyle(
                                        color: Colors.black, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 24, // ★「が　ん　ば　れ！」の文字サイズ (24pt)
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ★【右列2】「購入内容（馬番・馬名・各100円）」の大元表示領域 (横幅: 53%, 高さ: 37%)
                  Positioned(
                    left: w * 0.47,  // 左端から 47% の位置
                    top: hoshikiToDisplay.isNotEmpty ? h * 0.18 : h * 0.02, // 「がんばれ！」枠のすぐ下(高さ18%の位置)から開始
                    width: w * 0.53, // 横幅 53%
                    height: hoshikiToDisplay.isNotEmpty ? h * 0.37 : h * 0.53, // ★大元の表示箱の高さ (37%)
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: PurchaseDetailsCard(
                        parsedResult: ticketData,
                        betType: overallMethod,
                        raceResult: raceResult,
                      ),
                    ),
                  ),

                  // ★【右列3】「単勝 100円」「複勝 100円」の配置領域 (横幅: 53%, 高さ: 27%)
                  Positioned(
                    left: w * 0.47,  // 左端から 47% の位置
                    top: h * 0.55,   // 上から 55% の位置から開始
                    width: w * 0.53, // 横幅 53%
                    height: h * 0.27, // 高さ 27%
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: _buildOuenAmountDisplay(ticketData),
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

/// 応援馬券の「単勝◯円」「複勝◯円」2行表示の描画関数
Widget _buildOuenAmountDisplay(Map<String, dynamic> ticketData) {
  if (!ticketData.containsKey('購入内容')) {
    return const SizedBox.shrink();
  }
  List<Map<String, dynamic>> purchaseDetails = (ticketData['購入内容'] as List).cast<Map<String, dynamic>>();
  if (purchaseDetails.length < 2) {
    return const SizedBox.shrink();
  }
  final detail = purchaseDetails.first;

  // 伏せ字「☆」のフォントスタイル
  const TextStyle starStyle = TextStyle(
    color: Colors.black, 
    fontWeight: FontWeight.bold, 
    fontSize: 10, // ★単勝・複勝の「☆」の文字サイズ (10pt)
  );
  
  // 「単勝」「複勝」「100円」のフォントスタイル
  const TextStyle amountStyle = TextStyle(
    color: Colors.black, 
    fontWeight: FontWeight.bold, 
    fontSize: 14, // ★「単勝」「複勝」「100円」の文字サイズ (14pt)
    height: 1.0,
  );

  int kingaku = detail['購入金額'] as int;
  String starsForAmount = getStars(kingaku);
  String amountValue = kingaku.toString();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('単勝 ', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
      FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('複勝 ', style: amountStyle), Text(starsForAmount, style: starStyle), Text('$amountValue円', style: amountStyle)])),
    ],
  );
}
