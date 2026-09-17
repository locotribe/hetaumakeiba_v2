// lib/widgets/ticket/parts/horse_number_box.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';

// 馬番の頭数および馬名表示スタイルの有無に応じて、馬番を囲む四角枠のサイズ（幅・高さ）を決定する関数
Size getBoxSizeByHorseCount(
  int count, {
  bool isHorseNameStyle = false, // ★馬名が表示される馬券スタイルかどうか
  int horseNumber = 1,           // ★馬番号（桁数による枠幅切り替え用）
}) {
  if (isHorseNameStyle) {
    const double baseHeight = 24.0;
    // 1桁(1〜9)なら正方形に近い幅 (高さ×1.05)、2桁(10〜18)なら横長枠 (高さ×1.25)
    final double width = (horseNumber >= 10) ? baseHeight * 1.25 : baseHeight * 1.05;
    return Size(width, baseHeight);
  }

  // 【従来の連勝式馬券用】
  if (count == 1) {
    return const Size(35.0, 40.0 * 1.4); // 【大】1頭のみ（縦長）
  } else if (count >= 2 && count <= 6) {
    return const Size(25.0, 25.0 * 1.4); // 【中】2〜6頭（縦長）
  } else {
    // ★ 【小】7頭以上は横幅をしっかり確保し、高さを抑えて「横長枠」にする！
    return const Size(23.0, 18.0); // 例: 横幅 18.0 / 高さ 14.0 （横長）
  }
}

// 馬番枠ウィジェットを生成するメイン関数
List<Widget> buildHorseNumberDisplay(
  dynamic horseNumbers, {
  String symbol = '',
  int? horseCountForSizing,
  bool isHorseNameStyle = false, // ★追加: 馬名表示スタイルフラグ (デフォルトは false)
  Key? key,
}) {
  List<Widget> widgets = [];
  final int count = horseCountForSizing ?? (horseNumbers is List ? horseNumbers.length : 1);

  List<int> numbersToProcess = [];

  if (horseNumbers is List) {
    numbersToProcess.addAll(horseNumbers.cast<int>());
  } else if (horseNumbers is int) {
    numbersToProcess.add(horseNumbers);
  }

  for (int i = 0; i < numbersToProcess.length; i++) {
    final int currentNum = numbersToProcess[i];
    final String numberStr = currentNum.toString();

    // 馬名表示スタイルかどうかに合わせて四角枠サイズを取得
    final Size boxSize = getBoxSizeByHorseCount(
      count,
      isHorseNameStyle: isHorseNameStyle,
      horseNumber: currentNum,
    );

    // ★枠の中の数字の「フォントサイズ」決定
    final double fontSize = isHorseNameStyle
        ? boxSize.height * 0.85 // 馬名スタイル時は高さの85%
        : boxSize.height * 0.93 - (count == 1 ? 0.0 : 1.0);

    // 馬番テキスト本体
    Widget numberText = Text(
      numberStr,
      maxLines: 1,
      softWrap: false,
      style: ticketGothic(
        fontSize: fontSize,         // ★馬番数字のフォントサイズ
        color: Colors.black,        // 文字色: 黒
        fontWeight: FontWeight.bold,// 太字
        height: 1.0,                // 行の高さを詰めて上下余白を最小化
      ),
    );

    // 2桁以上の馬番（例: 10番〜）の長体処理
    if (numberStr.length >= 2) {
      // 7頭以上の小枠(count >= 7)の時は scaleX を 0.88 や 0.92 に広げて数字を太く見せる！
      final double scaleXValue = isHorseNameStyle
          ? 0.85
          : (count >= 7 ? 0.90 : 0.72);

      numberText = Transform.scale(
        scaleX: scaleXValue, // ← ここを大きな値（0.88 〜 0.92 など）にする
        child: OverflowBox(
          maxWidth: boxSize.height * 1.5,
          child: numberText,
        ),
      );
    }

    // 四角い枠線（Container）の中に数字を配置
    widgets.add(
      Container(
        key: key,
        width: boxSize.width,   // ★四角枠の横幅
        height: boxSize.height, // ★四角枠の高さ
        alignment: Alignment.center, // 数字を枠の中央に配置
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black), // ★四角枠の「黒い外枠線」
        ),
        child: numberText, // 枠の中に馬番数字を入れる
      ),
    );
    if (symbol.isNotEmpty && i < numbersToProcess.length - 1) {
      widgets.add(Text(symbol, style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold)));
    }
  }
  return widgets;
}

