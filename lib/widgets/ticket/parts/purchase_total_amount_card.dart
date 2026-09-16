// lib/widgets/ticket/parts/purchase_total_amount_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';

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
    final TextStyle labelTextStyle = ticketMincho(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14, // 「合計」「枚」「円」
      // [修正] 単勝・複勝の行と同様に上下余白を削り、ベースライン揃えで下寄せにする (v.2026.9.16+XXXXXXXX)
      height: 1.0,
    );
    final TextStyle starTextStyle = ticketMincho(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 12, // 「★」
    );
    final TextStyle numberTextStyle = ticketGothic(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 26, // 「数字」
      // [修正] 単勝・複勝の行と同様に上下余白を削る (v.2026.9.16+XXXXXXXX)
      height: 1.0,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // [修正] 中央揃えからベースライン揃えに変更し「枚」「円」を下寄せにする (v.2026.9.16+XXXXXXXX)
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // 左側: 合計 ★★★600枚
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('合計　', style: labelTextStyle),
              // [修正] 下寄せで★も下がるため、★だけ上へ持ち上げて縦中央に寄せる (v.2026.9.16+XXXXXXXX)
              Transform.translate(
                offset: const Offset(0, -3.5),
                child: Text(totalStars, style: starTextStyle),
              ),
              Text('$totalSheets', style: numberTextStyle),
              Text('枚', style: labelTextStyle),
            ],
          ),
          const SizedBox(width: 8), // ★ 「枚」と右側の「★」の間のスペース
          // 右側: ★★★6000円
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Transform.translate(
                offset: const Offset(0, -3.5),
                child: Text(totalStars, style: starTextStyle),
              ),
              Text(totalAmountString, style: numberTextStyle),
              Text('円', style: labelTextStyle),
            ],
          ),
        ],
      ),
    );
  }
}
