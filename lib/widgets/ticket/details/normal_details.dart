// lib/widgets/ticket/details/normal_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/horse_number_box.dart';

/// 通常投票のレイアウト
Widget buildNormalDetails(Map<String, dynamic> detail, String currentBetType, RaceResult? raceResult) {
  final String shikibetsuId = detail['式別'] ?? '';
  // 式別IDから日本語名を取得（ID・日本語文字列どちらでも対応できるようフォールバック追加）
  final String shikibetsu = bettingDict[shikibetsuId] ?? shikibetsuId;

  String currentSymbol = getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);
  final dynamic horseNumbers = detail['馬番'];
  final int horseCount = horseNumbers is List ? horseNumbers.length : 1;
  final int? kingaku = detail['購入金額'];

  Widget horseDisplayWidget;
  bool isHorseNameLayoutApplied = false; // ★単勝・複勝で馬名2行レイアウトが適用されたかどうかのフラグ

  if (shikibetsu == '3連単' && currentBetType == '通常' && horseNumbers is List) {
    // (既存の3連単の処理はそのまま)
    final List<Map<String, dynamic>> groupsData = (horseNumbers as List).cast<int>().map((horseNum) {
      return {'horseNumbers': [horseNum]};
    }).toList();

    horseDisplayWidget = buildHorizontalGroupLayout(
      groupsData,
      isFormation: false,
      shikibetsu: shikibetsu,
      betType: currentBetType,
    );
  } else {
    // 単勝・複勝で馬名が表示されるかどうかを判定
    final bool hasHorseName = (shikibetsu == '単勝' || shikibetsu == '複勝') && raceResult != null;

    // 馬番枠ウィジェット生成（馬名表示時は正方形/横長枠スタイルを適用）
    final Widget horseNumbersDisplay = Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...buildHorseNumberDisplay(
          horseNumbers,
          symbol: currentSymbol,
          horseCountForSizing: horseCount,
          isHorseNameStyle: hasHorseName, // ★馬名が表示される場合は正方形/横長枠を適用
        )
      ],
    );

    if (hasHorseName) {
      String? horseNameToDisplay;
      try {
        // ★修正1: horseNumbers を安全に unwrap（リストまたは単一数値に対応）
        final int horseNumberInt = (horseNumbers is List ? horseNumbers[0] : horseNumbers) as int;
        final String horseNumberString = horseNumberInt.toString();
        final horseData = raceResult.horseResults.firstWhere(
              (h) => h.horseNumber.trim() == horseNumberString,
        );
        horseNameToDisplay = horseData.horseName;
      } catch (e) {
        // Not found
      }

      if (horseNameToDisplay != null) {
        isHorseNameLayoutApplied = true; // 2行レイアウト適用済み

        // [修正] 実物馬券に合わせ、各行に高さを与えて中身を行の高さまで拡大する (v.2026.9.14+26091401)
        // 行の高さを決めてから中身を FittedBox で合わせることで、買い目が1〜5点のどれでも
        // 同じ比率のまま表示できる（頭数ごとの分岐が不要になる）
        const double firstLineHeight = 30.0;   // 1行目（馬番枠＋馬名）の高さ
        const double amountLineHeight = 34.0;  // 2行目（☆＋金額＋円）の高さ

        final TextStyle amountStyle = ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0);
        final TextStyle horseNameStyle = ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16); // ★fontSize: 16pt (最長9文字収まるサイズ)

        // 【1行目】馬番枠 ＋ 馬名（左寄せ ＆ 馬名の横幅を 80% に長体化）
        // [修正] FittedBox(contain) で行の高さまで拡大する。
        // 馬名が長い場合は横幅が上限になるため、9文字でもはみ出さない (v.2026.9.14+26091401)
        final Widget firstLine = SizedBox(
          height: firstLineHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,                    // 左寄せ
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                horseNumbersDisplay,
                const SizedBox(width: 4.0),
                // [修正] 馬名の縦高さ(100%)を維持したまま横幅のみ 80% (0.8) にスリム化 (v.2026.9.14+26091401)
                Transform.scale(
                  scaleX: 0.8,
                  alignment: Alignment.centerLeft,
                  child: Text(horseNameToDisplay, style: horseNameStyle),
                ),
              ],
            ),
          ),
        );

        // 【2行目】☆（縦中央）＋ 金額（行の高さいっぱいに縦長・隙間なし）＋ 円（下端）
        Widget amountLine = const SizedBox(height: amountLineHeight);
        if (kingaku != null && currentBetType == '通常') {
          amountLine = SizedBox(
            height: amountLineHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,         // 右寄せ
              crossAxisAlignment: CrossAxisAlignment.end,       // 下端揃え（「円」がここに来る）
              children: [
                // [修正] ☆ と金額数値の間の不要な余白を排除し、密着させて縦長に拡大 (v.2026.9.14+26091401)
                Transform.scale(
                  scaleX: 0.75,                                 // 横方向の圧縮率（長体の強さ）
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.fitHeight,                      // 行の高さに合わせて100%拡大
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15.0), // ☆を縦中央に持ち上げる
                          child: Text(
                            getStars(kingaku),
                            style: ticketMincho(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 45,                    // 基準文字サイズ
                            ),
                          ),
                        ),
                        Text(
                          '$kingaku',
                          style: ticketGothic(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 100,                      // 設計上の基準値。実サイズは行の高さが決める
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('円', style: amountStyle),            // 単位「円」
              ],
            ),
          );
        }

        // [修正] 実物馬券には行間が無いため、1行目と2行目の間の余白を削除 (v.2026.9.14+26091401)
        horseDisplayWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,       // 子要素の横幅を表示領域いっぱいに広げる
          children: [
            firstLine,                                          // 1行目: 馬番枠 ＋ 馬名
            amountLine,                                         // 2行目: 縦長数字の金額行
          ],
        );
      } else {
        horseDisplayWidget = horseNumbersDisplay;
      }
    } else {
      horseDisplayWidget = horseNumbersDisplay;
    }
  }

  // 馬名表示の2行レイアウトが適用された場合は、Column 自体が幅いっぱいの表示領域を持つため
  // 外側で Row に包むと無限幅エラーが発生する。そのため Column を直接返却する。
  if (isHorseNameLayoutApplied) {
    return horseDisplayWidget;                                 // 2行レイアウト用 Column を直接返却
  }

  // 馬名なし/連勝式の場合は、馬番と金額を Row で横並びにして結合する
  Widget amountDisplay = const SizedBox.shrink();
  if (kingaku != null && currentBetType == '通常') {
    final TextStyle starStyle = ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10); // 「☆」の文字サイズ
    final TextStyle amountNumberStyle = ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0); // 金額数値の文字サイズ
    final TextStyle amountUnitStyle = ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0); // 単位「円」の文字サイズ
    amountDisplay = Row(
      mainAxisSize: MainAxisSize.min,                           // 横幅を最小限に抑える
      crossAxisAlignment: CrossAxisAlignment.baseline,          // ベースライン揃え
      textBaseline: TextBaseline.alphabetic,                 // ベースライン指定
      children: [
        const SizedBox(width: 16.0),                            // 馬番と金額の間の横余白 (16px)
        Text(getStars(kingaku), style: starStyle),            // 伏せ字「☆☆☆」
        // ★通常横並び時の金額数字も実物馬券に合わせて「縦長・スリム（長体）」に伸ばす
        Transform.scale(
          scaleY: 1.25,                                         // 縦方向に 1.25 倍引き伸ばす
          scaleX: 0.85,                                         // 横方向に 0.85 倍引き締める（スリム化）
          child: Text('$kingaku', style: amountNumberStyle),         // 金額数値 (例: 5000)
        ),
        Text('円', style: amountUnitStyle),                       // 単位「円」
      ],
    );
  }

  // 最終的に結合して返却
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      horseDisplayWidget,
      amountDisplay,
    ],
  );
}
