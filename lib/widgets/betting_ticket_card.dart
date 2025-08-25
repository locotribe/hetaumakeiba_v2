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

/// JRAの馬券を模したUIを表示するウィジェット
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
        shikibetsuToDisplay = '単勝+複勝';
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

    return Container(
      height: 230,
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
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
        child: Column(
          children: [
            // --- 上段 ---
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- (上段) 左側領域 ---
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ticketData.containsKey('年') && ticketData.containsKey('回') && ticketData.containsKey('日'))
                          Text(
                            '20${ticketData['年']}年${ticketData['回']}回${ticketData['日']}日',
                            style: const TextStyle(color: Colors.black, fontSize: 15,height: 1.0,),


                          ),
                        if (ticketData.containsKey('開催場') && ticketData.containsKey('レース'))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ticketData['開催場']}',
                                style: const TextStyle(color: Colors.black, fontSize: 22),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(color: Colors.black),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Text(
                                        '${ticketData['レース']}',
                                        style: const TextStyle(color: Colors.white, fontSize: 23, height: 0.9),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'レース',
                                    style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // --- (上段) 中央領域 ---
                  Container(
                    width: 40,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: topContainerColor,
                          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                          child: Center(child: topWidget),
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
                                  Text('普通', style: TextStyle(color: middleTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  ...shikibetsuToDisplay.characters.map((char) {
                                    return Text(char, style: TextStyle(color: middleTextColor, fontSize: 20, fontWeight: FontWeight.bold));
                                  }),
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
                                        style: TextStyle(color: middleTextColor, fontSize: 16, fontWeight: FontWeight.bold),
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
                          child: Center(child: bottomWidget),
                        )
                      ],
                    ),
                  ),
                  // --- (上段) 右側領域 ---
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hoshikiToDisplay.isNotEmpty)
                          // LayoutBuilderで親ウィジェットの幅を取得
                            LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                // 利用可能な最大の幅をキャプチャ
                                final double availableWidth = constraints.maxWidth;

                                return DecoratedBox(
                                  decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    // Containerに取得した幅を明示的に設定
                                    child: Container(
                                      height: 30,
                                      width: availableWidth,
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: () {
                                        const baseStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold);
                                        const englishStyle = TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.normal);
                                        if (overallMethod == 'ながし' || overallMethod == 'ボックス') {
                                          // Containerの幅が確定しているので、Row + Expandedが正しく機能する
                                          return Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: FittedBox(
                                                  fit: BoxFit.contain,
                                                  child: Text(
                                                    hoshikiToDisplay,
                                                    style: baseStyle,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1, // 1/3のスペースを確保
                                                child: Center(
                                                  child: Text(
                                                    overallMethod == 'ながし' ? 'WHEEL' : 'BOX',
                                                    style: englishStyle,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          return Center(
                                            child: FittedBox(
                                              fit: BoxFit.contain, // 親ウィジェットに収まるように調整（デフォルト）
                                              child: Text(
                                                hoshikiToDisplay,
                                                style: baseStyle.copyWith(fontSize: 30),
                                              ),
                                            ),
                                          );
                                        }
                                      }(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (hoshikiToDisplay.isNotEmpty) const SizedBox(height: 0),

                          // 購入内容（馬番）が残りのスペースを全て使う
                          Expanded(
                            child: PurchaseDetailsCard(
                              parsedResult: ticketData,
                              betType: overallMethod,
                            ),
                          ),

                          // 組合せ数・金額は下部に固定
                          PurchaseCombinationsCard(
                            parsedResult: ticketData,
                            betType: overallMethod,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- 下段 ---
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: (salesLocation != null && salesLocation.isNotEmpty)
                      ? Text(
                    salesLocation,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, height: 1.0,),
                  )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 40 + 10),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: PurchaseTotalAmountCard(
                      parsedResult: ticketData,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
