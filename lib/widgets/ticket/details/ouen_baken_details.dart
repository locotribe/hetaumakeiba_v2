// lib/widgets/ticket/details/ouen_baken_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';
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

  // 行の高さを決めて中身を FittedBox で合わせることで、実物馬券と同じ比率のレイアウトを実現 (v.2026.9.15+26091501)
  const double firstLineHeight = 30.0;   // 1行目（馬番枠＋馬名）の高さ
  const double amountLineHeight = 34.0;  // 2行目（各＋☆＋金額＋円）の高さ

  final TextStyle amountStyle = ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0);

  // 【1行目】馬番の四角枠 ＋ 馬名テキスト（左寄せ ＆ 横幅80%に長体化）
  // FittedBoxによる相殺を防ぎ、高さ100%を保持したまま確実に横幅のみ80%に長体化する (v.2026.9.15+26091501)
  final Widget firstLine = SizedBox(
    height: firstLineHeight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // [追加] 馬番枠の左側に隙間を空け、1行目だけを右へずらす (v.2026.9.16+XXXXXXXX)
        const SizedBox(width: 4.0),
        horseNumberWidget,                               // 馬番枠（正方形/横長）
        const SizedBox(width: 4.0),
        // 馬名の縦高さ(100%)を維持したまま横幅のみ 80% (0.8) にスリム化
        Transform.scale(
          scaleX: 0.8,
          alignment: Alignment.centerLeft,
          child: Text(
            horseNameToDisplay,
            style: ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
      ],
    ),
  );

  // 【2行目】「各」＋ ☆（縦中央）＋ 金額（行の高さいっぱいに縦長・隙間なし）＋ 円（下端）
  Widget amountLine = const SizedBox(height: amountLineHeight);
  if (kingaku != null) {
    amountLine = SizedBox(
      height: amountLineHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,         // 右寄せ
        crossAxisAlignment: CrossAxisAlignment.end,       // 下端揃え（「円」がここに来る）
        children: [
          // 「各」と「☆」の間の不要な余白を完全に消去し、数字まで密着させて縦長に拡大 (v.2026.9.15+26091501)
          Transform.scale(
            scaleX: 0.75,                                 // 横方向の圧縮率（長体の強さ）
            alignment: Alignment.bottomRight,
            child: FittedBox(
              fit: BoxFit.fitHeight,                      // 行の高さに合わせて100%拡大
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '各',
                    style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 45),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0), // ☆を縦中央に持ち上げる
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

  return [
    // 1行目（馬名：左寄せ）と2行目（各100円：右寄せ）を縦に並べるメインカラム
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch, // 子要素の横幅を表示領域いっぱいに広げる
      children: [
        firstLine,                                     // 1行目: 馬番＋馬名
        amountLine,                                    // 2行目: 各◯円
      ],
    )
  ];
}
