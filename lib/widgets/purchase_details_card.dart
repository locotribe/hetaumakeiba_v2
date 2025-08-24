// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart'; // 組合せ計算ロジックなどをインポート

// 購入詳細情報を表示するためのStatelessWidget
class PurchaseDetailsCard extends StatelessWidget {
  // レースの解析結果全体を格納するMap
  final Map<String, dynamic> parsedResult;
  // '通常', '応援馬券', 'ボックス'などの購入方法を示す文字列
  final String betType;

  // コンストラクタ
  const PurchaseDetailsCard({
    Key? key,
    required this.parsedResult, // 解析結果は必須
    required this.betType,      // 購入方法は必須
  }) : super(key: key);

  // 金額に応じて'☆'マークを生成するメソッド
  // 主に各組合せの単価表示に使用
  String _getStars(int amount) {
    String amountStr = amount.toString(); // 金額を文字列に変換
    int numDigits = amountStr.length;    // 金額の桁数を取得
    // 桁数に応じて☆の数を変える
    if (numDigits >= 6) {
      return ''; // 6桁以上は表示しない
    } else if (numDigits == 5) {
      return '☆'; // 5桁 (例: 10,000円)
    } else if (numDigits == 4) {
      return '☆☆'; // 4桁 (例: 1,000円)
    } else if (numDigits == 3) {
      return '☆☆☆'; // 3桁 (例: 100円)
    }
    return ''; // それ以外は表示しない
  }

  // 合計金額に応じて'★'マークを生成するメソッド
  String _getTotalAmountStars(int amount) {
    String amountStr = amount.toString(); // 合計金額を文字列に変換
    int numDigits = amountStr.length;    // 合計金額の桁数を取得
    // 桁数に応じて★の数を変える
    if (numDigits >= 7) {
      return ''; // 7桁以上は表示しない
    } else if (numDigits == 6) {
      return '★'; // 6桁 (例: 100,000円)
    } else if (numDigits == 5) {
      return '★★'; // 5桁 (例: 10,000円)
    } else if (numDigits == 4) {
      return '★★★'; // 4桁 (例: 1,000円)
    } else if (numDigits == 3) {
      return '★★★★'; // 3桁 (例: 100円)
    }
    return ''; // それ以外は表示しない
  }

