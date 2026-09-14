// lib/widgets/ticket/details/ouen_baken_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/horse_number_box.dart';

/// 応援馬券のレイアウト
List<Widget> buildOuenBakenDetails(List<Map<String, dynamic>> purchaseDetails, RaceResult? raceResult) {
  if (purchaseDetails.isEmpty) return [];

  final detail = purchaseDetails.first;
  final horseNumberData = detail['馬番'];
  final horseNumber = (horseNumberData is List ? horseNumberData[0] : horseNumberData) as int;
  final int? kingaku = detail['購入金額'];

  String horseNameToDisplay = 'キミノアイバ'; // デフォルト値
  if (raceResult != null) {
    try {
      final horseNumberString = horseNumber.toString();
      final horseData = raceResult.horseResults.firstWhere(
            (h) => h.horseNumber.trim() == horseNumberString,
      );
      horseNameToDisplay = horseData.horseName;
    } catch (e) {
      // レース結果に馬が見つからない場合 (除外など) はデフォルト名のまま
    }
  }

  final Widget horseNumberWidget = buildHorseNumberDisplay(horseNumber, horseCountForSizing: 1).first;

  const TextStyle amountStyle = TextStyle(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 14,
    height: 1.0,);
  const TextStyle kiminoAibaStyle = TextStyle(
      color: Colors.black,
      fontWeight:
      FontWeight.bold,
      fontSize: 13);

  // 1行目: 馬番とテキスト
  final Widget firstLine = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      horseNumberWidget,
      Text(' $horseNameToDisplay', style: kiminoAibaStyle),
    ],
  );

  // 2行目: 金額
  Widget amountLine = const SizedBox.shrink();
  if (kingaku != null) {
    const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    amountLine = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('各', style: amountStyle),
        Text(getStars(kingaku), style: starStyle),
        Text('$kingaku円', style: amountStyle),
      ],
    );
  }

  return [
    IntrinsicWidth(
      // [修正] Column(stretch)がFittedBoxの無制約(幅Infinity)を直接受け取り
      // BoxConstraints forces an infinite width. で例外になるため、
      // IntrinsicWidthで有限の横幅に変換してからstretchさせる (v.13.41.1)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          firstLine,
          amountLine,
        ],
      ),
    )
  ];
}
