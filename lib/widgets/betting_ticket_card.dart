// lib/widgets/betting_ticket_card.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

// 半角数字を全角数字に変換するヘルパー関数
// 馬券の券面に印字されるスタイルに合わせるために使用
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
/// [ticketData] に含まれる情報に基づいて、券種や方式に応じたスタイルで表示を切り替える
class BettingTicketCard extends StatelessWidget {
  // 表示する馬券のデータ
  final Map<String, dynamic> ticketData;

  // コンストラクタ
  const BettingTicketCard({
    super.key,
    required this.ticketData,
  });

  @override
  Widget build(BuildContext context) {
    // 発売所の情報を格納する変数
    String? salesLocation;
    // ticketDataに'発売所'キーが存在する場合、その値を取得
    if (ticketData.containsKey('発売所')) {
      salesLocation = ticketData['発売所'] as String;
    }

    // 券面中央に表示する式別名を格納する変数（例: "馬連", "３連単"）
    String shikibetsuToDisplay = '';
    // 券面右上に表示する方式名を格納する変数（例: "ながし", "ボックス", "が　ん　ば　れ！"）
    String hoshikiToDisplay = '';
    // 購入内容リストの先頭から取得した主要な式別名を格納する変数
    String primaryShikibetsuFromDetails = '';
    // 馬券全体の方式を格納する変数（例: "通常", "ながし", "応援馬券"）
    String overallMethod = '';

    // ### ここからがスタイル変更ロジック ###
    // ticketDataの内容に応じて、馬券の券面デザイン（テキスト、色など）を動的に変更する

    // スタイルを格納する変数の初期化（デフォルト値）
    // 中央エリア上部に表示するウィジェット
    Widget topWidget = Text('Top', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white));
    // 中央エリア下部に表示するウィジェット
    Widget bottomWidget = Text('Bottom', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white));
    // 中央エリア上部のコンテナ色
    Color topContainerColor = Colors.black;
    // 中央エリア下部のコンテナ色
    Color bottomContainerColor = Colors.black;
    // 中央エリア中央部のコンテナ色
    Color middleContainerColor = Colors.transparent;
    // 中央エリア中央部のテキスト色
    Color middleTextColor = Colors.black;


    // ticketDataに'方式'キーが存在する場合のみ、スタイル設定ロジックを実行
    if (ticketData.containsKey('方式')) {
      // 全体の方式を取得
      overallMethod = ticketData['方式'] ?? '';

      // 購入内容の詳細リストを取得
      List<Map<String, dynamic>> purchaseDetails = [];
      if (ticketData.containsKey('購入内容')) {
        purchaseDetails = (ticketData['購入内容'] as List).cast<Map<String, dynamic>>();
        // 購入内容が1件以上あり、最初の項目に'式別'キーが存在する場合
        if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
          // 式別IDを取得
          final shikibetsuId = purchaseDetails[0]['式別'];
          // 式別IDを日本語の式別名に変換して格納（例: "01" -> "単勝"）
          // bettingDictは外部で定義された式別IDと式別名の対応マップを想定
          primaryShikibetsuFromDetails = bettingDict[shikibetsuId] ?? '';
        }
      }

      // '応援馬券'の場合の特別なスタイル設定
      if (overallMethod == '応援馬券') {
        shikibetsuToDisplay = '単勝+複勝'; // 中央の表示テキスト
        hoshikiToDisplay = 'が　ん　ば　れ！'; // 右上の表示テキスト

        // 応援馬券のスタイル設定
        // 上部ウィジェット（単勝 "WIN"）
        topWidget = const SizedBox(
          height: 15.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text('WIN', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black)),
          ),
        );
        topContainerColor = Colors.transparent; // 背景を透明（白）に

        // 下部ウィジェット（複勝 "PLACE/SHOW"）
        bottomWidget = const SizedBox(
          height: 30.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ),
        );
        bottomContainerColor = Colors.black; // 背景を黒に

      } else {
        // 応援馬券以外の場合のロジック
        if (overallMethod == '通常') {
          // 通常購入の場合、購入内容に含まれるすべての式別名をカンマ区切りで連結して表示
          shikibetsuToDisplay = purchaseDetails.map((p) => bettingDict[p['式別']] ?? '').toSet().join(',');
          hoshikiToDisplay = ''; // 通常購入では方式表示はなし
        } else {
          // ながし、ボックス、フォーメーションなどの場合
          // 主要な式別名があればそれを、なければ全体の方式名（例: "フォーメーション"）を中央に表示
          shikibetsuToDisplay = primaryShikibetsuFromDetails.isNotEmpty ? primaryShikibetsuFromDetails : overallMethod;

          // 'ながし'の場合の方式表示テキストを設定
          if (overallMethod == 'ながし' && purchaseDetails.isNotEmpty) {
            final detail = purchaseDetails[0];
            // 'ながし種別'（例: "軸1頭"）があればそれを採用
            if (detail.containsKey('ながし種別')) {
              hoshikiToDisplay = detail['ながし種別'];
            }
            // なければ'ながし'（例: "1頭軸"）を採用
            else if (detail.containsKey('ながし')) {
              hoshikiToDisplay = detail['ながし'];
            }
            // それもなければ全体の方式名を採用
            else {
              hoshikiToDisplay = overallMethod;
            }
          } else {
            // 'ながし'以外（ボックスなど）は、全体の方式名をそのまま表示
            hoshikiToDisplay = overallMethod;
          }
        }
        // 式別名に含まれる半角数字を全角に変換
        shikibetsuToDisplay = _convertHalfWidthNumbersToFullWidth(shikibetsuToDisplay);

        // 通常馬券のスタイル設定
        // 主要な式別名に応じて、中央エリアのスタイルを切り替える
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
            // 枠連のみ、中央の背景も黒、文字を白にする特別なスタイル
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

    // 馬券全体のUIを構築する部分
    return Container(
      // 馬券全体の装飾
      decoration: BoxDecoration(
        color: Colors.white, // 背景色
        border: Border.all(color: Colors.grey), // 枠線
        // 背景画像（透かし模様）
        image: const DecorationImage(
          image: AssetImage('assets/images/baken_bg.png'),
          fit: BoxFit.fitWidth,
        ),
        // 影をつけて立体感を出す
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.2), // 影の色（少し透明な黒）
            spreadRadius: 1, // 影の広がり
            blurRadius: 4,   // 影のぼかし具合
            offset: Offset(2, 3), // 影の位置（横, 縦）
          ),
        ],
      ),
      // 馬券のコンテンツを配置するRowウィジェット
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 上揃えで配置
        children: [
          // --- 左側領域 ---
          // 日付、開催場、レース番号、発売所を表示
          Expanded(
            flex: 2, // 横幅の比率
            child: SizedBox(
              height: 220, // 高さを固定
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 0), // パディング
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 左揃えで配置
                  children: [
                    // 年、回、日の情報があれば日付を表示
                    if (ticketData.containsKey('年') && ticketData.containsKey('回') && ticketData.containsKey('日'))
                      Text(
                        '20${ticketData['年']}年${ticketData['回']}回${ticketData['日']}日',
                        style: TextStyle(color: Colors.black, fontSize: 15),
                      ),
                    // 開催場とレース番号の情報があれば表示
                    if (ticketData.containsKey('開催場') && ticketData.containsKey('レース'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 開催場名
                          Text(
                            '${ticketData['開催場']}',
                            style: TextStyle(color: Colors.black, fontSize: 22),
                          ),
                          // レース番号と「レース」のテキスト
                          Row(
                            children: [
                              // レース番号（黒背景に白文字）
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
                              const SizedBox(width: 4), // 間隔
                              // 「レース」テキスト
                              const Text(
                                'レース',
                                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold,),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const Spacer(), // 可変の空白スペース（発売所を一番下に配置するため）
                    // 発売所の情報があれば表示
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
          // 式別名（馬連、３連単など）を縦書きで表示
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0), // 上下のパディング
            child: Container(
              width: 40, // 横幅
              height: 190, // 高さ
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.0), // 黒い枠線
              ),
              child: Column(
                children: [
                  // 上部コンテナ（WIN, QUINELLAなど）
                  Container(
                    width: double.infinity, // 横幅いっぱい
                    color: topContainerColor, // スタイル変更ロジックで決定された色
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                    child: Center(
                      child: topWidget, // スタイル変更ロジックで決定されたウィジェット
                    ),
                  ),
                  // 中央の式別名を表示する部分
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      color: middleContainerColor, // スタイル変更ロジックで決定された色
                      // '方式'キーが存在する場合のみ表示
                      child: (ticketData.containsKey('方式'))
                      // 式別が'馬連'の場合は特別なレイアウトを適用
                          ? (primaryShikibetsuFromDetails == '馬連')
                          ? FittedBox(
                        fit: BoxFit.contain,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // "普通"のテキスト
                            Text(
                              '普通',
                              style: TextStyle(
                                color: middleTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12), // 間隔
                            // 式別名を1文字ずつ縦に並べる
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
                      // '馬連'以外の場合は、各文字を均等に配置
                          : Column(
                        // 式別名を1文字ずつに分解し、それぞれをExpandedウィジェットで囲む
                        children: shikibetsuToDisplay.characters.map((char) {
                          return Expanded(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                                child: Text(
                                  char, // 1文字
                                  style: TextStyle(
                                    color: middleTextColor, // スタイル変更ロジックで決定された色
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                      // '方式'キーがない場合は何も表示しない
                          : const SizedBox.shrink(),
                    ),
                  ),
                  // 下部コンテナ（WIN, PLACE/SHOWなど）
                  Container(
                    width: double.infinity,
                    color: bottomContainerColor, // スタイル変更ロジックで決定された色
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                    child: Center(
                      child: bottomWidget, // スタイル変更ロジックで決定されたウィジェット
                    ),
                  )
                ],
              ),
            ),
          ),
          // --- 右側領域 ---
          // 方式（ながし、ボックスなど）、購入内容の詳細を表示
          Expanded(
            flex: 3, // 横幅の比率
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), // パディング
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // 子ウィジェットを横幅いっぱいに広げる
                children: [
                  // 方式の表示テキスト（hoshikiToDisplay）が空でない場合のみ表示
                  if (hoshikiToDisplay.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown, // はみ出さないようにスケールダウン
                      alignment: Alignment.centerLeft, // 左揃え
                      child: Row(
                        children: [
                          // 方式名を表示する枠
                          Container(
                            width: 160,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1.5), // 黒い枠線
                            ),
                            alignment: Alignment.center, // 中央揃え
                            // 即時関数で方式に応じたテキストウィジェットを返す
                            child: () {
                              // テキストの基本スタイル
                              const baseStyle = TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              );
                              // 英語部分のスタイル
                              const englishStyle = TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                              );

                              // 'ながし'の場合、日本語と英語を組み合わせたRichTextを返す
                              if (overallMethod == 'ながし') {
                                return RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: baseStyle.copyWith(fontSize: 20),
                                    children: <TextSpan>[
                                      TextSpan(text: hoshikiToDisplay), // 例: "軸1頭"
                                      TextSpan(text: ' WHEEL', style: englishStyle), // " WHEEL"
                                    ],
                                  ),
                                );
                                // 'ボックス'の場合も同様にRichTextを返す
                              } else if (overallMethod == 'ボックス') {
                                return RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: baseStyle.copyWith(fontSize: 20),
                                    children: <TextSpan>[
                                      TextSpan(text: hoshikiToDisplay), // "ボックス"
                                      TextSpan(text: ' BOX', style: englishStyle), // " BOX"
                                    ],
                                  ),
                                );
                                // それ以外（応援馬券など）は通常のTextウィジェットを返す
                              } else {
                                return Text(
                                  hoshikiToDisplay, // 例: "が　ん　ば　れ！"
                                  style: baseStyle.copyWith(fontSize: 18),
                                );
                              }
                            }(),
                          ),
                        ],
                      ),
                    ),
                  // 方式表示と購入内容の間に8ピクセルの間隔を設ける
                  if (hoshikiToDisplay.isNotEmpty)
                    const SizedBox(height: 8),
                  // 購入内容の詳細（買い目、金額など）を表示する外部ウィジェット
                  PurchaseDetailsCard(
                    parsedResult: ticketData, // 馬券データ全体を渡す
                    betType: overallMethod, // 馬券の方式を渡す
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