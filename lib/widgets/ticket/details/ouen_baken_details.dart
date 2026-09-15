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

  // 馬番を囲む四角枠ウィジェット（馬名表示スタイルフラグ isHorseNameStyle: true を指定して正方形/横長枠に）
  final Widget horseNumberWidget = buildHorseNumberDisplay(
    horseNumber,
    horseCountForSizing: 1,
    isHorseNameStyle: true, // ★馬名あり馬券スタイルの四角枠（高さ＝馬名と同等）を適用
  ).first;

  // 「各100円」行の「各」「円」のフォントスタイル（文字サイズ、太さ、色など）
  const TextStyle amountStyle = TextStyle(
    color: Colors.black,        // 文字色: 黒
    fontWeight: FontWeight.bold,// 文字の太さ: 太字
    fontSize: 14,               // ★「各」「100円」の文字サイズ (14pt)
    height: 1.0,                // 行の高さ
  );

  // 馬名（例: スターアニス）のフォントスタイル
  const TextStyle kiminoAibaStyle = TextStyle(
    color: Colors.black,        // 文字色: 黒
    fontWeight: FontWeight.bold,// 文字の太さ: 太字
    fontSize: 18,               // ★馬名の文字サイズ (18pt)
  );

  // 【1行目】馬番の四角枠 ＋ 馬名テキスト（表示領域の左端に配置）
  final Widget firstLine = Row(
    mainAxisSize: MainAxisSize.max,           // 横幅を表示領域いっぱいに確保
    mainAxisAlignment: MainAxisAlignment.start, // 馬番と馬名を「左寄せ」に配置
    children: [
      horseNumberWidget,                       // [馬番の四角枠]
      Text(' $horseNameToDisplay', style: kiminoAibaStyle), // [馬名テキスト]
    ],
  );

  // 【2行目】金額表示「各☆☆☆100円」（表示領域の一番右端に配置）
  Widget amountLine = const SizedBox.shrink();
  if (kingaku != null) {
    // 伏せ字「☆」のフォントスタイル
    const TextStyle starStyle = TextStyle(
      color: Colors.black,        // 文字色: 黒
      fontWeight: FontWeight.bold,// 文字の太さ: 太字
      fontSize: 10,               // ★伏せ字「☆」の文字サイズ (10pt)
    );

    amountLine = Row(
      mainAxisSize: MainAxisSize.max,           // 横幅を表示領域いっぱいに確保
      mainAxisAlignment: MainAxisAlignment.end,    // 金額を「一番右端」に配置
      crossAxisAlignment: CrossAxisAlignment.baseline, // 「円」と数字のベースライン（下位置）を揃える
      textBaseline: TextBaseline.alphabetic,       // ベースライン指定
      children: [
        const Text('各', style: amountStyle),    // 「各」テキスト
        Text(getStars(kingaku), style: starStyle), // 伏せ字「☆☆☆」
        // ★金額数字部分のみを実物馬券同様に「縦長・スリム（長体）」に伸ばす処理
        Transform.scale(
          scaleY: 1.25,                           // 縦方向に 1.25 倍引き伸ばす
          scaleX: 0.85,                           // 横方向に 0.85 倍引き締める（スリム化）
          child: Text('$kingaku', style: amountStyle), // 金額数値 (例: 100)
        ),
        const Text('円', style: amountStyle),         // 単位「円」
      ],
    );
  }

  return [
    // 1行目（馬名：左寄せ）と2行目（各100円：右寄せ）を縦に並べるメインカラム
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // 子要素の横幅を表示領域いっぱいに広げる
      children: [
        firstLine,                   // 1行目: 馬番＋馬名
        const SizedBox(height: 2.0), // 1行目と2行目の間の縦余白 (2px)
        amountLine,                  // 2行目: 各◯円
      ],
    )
  ];
}
