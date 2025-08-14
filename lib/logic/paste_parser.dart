// lib/logic/paste_parser.dart

import 'package:flutter/services.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';


// 解析結果を保持するためのデータクラス
class PasteParseResult {
  final double? odds;
  final int? popularity;

  PasteParseResult({
    this.odds,
    this.popularity,
  });
}

class PasteParser {
  // クリップボードからテキストを非同期で取得する静的メソッド
  static Future<String> getTextFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    return clipboardData?.text ?? '';
  }

  // ペーストされたテキストと、アプリ内の馬リストを基に解析するメイン関数
  static Map<String, PasteParseResult> parseDataByHorseName(String text, List<PredictionHorseDetail> horses) {
    final Map<String, PasteParseResult> resultMap = {};

    for (int i = 0; i < horses.length; i++) {
      final currentHorse = horses[i];
      final horseName = currentHorse.horseName;

      // テキスト全体から現在の馬の名前を探す
      final nameIndex = text.indexOf(horseName);
      if (nameIndex == -1) continue;

      // 次の馬の名前の位置を探し、検索範囲を限定する
      int endIndex;
      if (i < horses.length - 1) {
        final nextHorseName = horses[i + 1].horseName;
        endIndex = text.indexOf(nextHorseName, nameIndex);
        if (endIndex == -1) {
          endIndex = text.length;
        }
      } else {
        endIndex = text.length;
      }

      // 現在の馬の情報のブロックを切り出す
      final targetBlock = text.substring(nameIndex, endIndex);

      // ブロック内のすべての数字（整数と小数）を抽出する
      final numberRegExp = RegExp(r'\d+\.\d+|\d+');
      final allNumbersInBlock = numberRegExp.allMatches(targetBlock).map((m) => m.group(0)!).toList();

      // --- ここからが新しいロジック ---
      // アプリが既に知っている静的データ（性齢、斤量）を文字列として準備
      final sexAgeStr = currentHorse.sexAndAge.replaceAll(RegExp(r'[^0-9]'), ''); // "セ10" -> "10"
      final weightStr = currentHorse.carriedWeight.toString(); // 60.0 -> "60.0"

      // 抽出した数字リストから、既知の静的データを除外する
      final List<String> dynamicNumbers = [];
      for(final numStr in allNumbersInBlock) {
        if (numStr != sexAgeStr && numStr != weightStr) {
          dynamicNumbers.add(numStr);
        }
      }

      // 除外後に残った数字のリストからオッズと人気を特定する
      if (dynamicNumbers.isNotEmpty) {
        double? odds;
        int? popularity;

        // 残ったリストの最初の数字をオッズとして試す
        odds = double.tryParse(dynamicNumbers[0]);

        // 2番目の数字を人気として試す
        if (dynamicNumbers.length > 1) {
          final popStr = dynamicNumbers[1].replaceAll('人気', '');
          popularity = int.tryParse(popStr);
        }

        // オッズと人気の両方が正しく取得できた場合のみ結果を保存
        if (odds != null && popularity != null) {
          resultMap[horseName] = PasteParseResult(odds: odds, popularity: popularity);
        }
      }
    }
    return resultMap;
  }
}