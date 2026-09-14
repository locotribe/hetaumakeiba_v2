// lib/widgets/ticket/parts/horse_number_box.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';

// グループ内の馬番の数に応じて、馬番を囲う枠のサイズ（縦長）を決定する関数
Size getBoxSizeByHorseCount(int count) {
  // 枠の大きさを指定する場所（高さは横幅の1.35倍の縦長とする）
  // 列をまたいだ揃えではなく、頭数のみで「大・中・小」の3段階を独立して決定する
  double width;
  if (count == 1) {
    // [修正] 1頭単独ボックスの横幅を細身に調整 (v.13.40.2)
    width = 44.0; // 【大】1頭のみ
  } else if (count >= 2 && count <= 6) {
    width = 35.0; // 【中】2〜6頭
  } else {
    width = 22.0; // 【小】7頭以上（全体縮小を防ぐため、現状の25.0から少しスリム化）
  }
  return Size(width, width * 1.35);
}

List<Widget> buildHorseNumberDisplay(dynamic horseNumbers, {String symbol = '', int? horseCountForSizing, Key? key}) {
  List<Widget> widgets = [];
  final int count = horseCountForSizing ?? (horseNumbers is List ? horseNumbers.length : 1);
  final Size boxSize = getBoxSizeByHorseCount(count);

  List<int> numbersToProcess = [];

  if (horseNumbers is List) {
    numbersToProcess.addAll(horseNumbers.cast<int>());
  } else if (horseNumbers is int) {
    numbersToProcess.add(horseNumbers);
  }

  for (int i = 0; i < numbersToProcess.length; i++) {
    final String numberStr = numbersToProcess[i].toString();
    // 縦の大きさはボックスの高さを基準に確保する（横幅基準だと二桁で縮小しすぎるため）
    // [修正] 中・小サイズの馬番フォントを微調整（-1pt） (v.13.40.2)
    final double fontSize = boxSize.height * 0.88 - (count == 1 ? 0.0 : 1.0);

    Widget numberText = Text(
      numberStr,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.black,
        fontWeight: FontWeight.bold,
        height: 1.0, // 行の高さを詰めて上下の余白を最小化
      ),
    );

    // 二桁以上の馬番は、縦の大きさを保ったまま横幅のみ圧縮する「長体」にする
    if (numberStr.length >= 2) {
      numberText = Transform.scale(
        scaleX: 0.65, // バランスを見て0.63〜0.67で調整
        child: OverflowBox(
          // ボックス幅の制約を外し、Textを改行させずに1行で描画させる
          maxWidth: boxSize.height,
          child: numberText,
        ),
      );
    }

    widgets.add(
      Container(
        key: key,
        width: boxSize.width,
        height: boxSize.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: numberText,
      ),
    );
    if (symbol.isNotEmpty && i < numbersToProcess.length - 1) {
      widgets.add(Text(symbol, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
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
  return SizedBox(
    // _buildHorseNumberDisplayのセルと同じ幅にし、垂直軸のズレを防ぐ
    width: boxSize.width,
    height: boxSize.height,
    child: Center(
      child: Text(
        '☆',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: boxSize.width * 0.6,
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
        Text(label, style: const TextStyle(color: Colors.black)),
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
          scaleX: 0.5,
          scaleY: 1.5,
          child: Text(symbol, style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
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
