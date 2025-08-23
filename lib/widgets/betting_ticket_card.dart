// lib/widgets/betting_ticket_card.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

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

class BettingTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticketData;

  const BettingTicketCard({
    super.key,
    required this.ticketData,
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

    // ### ここからがスタイル変更ロジック ###

    // スタイル変数の初期化（デフォルト値）
    Widget topWidget = Text('Top', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white));
    Widget bottomWidget = Text('Bottom', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white));
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
        shikibetsuToDisplay = '単勝+複勝';
        hoshikiToDisplay = 'が　ん　ば　れ！';

        // 応援馬券のスタイル設定
        topWidget = const SizedBox(
          height: 15.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text('WIN', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black)),
          ),
        );
        topContainerColor = Colors.transparent;

        bottomWidget = const SizedBox(
          height: 30.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
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
            }
            else if (detail.containsKey('ながし')) {
              hoshikiToDisplay = detail['ながし'];
            }
            else {
              hoshikiToDisplay = overallMethod;
            }
          } else {
            hoshikiToDisplay = overallMethod;
          }
        }
        shikibetsuToDisplay = _convertHalfWidthNumbersToFullWidth(shikibetsuToDisplay);

        // 通常馬券のスタイル設定
        switch (primaryShikibetsuFromDetails) {
          case '単勝':
            topWidget = bottomWidget = const SizedBox(
              height: 15.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('WIN', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.transparent;
            break;
          case '複勝':
            topWidget = bottomWidget =  const SizedBox(
              height: 30.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.black;
            break;
          case '馬連':
            topWidget = bottomWidget = const SizedBox(
              height: 15.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('QUINELLA', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.transparent;
            break;
          case '馬単':
            topWidget = bottomWidget = const SizedBox(
              height: 15.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('EXACTA', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.black;
            break;
          case 'ワイド':
            topWidget = bottomWidget = const SizedBox(
              height: 30.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('QUINELLA\nPLACE', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.black;
            break;
          case '枠連':
            Widget wakurenText = Text('BRACKET\nQUINELLA', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white));
            topWidget = bottomWidget = SizedBox(
                height: 30.0,
                child: FittedBox(fit: BoxFit.contain, child: wakurenText)
            );
            topContainerColor = bottomContainerColor = Colors.black;
            middleContainerColor = Colors.black;
            middleTextColor = Colors.white;
            break;
          case '3連複':
            topWidget = bottomWidget = const SizedBox(
              height: 15.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('TRIO', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.transparent;
            break;
          case '3連単':
            topWidget = bottomWidget = const SizedBox(
              height: 15.0,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('TRIFECTA', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            );
            topContainerColor = bottomContainerColor = Colors.black;
            break;
        }
      }
    }
    // ### ここまでがスタイル変更ロジック ###

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        image: const DecorationImage(
          image: AssetImage('assets/images/baken_bg.png'),
          fit: BoxFit.fitWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.2), // 影の色（少し透明な黒）
            spreadRadius: 1, // 影の広がり
            blurRadius: 4,   // 影のぼかし具合
            offset: Offset(2, 3), // 影の位置（横, 縦）
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 左側領域 ---
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ticketData.containsKey('年') && ticketData.containsKey('回') && ticketData.containsKey('日'))
                      Text(
                        '20${ticketData['年']}年${ticketData['回']}回${ticketData['日']}日',
                        style: TextStyle(color: Colors.black, fontSize: 15),
                      ),
                    if (ticketData.containsKey('開催場') && ticketData.containsKey('レース'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ticketData['開催場']}',
                            style: TextStyle(color: Colors.black, fontSize: 22),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 50,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    '${ticketData['レース']}',
                                    style: const TextStyle(color: Colors.white, fontSize: 25, height: 0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'レース',
                                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold,),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const Spacer(),
                    if (salesLocation != null && salesLocation.isNotEmpty)
                      Text(
                        salesLocation,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // --- 中央領域 ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Container(
              width: 40,
              height: 190,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.0),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: topContainerColor,
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                    child: Center(
                      child: topWidget,
                    ),
                  ),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      color: middleContainerColor,
                      child: (ticketData.containsKey('方式'))
                          ? (primaryShikibetsuFromDetails == '馬連')
                          ? FittedBox(
                        fit: BoxFit.contain,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '普通',
                              style: TextStyle(
                                color: middleTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...shikibetsuToDisplay.characters.map((char) {
                              return Text(
                                char,
                                style: TextStyle(
                                  color: middleTextColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      )
                          : Column(
                        children: shikibetsuToDisplay.characters.map((char) {
                          return Expanded(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                                child: Text(
                                  char,
                                  style: TextStyle(
                                    color: middleTextColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: bottomContainerColor,
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                    child: Center(
                      child: bottomWidget,
                    ),
                  )
                ],
              ),
            ),
          ),
          // --- 右側領域 ---
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hoshikiToDisplay.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Container(
                            width: 160,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: () {
                              const baseStyle = TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              );
                              const englishStyle = TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                              );

                              if (overallMethod == 'ながし') {
                                return RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: baseStyle.copyWith(fontSize: 20),
                                    children: <TextSpan>[
                                      TextSpan(text: hoshikiToDisplay),
                                      TextSpan(text: ' WHEEL', style: englishStyle),
                                    ],
                                  ),
                                );
                              } else if (overallMethod == 'ボックス') {
                                return RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: baseStyle.copyWith(fontSize: 20),
                                    children: <TextSpan>[
                                      TextSpan(text: hoshikiToDisplay),
                                      TextSpan(text: ' BOX', style: englishStyle),
                                    ],
                                  ),
                                );
                              } else {
                                return Text(
                                  hoshikiToDisplay,
                                  style: baseStyle.copyWith(fontSize: 18),
                                );
                              }
                            }(),
                          ),
                        ],
                      ),
                    ),
                  if (hoshikiToDisplay.isNotEmpty)
                    const SizedBox(height: 8),
                  PurchaseDetailsCard(
                    parsedResult: ticketData,
                    betType: overallMethod,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
