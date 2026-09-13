// lib/widgets/ticket/parts/purchase_total_amount_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';

class PurchaseTotalAmountCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult;

  const PurchaseTotalAmountCard({
    super.key,
    required this.parsedResult,
  });

  @override
  Widget build(BuildContext context) {
    final int totalAmount = parsedResult['合計金額'] as int? ?? 0;

    if (totalAmount == 0) {
      return const SizedBox.shrink();
    }

    String totalStars = getTotalAmountStars(totalAmount);
    String totalAmountString = totalAmount.toString();
    int totalSheets = totalAmount ~/ 10;

    // ★ 実物馬券に近いバランスの良いフォントサイズ
    const TextStyle labelTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14, // 「合計」「枚」「円」
    );
    const TextStyle starTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 12, // 「★」
    );
    const TextStyle numberTextStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 22, // 「数字」
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左側: 合計 ★★★600枚
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('合計　', style: labelTextStyle),
              Text(totalStars, style: starTextStyle),
              Text('$totalSheets', style: numberTextStyle),
              const Text('枚', style: labelTextStyle),
            ],
          ),
          const SizedBox(width: 8), // ★ 「枚」と右側の「★」の間のスペース
          // 右側: ★★★6000円
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(totalStars, style: starTextStyle),
              Text(totalAmountString, style: numberTextStyle),
              const Text('円', style: labelTextStyle),
            ],
          ),
        ],
      ),
    );
  }
}
