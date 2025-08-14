// lib/logic/paste_parser.dart

import 'package:flutter/services.dart';

// 解析結果を保持するためのデータクラス
class PasteParseResult {
  final int? horseNumber;
  final String horseName;
  final double? odds;
  final int? popularity;
  final String? horseWeight;

  PasteParseResult({
    this.horseNumber,
    required this.horseName,
    this.odds,
    this.popularity,
    this.horseWeight,
  });
}

class PasteParser {
  // クリップボードからテキストを非同期で取得する静的メソッド
  static Future<String> getTextFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    return clipboardData?.text ?? '';
  }

  // ペーストされた出馬表テキストを解析するメインの関数
  static List<PasteParseResult> parseShutubaDataFromPastedText(String text) {
    final List<PasteParseResult> results = [];
    // 行を分割し、前後の空白を除去し、空行や区切り線を除外
    final lines = text.split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '--' && !e.startsWith('編集') && !e.contains('◎'))
        .toList();

    for (int i = 0; i < lines.length; i++) {
      final line1 = lines[i];

      // パターン1: 枠順確定後など、1行に全ての情報が含まれる形式
      // 例: "1 1 ホウオウビスケッツ 牡5 58.0 岩田康 3.9 1 (美)奥村武 480(+2)"
      final singleLineRegExp = RegExp(
          r'^\s*\d{1,2}\s+'      // 枠番
          r'(\d{1,2})\s+'          // 馬番 (グループ1)
          r'(.+?)\s+'             // 馬名 (グループ2)
          r'[牡牝セせん]\d\s+'   // 性齢
          r'[\d\.]+\s+'            // 斤量
          r'.+?\s+'                // 騎手
          r'([\d\.]+)\s+'          // 単勝オッズ (グループ3)
          r'(\d+)'                 // 人気 (グループ4)
          r'(?:\s+.+?\s+(\d{3}\(.+?\)))?\s*$' // 調教師と馬体重(任意 グループ5)
      );

      var match = singleLineRegExp.firstMatch(line1);
      if (match != null) {
        try {
          results.add(PasteParseResult(
            horseNumber: int.parse(match.group(1)!),
            horseName: match.group(2)!.trim(),
            odds: double.parse(match.group(3)!),
            popularity: int.parse(match.group(4)!),
            horseWeight: match.group(5),
          ));
          continue; // マッチしたので次の行の処理へ
        } catch (e) {
          // パースに失敗した場合は無視して次の行へ
        }
      }

      // パターン2: 枠順確定前など、2行で1頭の情報が構成される形式
      if (i + 1 < lines.length) {
        final line2 = lines[i + 1];
        // line1 (馬名): アウスヴァール
        // line2 (データ): セ758.0古川吉栗東昆174.316
        final twoLineRegExp = RegExp(
            r'^[牡牝セせん]\d'      // 性齢
            r'[\d\.]+'            // 斤量
            r'.+?'                // 騎手、調教師など
            r'([\d\.]+)'           // 単勝オッズ (グループ1)
            r'(\d+)$'              // 人気 (グループ2)
        );
        match = twoLineRegExp.firstMatch(line2);

        // line2がデータ行のパターンに一致し、かつline1がデータ行のパターンに一致しないことを確認
        if (match != null && !twoLineRegExp.hasMatch(line1) && !singleLineRegExp.hasMatch(line1)) {
          try {
            results.add(PasteParseResult(
              horseNumber: null, // この形式では馬番は取得不可
              horseName: line1.trim(),
              odds: double.parse(match.group(1)!),
              popularity: int.parse(match.group(2)!),
              horseWeight: null, // この形式では馬体重は取得不可
            ));
            i++; // 2行分処理したのでインデックスを1つ余分に進める
            continue; // マッチしたので次のループの処理へ
          } catch(e) {
            // パースに失敗した場合は無視して次の行へ
          }
        }
      }
    }
    return results;
  }
}