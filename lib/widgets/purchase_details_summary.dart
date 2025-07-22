import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';

class PurchaseDetailsSummary extends StatelessWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;

  const PurchaseDetailsSummary({
    Key? key,
    required this.parsedResult,
    required this.betType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalAmount = 0;

    if (parsedResult.containsKey('購入内容')) {
      List<Map<String, dynamic>> purchaseDetails = (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
      for (var detail in purchaseDetails) {
        if (detail.containsKey('購入金額')) {
          int kingakuPerCombination = detail['購入金額'] as int;
          if (detail.containsKey('表示用相手頭数') && detail.containsKey('表示用乗数')) {
            int opponentCountForDisplay = detail['表示用相手頭数'] as int;
            int multiplierForDisplay = detail['表示用乗数'] as int;
            totalAmount += (opponentCountForDisplay * multiplierForDisplay * kingakuPerCombination);
          } else if (detail.containsKey('組合せ数')) {
            int combinations = detail['組合せ数'] as int;
            totalAmount += (combinations * kingakuPerCombination);
          } else {
            totalAmount += kingakuPerCombination;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PurchaseDetailsCard(
          parsedResult: parsedResult,
          betType: betType,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '合計',
                  style: AppStyles.totalLabelStyle,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$totalAmount円',
                    style: AppStyles.totalAmountStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
