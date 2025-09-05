// lib/logic/paste_parser.dart

import 'package:flutter/services.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';


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

    // PC版にしか含まれない「編集」の有無で、まずPC版かを判定する
    if (text.contains('編集')) {
      // --- ここからが最終版のPC版解析ロジック ---
      final lines = text.split('\n');

      for (int i = 0; i < lines.length; i++) {
        // ▼▼▼ ここを修正しました ▼▼▼
        // 「'編集'と完全に一致」から「'編集'で終わる」に条件を緩和
        if (lines[i].trim().endsWith('編集')) {
          String? dataLine;
          String? horseName;

          // 「編集」行から遡って、空でない行を2つ探す
          for (int j = i - 1; j >= 0; j--) {
            final currentLine = lines[j].trim();
            if (currentLine.isNotEmpty) {
              if (dataLine == null) {
                // 最初に見つかる空でない行が「データ行」
                dataLine = currentLine;
              } else {
                // 次に見つかる空でない行が「馬名」
                horseName = currentLine;
                break;
              }
            }
          }

          if (horseName != null && dataLine != null) {
            double? odds;
            int? popularity;

            // データ行にタブが含まれるかで、2つの解析方法を切り替える
            if (dataLine.contains('\t')) {
              // --- パターンA: タブ区切りのデータを解析 ---
              final parts = dataLine.split('\t').where((p) => p.trim().isNotEmpty).toList();
              final numbers = parts
                  .map((p) => double.tryParse(p))
                  .where((n) => n != null)
                  .cast<double>()
                  .toList();

              if (numbers.length >= 2) {
                final lastValue = numbers.last;
                final secondLastValue = numbers[numbers.length - 2];

                if (secondLastValue.toString().contains('.')) {
                  odds = secondLastValue;
                  popularity = lastValue.toInt();
                } else {
                  odds = lastValue;
                  popularity = secondLastValue.toInt();
                }
              }
            } else {
              // --- パターンB: 連結されたデータを正規表現で解析 ---
              final regex = RegExp(r'(\d+\.\d+)(\d+)$');
              final match = regex.firstMatch(dataLine);

              if (match != null) {
                odds = double.tryParse(match.group(1)!);
                popularity = int.tryParse(match.group(2)!);
              }
            }

            if (odds != null && popularity != null) {
              resultMap[horseName] = PasteParseResult(odds: odds, popularity: popularity);
            }
          }
        }
      }
    }
    // モバイル版のデータか判定
    else if (text.contains('人気')) {
      // --- ここからが既存のモバイル版の解析ロジック（変更なし） ---
      for (int i = 0; i < horses.length; i++) {
        final currentHorse = horses[i];
        final horseName = currentHorse.horseName;

        final nameIndex = text.indexOf(horseName);
        if (nameIndex == -1) continue;

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

        final targetBlock = text.substring(nameIndex, endIndex);

        double? odds;
        int? popularity;

        if (targetBlock.contains('人気')) {
          final popRegExp = RegExp(r'(\d+)人気');
          final popMatch = popRegExp.firstMatch(targetBlock);

          if (popMatch != null) {
            popularity = int.tryParse(popMatch.group(1)!);
            final popIndex = popMatch.start;
            final searchBlockForOdds = targetBlock.substring(0, popIndex);
            final oddsRegExp = RegExp(r'(\d+\.\d+)');
            final allOddsMatches = oddsRegExp.allMatches(searchBlockForOdds);
            if (allOddsMatches.isNotEmpty) {
              odds = double.tryParse(allOddsMatches.last.group(1)!);
            }
          }
        }

        if (odds != null && popularity != null) {
          resultMap[horseName] = PasteParseResult(odds: odds, popularity: popularity);
        }
      }
    }

    return resultMap;
  }
}