  // 式別（馬券の種類）と購入方法に応じて、馬番間の記号を返すメソッド
  String _getHorseNumberSymbol(String shikibetsu, String betType, {String? uraStatus}) {
    // ウラ指定がある場合は、両方向の矢印を返す
    if (uraStatus == 'あり') {
      return '◀ ▶';
    }

    // 通常購入の場合の記号を決定
    if (betType == '通常') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') {
        return '▶'; // 着順が重要な場合は右向き矢印
      } else if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') {
        return '-'; // 着順が関係ない組合せはハイフン
      } else if (shikibetsu == 'ワイド') {
        return '◆'; // ワイドはひし形
      }
    }
    return ''; // ボックスやながしなど、他の購入方法では記号を表示しない
  }

  // 馬番リストから、枠付きの馬番表示ウィジェットのリストを生成するメソッド
  List<Widget> _buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = '', double? fontSize}) {
    List<Widget> widgets = []; // 生成したウィジェットを格納するリスト
    // フォントサイズに基づいて馬番ボックスの幅を動的に計算
    final double dynamicWidth = (fontSize ?? 16.0) * 1.8;

    List<int> numbersToProcess = []; // 処理対象の馬番を格納するリスト

    // horseNumbersがリストか単一の数値かに応じて処理を分岐
    if (horseNumbers is List) {
      // リストの場合は、要素をint型に変換して追加
      numbersToProcess.addAll(horseNumbers.cast<int>());
    } else if (horseNumbers is int) {
      // 単一の数値の場合は、そのまま追加
      numbersToProcess.add(horseNumbers);
    }

    // 処理対象の馬番リストをループ処理
    for (int i = 0; i < numbersToProcess.length; i++) {
      // 枠線で囲まれた馬番テキストウィジェットを追加
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0), // 左右に少し余白
          child: Container(
            width: dynamicWidth, // 動的に計算した幅
            alignment: Alignment.center, // 中央揃え
            padding: const EdgeInsets.symmetric(vertical: 2.0), // 上下に少し余白
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black), // 黒い枠線
            ),
            child: Text(
              numbersToProcess[i].toString(), // 馬番を文字列として表示
              style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
      // 記号が指定されていて、かつ最後の馬番でなければ、記号ウィジェットを追加
      if (symbol.isNotEmpty && i < numbersToProcess.length - 1) {
        widgets.add(
          Text(symbol, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        );
      }
    }
    return widgets; // 生成されたウィジェットのリストを返す
  }

  // 馬番の数に応じてフォントサイズを調整するメソッド
  // 多くの馬番を狭いスペースに表示させるために使用
  double _getFontSizeByHorseCount(int count) {
    if (count == 1) {
      return 18.0; // 1頭なら大きく
    } else if (count >= 2 && count <= 6) {
      return 14.0; // 2〜6頭なら中くらい
    } else {
      return 8.0; // 7頭以上なら小さく
    }
  }

  // フォーメーション表示用に、馬番を2列のグリッド形式で表示するウィジェットを生成するメソッド
  Widget _buildHorseNumberGrid(List<int> horseNumbers, double fontSize) {
    List<Widget> gridRows = []; // グリッドの各行を格納するリスト
    // 2つずつ馬番を処理して1行を生成
    for (int i = 0; i < horseNumbers.length; i += 2) {
      List<Widget> rowChildren = []; // 1行に含まれるウィジェット（馬番ボックス）

      // 1つ目の馬番ボックスを追加
      rowChildren.add(
        _buildHorseNumberDisplay(horseNumbers[i], fontSize: fontSize).first,
      );

      // 2つ目の馬番が存在する場合のみ、スペースと2つ目の馬番ボックスを追加
      if (i + 1 < horseNumbers.length) {
        rowChildren.add(const SizedBox(width: 4.0)); // ボックス間のスペース
        rowChildren.add(
          _buildHorseNumberDisplay(horseNumbers[i + 1], fontSize: fontSize).first,
        );
      }

      // 生成した行をリストに追加
      gridRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0), // 行間のスペース
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 行内で中央揃え
            mainAxisSize: MainAxisSize.min,
            children: rowChildren,
          ),
        ),
      );
    }
    // 全ての行をColumnで縦に並べて返す
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 左揃え
      children: gridRows,
    );
  }

  // 「軸」や「1着」などのラベルと馬番のグループを表示するウィジェットを生成するメソッド
  Widget _buildGroupLayoutItem(Map<String, dynamic> group, {required bool isFormation}) {
    final String label = group['label'] as String? ?? ''; // グループのラベル（例: '軸', '1着'）
    final List<int> horseNumbers = group['horseNumbers'] as List<int>? ?? []; // グループに含まれる馬番
    final double fontSize = _getFontSizeByHorseCount(horseNumbers.length); // 馬番の数に応じたフォントサイズ

    // ラベルと馬番表示をColumnで縦に並べる
    return Column(
      children: [
        // ラベルが存在する場合、ラベルテキストを表示
        if (label.isNotEmpty)
          Text(label, style: TextStyle(color: Colors.black54)),
        // ラベルが存在する場合、ラベルと馬番の間にスペースを設ける
        if (label.isNotEmpty)
          const SizedBox(height: 4),
        // isFormationフラグによって、グリッド表示か通常のWrap表示かを切り替える
        isFormation
            ? _buildHorseNumberGrid(horseNumbers, fontSize) // フォーメーションの場合は2列グリッド
            : Wrap( // それ以外（ながしなど）の場合は折り返し表示
          spacing: 4.0,       // 横方向のスペース
          runSpacing: 4.0,      // 縦方向のスペース
          alignment: WrapAlignment.center, // 中央揃え
          children: _buildHorseNumberDisplay(horseNumbers, symbol: '', fontSize: fontSize), // 記号なしで馬番を表示
        ),
      ],
    );
  }

  // 複数の馬番グループ（例: 1着、2着、3着）を水平に並べて表示するレイアウトウィジェット
  Widget _buildHorizontalGroupLayout(List<Map<String, dynamic>> groups, {required bool isFormation}) {
    // グループが空の場合は何も表示しない
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    // FittedBoxを使って、親ウィジェットの幅を超える場合に全体を縮小して表示
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min, // 内容物の幅に合わせる
        crossAxisAlignment: CrossAxisAlignment.start, // 上揃え
        // 各グループをmapで処理して、Paddingで囲んだ_buildGroupLayoutItemウィジェットのリストを生成
        children: groups.map((group) {
          return Flexible(
            child: Padding( // 各グループ間のスペースを確保
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildGroupLayoutItem(group, isFormation: isFormation), // isFormationフラグを渡してグループアイテムを生成
            ),
          );
        }).toList(),
      ),
    );
  }


  // 購入内容のデータ構造を解析し、表示用のウィジェットリストを生成する内部メソッド
  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    // 購入データのリストをMap<String, dynamic>のリストにキャスト
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();
    // ラベルの幅を固定値で定義
    const double labelWidth = 80.0;

    // ☆マークのスタイル
    final TextStyle starStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );

    // 金額表示のスタイル
    final TextStyle amountStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    // 応援馬券の場合の特殊な表示ロジック
    if (currentBetType == '応援馬券' && purchaseDetails.length >= 2) {
      // 応援馬券は単勝と複勝のセットなので、最初のデータ（単勝）を元に表示を作成
      final firstDetail = purchaseDetails[0];
      List<int> umanbanList = (firstDetail['馬番'] as List).cast<int>(); // 馬番リストを取得

      int kingaku = firstDetail['購入金額'] as int; // 金額を取得
      String starsForAmount = _getStars(kingaku);  // 金額に応じた☆マーク
      String amountValue = kingaku.toString();     // 金額の文字列

      // 応援馬券用の表示ウィジェットリストを返す
      return [
        // '馬番'ラベルと馬番の表示
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text('馬番', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end,),
            ),
            Expanded(
              child: Wrap(children: [..._buildHorseNumberDisplay(umanbanList, symbol: '')],),
            ),
          ],
        ),
        // '各 xxx円' の表示
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('各', style: amountStyle,),
                Text(starsForAmount, style: starStyle,),
                Text('${amountValue}円', style: amountStyle,),
              ],
            ),
          ),
        ),
        // '単勝 xxx円' の表示
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('単勝 ', style: amountStyle,),
                Text(starsForAmount, style: starStyle,),
                Text('${amountValue}円', style: amountStyle,),
              ],
            ),
          ),
        ),
        // '複勝 xxx円' の表示
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('複勝 ', style: amountStyle,),
                Text(starsForAmount, style: starStyle,),
                Text('${amountValue}円', style: amountStyle,),
              ],
            ),
          ),
        ),
      ];
    } else {
      // 応援馬券以外の場合のロジック
      // 各購入詳細をループ処理してウィジェットを生成
      return purchaseDetails.map((detail) {
        final String shikibetsuId = detail['式別'] ?? ''; // 式別ID
        final String shikibetsu = bettingDict[shikibetsuId] ?? ''; // 式別名（例: '馬単'）
        int? kingaku = detail['購入金額']; // 購入金額
        String uraDisplay = (detail['ウラ'] == 'あり') ? 'ウラ: あり' : ''; // ウラ指定の表示文字列
        int combinations = detail['組合せ数'] as int? ?? 0; // 組合せ数

        // 金額の前に「各組」を表示するかどうかを判定
        bool isComplexCombinationForPrefix = (currentBetType == 'ボックス' || currentBetType == 'ながし' || currentBetType == 'フォーメーション');

        String starsForPrefix = ''; // 金額用の☆マーク
        String amountValueForPrefix = ''; // 金額の文字列
        if (kingaku != null) {
          starsForPrefix = _getStars(kingaku);
          amountValueForPrefix = kingaku.toString();
        }

        List<Widget> detailWidgets = []; // この購入詳細のウィジェットを格納するリスト
        bool amountHandledInline = false; // 金額表示が他の部分で処理されたかどうかのフラグ

        // 購入方法と式別に応じて馬番の表示方法を分岐
        // 3連単フォーメーションの場合
        if (shikibetsu == '3連単' && currentBetType == 'フォーメーション') {
          final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final List<Map<String, dynamic>> groupsData = [
            {'label': '1着', 'horseNumbers': horseGroups.length > 0 ? horseGroups[0] : <int>[]},
            {'label': '2着', 'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
            {'label': '3着', 'horseNumbers': horseGroups.length > 2 ? horseGroups[2] : <int>[]},
          ];
          detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: true));
          // 3連複フォーメーションの場合
        } else if (shikibetsu == '3連複' && currentBetType == 'フォーメーション') {
          final List<List<int>> horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final List<Map<String, dynamic>> groupsData = [];
          for (int i = 0; i < horseGroups.length; i++) {
            groupsData.add({'label': '${i + 1}頭目', 'horseNumbers': horseGroups[i]});
          }
          detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: true));
          // 馬単フォーメーションの場合
        } else if (shikibetsu == '馬単' && currentBetType == 'フォーメーション') {
          final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
          final List<Map<String, dynamic>> groupsData = [
            {'label': '1着', 'horseNumbers': horseGroups.length > 0 ? horseGroups[0] : <int>[]},
            {'label': '2着', 'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
          ];
          detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: true));
          // ながしの場合
        } else if (currentBetType == 'ながし') {
          // 3連単ながしの場合 (1着、2着、3着のグループ)
          if (shikibetsu == '3連単') {
            final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            final List<Map<String, dynamic>> groupsData = [];
            final labels = ['1着', '2着', '3着'];
            for (int i = 0; i < horseGroups.length; i++) {
              if (horseGroups[i].isNotEmpty) { // 空のグループは表示しない
                groupsData.add({'label': labels[i], 'horseNumbers': horseGroups[i]});
              }
            }
            detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: false));
            // その他のながしの場合 (軸、相手のグループ)
          } else {
            final List<Map<String, dynamic>> groupsData = [];
            if (detail.containsKey('軸')) {
              groupsData.add({'label': '軸', 'horseNumbers': (detail['軸'] as List).cast<int>()});
            }
            if (detail.containsKey('相手')) {
              groupsData.add({'label': '相手', 'horseNumbers': (detail['相手'] as List).cast<int>()});
            }
            detailWidgets.add(_buildHorizontalGroupLayout(groupsData, isFormation: false));
          }
          // 上記以外の通常、ボックスなどの場合
        } else {
          // 馬番間の記号を取得
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);
          // 通常の馬番表示ウィジェットを追加
          detailWidgets.add(
              Padding(
                padding: const EdgeInsets.only(left: 0.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap( // 折り返し表示
                    spacing: 4.0, runSpacing: 4.0,
                    children: [..._buildHorseNumberDisplay(detail['馬番'], symbol: currentSymbol)],
                  ),
                ),
              ],
            ),
          ));
        }

        // 組合せ数の表示ロジック
        // パーサー側で整形された表示用文字列があればそれを優先
        String combinationDisplayString = detail['組合せ数_表示用'] as String? ?? '';
        // 表示用文字列がなく、組合せ数が1より大きい場合は、数値をそのまま文字列にする
        if (combinationDisplayString.isEmpty && combinations > 1) {
          combinationDisplayString = '$combinations';
        }

        // 組合せ数の表示文字列があれば、ウィジェットを追加
        if (combinationDisplayString.isNotEmpty) {
          detailWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 0.0, top: 0.0, bottom: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // 右揃え
                children: [
                  Text(
                    '組合せ数 $combinationDisplayString', // "組合せ数 10通り" のように表示
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        // 共通の金額表示ロジック
        if (kingaku != null && !amountHandledInline) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight, // 右揃え
                    child: FittedBox( // はみ出ないように縮小
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // マルチ指定がある場合は「マルチ」ラベルを表示
                          if (detail['マルチ'] == 'あり')
                            Container(
                              margin: const EdgeInsets.only(right: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                              decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(0))),
                              child: const Text('マルチ', style: TextStyle(color: Colors.white, fontSize: 22, height: 1)),
                            ),
                          // 必要に応じて「各組」を表示
                          Text(isComplexCombinationForPrefix ? '各組' : '', style: amountStyle),
                          // ☆マーク
                          Text(starsForPrefix, style: starStyle),
                          // 金額
                          Text('${amountValueForPrefix}円', style: amountStyle),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ));
        }

        // ウラ指定がある場合、その情報を表示
        if (uraDisplay.isNotEmpty) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(uraDisplay, style: TextStyle(color: Colors.black54)),
          ));
        }

        // 生成したすべてのウィジェットをColumnで縦に並べて返す
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 左揃え
          children: detailWidgets,
        );
      }).toList();
    }
  }


  // このウィジェットのUIを構築するメインのメソッド
  @override
  Widget build(BuildContext context) {
    // 解析結果に'購入内容'キーがなければ、何も表示しない
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }

    // 合計金額を取得（存在しない場合は0）
    final int totalAmount = parsedResult['合計金額'] as int? ?? 0;

    // 合計金額に応じた★マークと文字列を生成
    String totalStars = _getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();

    // 合計金額用の★マークのスタイル
    final TextStyle totalStarStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );

    // 合計金額のテキストスタイル
    final TextStyle totalAmountTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    // 全体のレイアウトをColumnで構成
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 全体を左揃え
      children: [
        // 購入詳細部分を表示
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // _buildPurchaseDetailsInternalを呼び出して、購入詳細のウィジェットリストを取得
          children: _buildPurchaseDetailsInternal(parsedResult['購入内容'], betType),
        ),
        // 合計金額部分を表示
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight, // 右揃え
                child: FittedBox( // はみ出ないように縮小
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // "合計"のテキスト
                      Text('合計　', style: totalAmountTextStyle,),
                      // ★マーク
                      Text(totalStars, style: totalStarStyle,),
                      // 合計金額
                      Text('${totalAmountString}円', style: totalAmountTextStyle,),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}