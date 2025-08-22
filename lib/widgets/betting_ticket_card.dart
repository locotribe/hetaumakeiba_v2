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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        image: const DecorationImage(
          image: AssetImage('assets/images/baken_bg.png'),
          fit: BoxFit.fitWidth,
        ),
      ),
// 全体を縦に配置するメインのColumn
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 子要素を左揃えに
        children: [
          // --- 1. 日付情報 ---
          // '年', '回', '日' のデータが存在する場合に日付を表示
          if (ticketData.containsKey('年') && ticketData.containsKey('回') && ticketData.containsKey('日'))
            Text(
              '20${ticketData['年']}年${ticketData['回']}回${ticketData['日']}日',
              style: TextStyle(color: Colors.black, fontSize: 15),
            ),
          const SizedBox(height: 1), // 日付と開催場の間のスペース

          // --- 2. 開催場とレース番号 ---
          // '開催場'と'レース'のデータが存在する場合に表示
          if (ticketData.containsKey('開催場') && ticketData.containsKey('レース'))
          // 開催場名とレース番号表示エリアを縦に並べるColumn
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 子要素を左揃えに
              children: [
                // 開催場名を表示するText
                Text(
                  '${ticketData['開催場']}',
                  style: TextStyle(color: Colors.black, fontSize: 25),
                ),
                const SizedBox(height: 4), // 開催場名とレース番号の間のスペース
                // レース番号と「レース」というテキストを横に並べるRow
                Row(
                  children: [
                    // レース番号を表示する黒い背景のContainer
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
                    const SizedBox(width: 4), // レース番号と「レース」テキストの間のスペース
                    // 「レース」という固定テキスト
                    const Text(
                      'レース',
                      style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold,),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16), // レース情報とメインコンテンツの間のスペース

          // --- 3. メインコンテンツ (左右分割) ---
          // 左側に式別情報、右側に購入詳細を配置するRow
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // 子要素を上揃えに
            children: [
              // --- 3-1. 左側: 式別情報コンテナ ---
              // 式別などを表示する縦長のコンテナ
              Container(
                width: 40,
                height: 190,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2.0),
                ),
                // ヘッダー、式別、フッターを縦に並べるColumn
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // 上部のヘッダー部分のContainer
                    Container(
                      width: double.infinity,
                      color: topContainerColor,
                      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                      child: Center(
                        child: topWidget,
                      ),
                    ),

// 中央の式別表示部分のContainer (Expandedで残りのスペースを全て使用)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: middleContainerColor,
                        // '方式'データが存在する場合に表示
                        child: (ticketData.containsKey('方式'))
                        // primaryShikibetsuFromDetailsが'馬連'の場合の特殊レイアウト
                            ? (primaryShikibetsuFromDetails == '馬連')
                            ? FittedBox(
                          fit: BoxFit.contain,
                          child: Column( // 「馬連」専用のレイアウト
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '普通', // 上部の水平テキスト
                                style: TextStyle(
                                  color: middleTextColor,
                                  fontSize: 12, // 指定されたフォントサイズ
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12), // 適度なスペース
                              // 下部の縦書きテキスト
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
                            : Column( // それ以外の券種のレイアウト
                          children: shikibetsuToDisplay.characters.map((char) {
                            return Expanded(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0), // 上下左右にパディングを追加
                                  child: Text(
                                    char,
                                    style: TextStyle(
                                      color: middleTextColor, // 変数を適用
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        )
                            : const SizedBox.shrink(), // '方式'データがない場合は何も表示しない
                      ),
                    ),

                    // 下部のフッター部分のContainer
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

              const SizedBox(width: 16), // 左右のコンテンツ間のスペース

              // --- 3-2. 右側: 購入方式と詳細情報 ---
              // 右側のエリア全体を確保するExpanded
              Expanded(
                flex: 85,
                // 購入方式と購入詳細カードを縦に並べるColumn
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // 子要素を横幅いっぱいに広げる
                  children: [
                    // 購入方式（ながし、ボックスなど）が存在する場合に表示
                    if (hoshikiToDisplay.isNotEmpty)
                    // 将来的な拡張性を考慮したRow（現在はContainerが1つ）
                      Row(
                        children: [
                          // 購入方式を表示する枠線付きのContainer
                          Container(
                            width: 160,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: () {
                              // ... (RichTextなどの表示ロジック)
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

                    // 購入方式と購入詳細の間のスペース
                    if (hoshikiToDisplay.isNotEmpty)
                      const SizedBox(height: 8),

                    // 購入詳細情報を表示するカスタムウィジェット
                    PurchaseDetailsCard(
                      parsedResult: ticketData,
                      betType: overallMethod,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // メインコンテンツと発売所情報の間のスペース

          // --- 4. 発売所情報 ---
          // 発売所情報が存在する場合に表示するContainer
          if (salesLocation != null && salesLocation.isNotEmpty)
            Container(
              child: Text(
                salesLocation,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
