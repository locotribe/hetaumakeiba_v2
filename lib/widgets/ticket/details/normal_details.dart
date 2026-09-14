// lib/widgets/ticket/details/normal_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/horse_number_box.dart';

/// 通常投票のレイアウト
Widget buildNormalDetails(Map<String, dynamic> detail, String currentBetType, RaceResult? raceResult) {
  final String shikibetsuId = detail['式別'] ?? '';
  final String shikibetsu = bettingDict[shikibetsuId] ?? '';

  String currentSymbol = getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);
  final dynamic horseNumbers = detail['馬番'];
  final int horseCount = horseNumbers is List ? horseNumbers.length : 1;
  final int? kingaku = detail['購入金額'];

  Widget horseDisplayWidget;

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
    // ボックスと3連単・通常以外の、これまで通りの処理
    final Widget horseNumbersDisplay = Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [...buildHorseNumberDisplay(horseNumbers, symbol: currentSymbol, horseCountForSizing: horseCount)],
    );

    if ((shikibetsu == '単勝' || shikibetsu == '複勝') && raceResult != null) {
      String? horseNameToDisplay;
      try {
        final horseNumberInt = horseNumbers as int;
        final horseNumberString = horseNumberInt.toString();
        final horseData = raceResult.horseResults.firstWhere(
              (h) => h.horseNumber.trim() == horseNumberString,
        );
        horseNameToDisplay = horseData.horseName;
      } catch (e) {
        // Not found
      }

      if (horseNameToDisplay != null) {
        horseDisplayWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            horseNumbersDisplay,
            const SizedBox(width: 8.0),
            Text(
              horseNameToDisplay,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      } else {
        horseDisplayWidget = horseNumbersDisplay;
      }
    } else {
      horseDisplayWidget = horseNumbersDisplay;
    }
  }

  // 金額表示ウィジェット (3連単・通常の場合もここで生成される)
  Widget amountDisplay = const SizedBox.shrink();
  if (kingaku != null && currentBetType == '通常') {
    const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    const TextStyle amountStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0,);
    amountDisplay = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 16.0),
        Text(getStars(kingaku), style: starStyle),
        Text('$kingaku円', style: amountStyle),
      ],
    );
  }

  // 最終的に馬番表示と金額表示を結合する
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      horseDisplayWidget,
      amountDisplay,
    ],
  );
}