Widget buildHorseNumberGrid(List<int> horseNumbers, {int starCount = 0}) {
  List<Widget> gridRows = [];
  final int horseCount = horseNumbers.length;
  final Size boxSize = getBoxSizeByHorseCount(horseCount);
  final List<dynamic> items = [
    ...horseNumbers,
    for (int i = 0; i < starCount; i++) '☆',
  ];

  for (int i = 0; i < items.length; i += 2) {
    List<Widget> rowChildren = [];
    rowChildren.add(buildGridCell(items[i], horseCount, boxSize));
    if (i + 1 < items.length) {
      rowChildren.add(const SizedBox(width: 2.0));
      rowChildren.add(buildGridCell(items[i + 1], horseCount, boxSize));
    }
    gridRows.add(
      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: rowChildren),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < gridRows.length; i++) ...[
        if (i > 0) const SizedBox(height: 2.0),
        gridRows[i],
      ],
    ],
  );
}

// 馬番グリッドの1セルを生成する（馬番セルまたは不足分の☆セル）
Widget buildGridCell(dynamic item, int horseCount, Size boxSize) {
  if (item is int) {
    return buildHorseNumberDisplay(item, horseCountForSizing: horseCount).first;
  }
  return buildStarCell(boxSize);
}

// 馬番セルと同じ占有領域（幅・高さ）で☆を中央配置するセル
Widget buildStarCell(Size boxSize) {
  // ★ 高さや幅が小さい小枠（7頭以上）かどうか判定
  final bool isSmallBox = boxSize.height <= 20.0;

  // ★ 小枠の時は高さの65%（小さめ）、大・中枠の時は幅の80%（大きめ）にする
  final double starFontSize = isSmallBox
      ? boxSize.height * 0.65 // ← 7頭以上の小枠のときは控えめなサイズに！
      : boxSize.width * 0.8;

  return SizedBox(
    width: boxSize.width,
    height: boxSize.height,
    child: Center(
      child: Text(
        '☆',
        textAlign: TextAlign.center,
        style: ticketMincho(
          fontSize: starFontSize, // ← 計算したフォントサイズを適用
          color: Colors.black,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    ),
  );
}

Widget buildGroupLayoutItem(Map<String, dynamic> group, {required bool isFormation, int maxCount = 0}) {
  final String label = group['label'] as String? ?? '';
  final List<int> horseNumbers = group['horseNumbers'] as List<int>? ?? [];
  final int count = horseNumbers.length;
  // 馬番が1つだけの列（軸など）は☆によるパディング対象外とする
  final bool isSingleHorse = count == 1;

  // 他列の頭数(maxCount)には依存せず、自身の頭数のみで不足数を決定する
  int missingCount = 0;
  if (!isSingleHorse) {
    int totalSlots;
    if (count <= 4) {
      // 2〜4頭は、最低4スロット（2行）保証
      totalSlots = 4;
    } else if (count >= 7 && count <= 10) {
      // JRAの特異仕様: 7〜10頭は8スロット(4行)の枠が存在せず、一律10スロット(5行)の枠が使われる
      totalSlots = 10;
    } else {
      // 5, 6, 11頭以上などは、端数が出ないように偶数スロットに丸める（奇数なら+1）
      totalSlots = count + (count % 2);
    }
    missingCount = totalSlots - count;
  }

  final Widget horseDisplayWidget = isSingleHorse
      ? buildHorseNumberDisplay(horseNumbers, horseCountForSizing: 1).first
      : isFormation
      ? buildHorseNumberGrid(horseNumbers, starCount: missingCount)
      : Wrap(
    spacing: 2.0,
    runSpacing: 2.0,
    alignment: WrapAlignment.center,
    children: [
      ...buildHorseNumberDisplay(horseNumbers, symbol: '', horseCountForSizing: horseNumbers.length),
      for (int i = 0; i < missingCount; i++)
        buildStarCell(getBoxSizeByHorseCount(horseNumbers.length)),
    ],
  );

  if (label.isNotEmpty) {
    return Column(
      children: [
        Text(label, style: ticketMincho(color: Colors.black)),
        const SizedBox(height: 4),
        horseDisplayWidget,
      ],
    );
  }
  return horseDisplayWidget;
}

Widget buildHorizontalGroupLayout(
    List<Map<String, dynamic>> groups, {
      required bool isFormation,
      required String shikibetsu,
      required String betType,
    }) {
  if (groups.isEmpty) return const SizedBox.shrink();

  final int maxCount = groups
      .map((g) => (g['horseNumbers'] as List<int>? ?? []).length)
      .fold(0, (a, b) => a > b ? a : b);

  List<Widget> children = [];
  final bool shouldShowSymbol = isFormation || (shikibetsu == '3連単' && (betType == 'ながし' || betType == '通常'));
  final String symbol = getHorseNumberSymbol(shikibetsu, betType);

  for (int i = 0; i < groups.length; i++) {
    children.add(buildGroupLayoutItem(groups[i], isFormation: isFormation, maxCount: maxCount));
    if (shouldShowSymbol && symbol.isNotEmpty && i < groups.length - 1) {
      children.add(
        Transform.scale(
          scaleX: 0.6,
          scaleY: 1.8,
          child: Text(symbol, style: ticketMincho(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: children,
  );
}
