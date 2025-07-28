// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic>? parsedResult;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const ResultPage({
    super.key,
    this.parsedResult,
    required this.savedListKey,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Map<String, dynamic>? _parsedResult;

  @override
  void initState() {
    super.initState();
    _parsedResult = widget.parsedResult;
  }

  @override
  void didUpdateWidget(covariant ResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parsedResult != oldWidget.parsedResult) {
      setState(() {
        _parsedResult = widget.parsedResult;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    String displayMessage;
    bool isErrorOrNotTicket = false;

    if (_parsedResult == null) {
      displayMessage = '馬券の読み取りに失敗しました';
      isErrorOrNotTicket = true;
    } else if (_parsedResult!.containsKey('isNotTicket') && _parsedResult!['isNotTicket'] == true) {
      displayMessage = '馬券ではありませんでした';
      isErrorOrNotTicket = true;
    } else if (_parsedResult!.containsKey('エラー')) {
      displayMessage = 'エラー: ${_parsedResult!['エラー']}\n詳細: ${_parsedResult!['詳細']}';
      isErrorOrNotTicket = true;
    } else {
      displayMessage = JsonEncoder.withIndent('  ').convert(_parsedResult);
    }

    String? salesLocation;
    if (_parsedResult != null && _parsedResult!.containsKey('発売所')) {
      salesLocation = _parsedResult!['発売所'] as String;
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


    if (_parsedResult != null && _parsedResult!.containsKey('方式')) {
      overallMethod = _parsedResult!['方式'] ?? '';

      List<Map<String, dynamic>> purchaseDetails = [];
      if (_parsedResult!.containsKey('購入内容')) {
        purchaseDetails = (_parsedResult!['購入内容'] as List).cast<Map<String, dynamic>>();
        if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
          primaryShikibetsuFromDetails = purchaseDetails[0]['式別'];
        }
      }

      if (overallMethod == '応援馬券') {
        shikibetsuToDisplay = '単勝＋複勝';
        hoshikiToDisplay = 'がんばれ！';

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
          shikibetsuToDisplay = purchaseDetails.map((p) => p['式別']).toSet().join(',');
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


    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('解析結果'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  // Container 1: 解析結果全体を囲むメインのコンテナ
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isErrorOrNotTicket
                        ? Center(
                      child: Text(
                        displayMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: _parsedResult != null && _parsedResult!.containsKey('エラー') ? Colors.red : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_parsedResult!.containsKey('年') && _parsedResult!.containsKey('回') && _parsedResult!.containsKey('日'))
                          Text(
                            '20${_parsedResult!['年']}年${_parsedResult!['回']}回${_parsedResult!['日']}日',
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        const SizedBox(height: 4),
                        if (_parsedResult!.containsKey('開催場') && _parsedResult!.containsKey('レース'))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_parsedResult!['開催場']}',
                                style: TextStyle(color: Colors.black, fontSize: 30),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Container 2: レース番号を表示する黒い背景のコンテナ
                                  Container(
                                    width: 70,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.all(Radius.circular(0)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Text(
                                        '${_parsedResult!['レース']}',
                                        style: const TextStyle(color: Colors.white, fontSize: 32, height: 0.9),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'レース',
                                    style: TextStyle(color: Colors.black, fontSize: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Container 3: 左側の縦長のコンテナ（式別などを表示）
                            Container(
                              width: 50,
                              height: 250,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black, width: 2.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  // Container 4: 左側コンテナ内の上部ヘッダー
                                  Container(
                                    width: double.infinity,
                                    color: topContainerColor, // 変数を適用
                                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                                    child: Center(
                                      child: topWidget, // 変数を適用
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  // ### ここからが修正箇所 ###
                                  // Container 5: 左側コンテナの中央部分（式別の文字を表示）
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      color: middleContainerColor, // 変数を適用
                                      child: (_parsedResult!.containsKey('方式'))
                                          ? (primaryShikibetsuFromDetails == '馬連')
                                          ? Column( // 「馬連」専用のレイアウト
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '普通', // 上部の水平テキスト
                                            style: TextStyle(
                                              color: middleTextColor,
                                              fontSize: 14, // 指定されたフォントサイズ
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
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      )
                                          : Column( // それ以外の券種のレイアウト
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: shikibetsuToDisplay.characters.map((char) {
                                          return Text(
                                            char,
                                            style: TextStyle(
                                              color: middleTextColor, // 変数を適用
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }).toList(),
                                      )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                  // ### ここまでが修正箇所 ###

                                  const SizedBox(height: 4),

                                  // Container 6: 左側コンテナ内の下部フッター
                                  Container(
                                    width: double.infinity,
                                    color: bottomContainerColor, // 変数を適用
                                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                                    child: Center(
                                      child: bottomWidget, // 変数を適用
                                    ),
                                  )

                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              flex: 85,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch, // 子要素を横幅いっぱいに広げる
                                children: [
                                  // 上のコンテナ：方式（ながし、ボックスなど）
                                  if (hoshikiToDisplay.isNotEmpty)
                                    Row( // ← このRowウィジェットを追加
                                      children: [
                                        Container(
                                          width: 250, // ← ここで幅を指定します（例：180）
                                          height: 40, // 高さを固定
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.black, width: 2.0), // 黒線で囲む
                                          ),
                                          alignment: Alignment.center, // テキストを中央に配置
                                          child: () {
                                            // ... (この中のRichTextなどの部分は変更なし)
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
                                                style: baseStyle.copyWith(fontSize: 20),
                                              );
                                            }
                                          }(),
                                        ),
                                      ],
                                    ),

                                  if (hoshikiToDisplay.isNotEmpty)
                                    const SizedBox(height: 8),

                                  // 下の部分：購入詳細カード
                                  PurchaseDetailsCard(
                                    parsedResult: _parsedResult!,
                                    betType: overallMethod,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 発売所情報を表示する新しいコンテナ
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
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => QRScannerPage(
                              scanMethod: 'camera',
                              savedListKey: widget.savedListKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('続けてカメラで登録'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => GalleryQrScannerPage(
                              scanMethod: 'gallery',
                              savedListKey: widget.savedListKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ギャラリーから登録'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
