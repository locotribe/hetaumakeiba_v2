// lib/widgets/betting_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

// 半角数字を全角数字に変換するヘルパー関数
String _convertHalfWidthNumbersToFullWidth(String text) {
  return text
      .replaceAll('0', '０')
      .replaceAll('1', '１')
      .replaceAll('2', '２')
      .replaceAll('3', '３')
      .replaceAll('4', '４')
      .replaceAll('5', '５')
      .replaceAll('6', '６')
      .replaceAll('7', '７')
      .replaceAll('8', '８')
      .replaceAll('9', '９');
}

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
    String? salesLocation;
    if (ticketData.containsKey('発売所')) {
      salesLocation = ticketData['発売所'] as String;
    }

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

      if (overallMethod == '応援馬券') {
        shikibetsuToDisplay = '単勝✙複勝';
        hoshikiToDisplay = 'が　ん　ば　れ！';
        topWidget = const SizedBox(
          height: 15.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text('WIN', textAlign: TextAlign.center, style: TextStyle(color: Colors.black)),
          ),
        );
        topContainerColor = Colors.transparent;
        bottomWidget = const SizedBox(
          height: 30.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
          ),
        );
        bottomContainerColor = Colors.black;
      } else {
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
        shikibetsuToDisplay = _convertHalfWidthNumbersToFullWidth(shikibetsuToDisplay);

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
              final leftPadding = w * 0.018; // 赤色縦線(QRコード左端)にインデントを正確に揃えるオフセット

              return Stack(
                children: [
                  // === 左列1: 年月日 (0%, 0%, 36%, 11%) ===
                  Positioned(
                    left: leftPadding,
                    top: 0,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.11,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ticketData.containsKey('年') && ticketData.containsKey('回') && ticketData.containsKey('日')
                            ? Text(
                                '20${ticketData['年']}年${ticketData['回']}回${ticketData['日']}日',
                                style: GoogleFonts.notoSerifJp(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // === 左列2: 開催場 (0%, 11%, 36%, 14%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.09,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.17,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ticketData.containsKey('開催場')
                            ? Text(
                                '${ticketData['開催場']}',
                                style: GoogleFonts.notoSerifJp(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 30,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // === 左列3: レース番号 (0%, 25%, 36%, 12%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.25,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ticketData.containsKey('レース')
                          ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: w * 0.13,
                            height: h * 0.11,
                            alignment: Alignment.center,
                            color: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 1.0), // 黒枠内の微小なパディング
                            child: FittedBox(
                              fit: BoxFit.contain, // ★ 枠の高さに合わせて自動で限界まで拡大
                              child: Text(
                                '${ticketData['レース']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900, // ★ 極太にする
                                  fontSize: 32, // ★ 基準サイズを大きくする
                                  height: 1.0,  // ★ 上下の余白をカットして黒枠いっぱいに広げる
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'レース',
                            style: GoogleFonts.notoSerifJp( // ★ 明朝体（GoogleFonts.notoSerifJp）に変更
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // === 左列4: QRコード (0%, 37%, 36%, 26%) ===
                  Positioned(
                    left: 0,
                    top: h * 0.38,
                    width: w * 0.36,
                    height: h * 0.26,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Image.asset('assets/images/QR_JRA.png', fit: BoxFit.contain),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Builder(builder: (context) {
                              if (raceResult != null && raceResult!.raceId.isNotEmpty) {
                                final url = 'https://db.netkeiba.com/race/${raceResult!.raceId}';
                                return QrImageView(
                                  data: url,
                                  version: QrVersions.auto,
                                  backgroundColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                );
                              } else {
                                return Image.asset('assets/images/QR_JRA.png', fit: BoxFit.contain);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === 左列5: 第86回 菊花賞 (0%, 63%, 36%, 19%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.63,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.19,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: raceResult != null && raceResult!.raceTitle.isNotEmpty
                          ? Builder(builder: (context) {
                              final RegExp regExp = RegExp(r"^(第.+?回)(.+?)\((.+?)\)$");
                              final match = regExp.firstMatch(raceResult!.raceTitle);

                              if (match != null && match.groupCount >= 3) {
                                final String numberPart = match.group(1)!;
                                final String namePart = match.group(2)!;
                                final String gradePart = match.group(3)!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text("$numberPart  ($gradePart)", style: GoogleFonts.notoSerifJp(fontSize: 15, color: Colors.black)),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(namePart, style: GoogleFonts.notoSerifJp(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                                    ),
                                  ],
                                );
                              } else {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(raceResult!.raceTitle, style: GoogleFonts.notoSerifJp(fontSize: 13, color: Colors.black)),
                                );
                              }
                            })
                          : const SizedBox.shrink(),
                    ),
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

                  // === フッター1・左: 発券場所 (0%, 82%, 36%, 9%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.82,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.09,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          salesLocation != null && salesLocation.startsWith('JRA') && !salesLocation.startsWith('JRA ')
                              ? salesLocation.replaceFirst('JRA', 'JRA ')
                              : (salesLocation ?? ''),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                  // === フッター1・右: 合計金額 (36%, 82%, 64%, 9%) ===
                  Positioned(
                    left: w * 0.36,
                    top: h * 0.82,
                    width: w * 0.64,
                    height: h * 0.14,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PurchaseTotalAmountCard(parsedResult: ticketData),
                    ),
                  ),

                  // === フッター2・左: 日付 (0%, 91%, 36%, 9%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.91,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.09,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          raceResult != null && raceResult!.raceDate.isNotEmpty
                              ? () {
                            final match = RegExp(r'(\d{1,2})[月/\.-](\d{1,2})').firstMatch(raceResult!.raceDate);
                            if (match != null) {
                              final month = int.parse(match.group(1)!); // 02 -> 2 に変換
                              final day = int.parse(match.group(2)!);   // 02 -> 2 に変換
                              return '$month月$day日';                  // 2月2日 にして返す
                            }
                            return raceResult!.raceDate;
                          }()
                              : '',
                          style: const TextStyle(color: Colors.black, fontSize: 13),
                        ),
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