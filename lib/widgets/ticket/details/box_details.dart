// lib/widgets/ticket/details/box_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/normal_details.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';

/// ボックス投票のグリッド内のセル（馬番または☆）を1つ生成する
Widget buildBoxHorseNumberCell(dynamic content, {required double scaleFactor}) {
  const double boxSize = 38.0;
  final double containerHeight = boxSize * scaleFactor;

  if (content is int) {
    // 馬番の場合
    return Expanded(
      child: Center(
        child: Container(
          width: boxSize,
          height: containerHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
          child: Transform.scale(
            scaleY: scaleFactor,
            alignment: Alignment.center,
            child: FittedBox(
              // 高さを基準にスケールする
              fit: BoxFit.fitHeight,
              child:
              // 二桁の場合のみ横幅を圧縮する
              Transform.scale(
                // content(馬番)が9より大きい(つまり二桁)なら横幅を85%に圧縮
                scaleX: content > 9 ? 0.85 : 1.0,
                scaleY: content > 9 ? 1.4 : 1.0,
                child: Text(
                  content.toString(),
                  style: ticketGothic(
                    fontSize: 43,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } else {
    // ☆を表示する部分
    return Expanded(
      child: Center(
        child: SizedBox(
          width: boxSize,
          height: containerHeight,
          child: Center(
            child: Text('☆', style: ticketMincho(fontSize: boxSize * 0.6, color: Colors.black)),
          ),
        ),
      ),
    );
  }
}

/// ボックス投票用のグリッドレイアウト全体を生成する
Widget buildBoxGridLayout(List<int> horseNumbers) {
  const int itemsPerRow = 5;
  final int horseCount = horseNumbers.length;

  // 馬の数に応じて3段階のスケール比率を決定 ★★★
  double scaleFactor;
  if (horseCount < 6) {
    scaleFactor = 1.5;   // 5頭以下は最も縦長
  } else if (horseCount < 12) {
    scaleFactor = 1.25;  // 6～11頭は少し縦長
  } else {
    scaleFactor = 1.0;   // 12頭以上は正方形
  }

  const double cellWidth = 38.0 + 4.0;
  const double totalWidth = cellWidth * itemsPerRow;

  List<Widget> rows = [];

  // 1. 馬番を表示するための行を生成する
  if (horseCount > 0) {
    final int horseRows = (horseCount / itemsPerRow).ceil();
    for (int i = 0; i < horseRows; i++) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < itemsPerRow; j++) {
        final int index = i * itemsPerRow + j;
        if (index < horseCount) {
          // スケール比率を渡してセルを生成
          rowChildren.add(buildBoxHorseNumberCell(horseNumbers[index], scaleFactor: scaleFactor));
        } else {
          // 行内の☆も、同じ行の馬番と高さを揃えるためにスケール比率を渡す
          rowChildren.add(buildBoxHorseNumberCell('☆', scaleFactor: scaleFactor));
        }
      }
      rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(children: rowChildren),
          )
      );
    }
  }

  // 新しい☆の表示ルール (5頭以下の場合のみ☆の行を追加)
  if (horseCount > 0 && horseCount <= 5) {
    List<Widget> starRowChildren = [];
    for (int j = 0; j < itemsPerRow; j++) {
      // ☆だけの行は常に正方形(スケール1.0)で表示
      starRowChildren.add(buildBoxHorseNumberCell('☆', scaleFactor: 1.0));
    }
    rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(children: starRowChildren),
        )
    );
  }

  return SizedBox(
    width: totalWidth,
    child: Column(children: rows),
  );
}

/// ボックス投票のレイアウト
Widget buildBoxDetails(Map<String, dynamic> detail, RaceResult? raceResult) {
  final dynamic horseNumbers = detail['馬番'];
  if (horseNumbers is List) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [buildBoxGridLayout(horseNumbers.cast<int>()), const SizedBox.shrink()],
    );
  }
  return buildNormalDetails(detail, 'ボックス', raceResult);
}
