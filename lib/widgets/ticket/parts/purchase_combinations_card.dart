// lib/widgets/ticket/parts/purchase_combinations_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';

class PurchaseCombinationsCard extends StatelessWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;

  const PurchaseCombinationsCard({
    super.key,
    required this.parsedResult,
    required this.betType,
  });

  @override
  Widget build(BuildContext context) {
    if (!parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }
    List<Map<String, dynamic>> purchaseDetails = (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
    if (purchaseDetails.isEmpty) {
      return const SizedBox.shrink();
    }
    final detail = purchaseDetails.first;

    final int? kingaku = detail['購入金額'];
    final int combinations = detail['組合せ数'] as int? ?? 0;
    final bool isComplexCombinationForPrefix = (betType == 'ボックス' || betType == 'ながし' || betType == 'フォーメーション');

    final TextStyle starStyle = ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
    final TextStyle amountStyle = ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0,);

    String combinationDisplayString = detail['組合せ数_表示用'] as String? ?? '';
    if (combinationDisplayString.isEmpty && combinations > 0) {
      combinationDisplayString = '$combinations';
    }

    List<Widget> widgets = [];

    if (combinationDisplayString.isNotEmpty) {
      widgets.add(
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '組合せ数 ',
                style: ticketMincho(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.0, // または 0.9 など、適宜調整してください
                  leadingDistribution: TextLeadingDistribution.even, // 上下の余白を均等に分配
                ),
              ),
              TextSpan(
                text: combinationDisplayString,
                style: ticketGothic(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (kingaku != null && isComplexCombinationForPrefix) {
      widgets.add(
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (detail['マルチ'] == 'あり')
                Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(0))),
                  child: Text('マルチ', style: ticketGothic(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1)),
                ),
              Text(isComplexCombinationForPrefix ? '各組' : '', style: amountStyle),
              Text(getStars(kingaku), style: starStyle),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$kingaku', style: ticketGothic(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0)),
                    TextSpan(text: '円', style: ticketMincho(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widgets,
    );
  }
}
