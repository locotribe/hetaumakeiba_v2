// lib/widgets/monthly_details_popup.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:intl/intl.dart';

class MonthlyDetailsPopup extends StatelessWidget {
  final int year;
  final int month;
  // ダミーデータではなく、実際の購入履歴リストを受け取る
  final List<MonthlyPurchaseDetail> purchaseDetails;

  const MonthlyDetailsPopup({
    super.key,
    required this.year,
    required this.month,
    required this.purchaseDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');

    return AlertDialog(
      title: Text('$year年$month月の購入履歴'),
      // 実際のデータリストを表示するロジックに変更
      content: SizedBox(
        width: double.maxFinite,
        child: purchaseDetails.isEmpty
            ? const Center(child: Text('この月の購入履歴はありません。'))
            : ListView.builder(
          shrinkWrap: true,
          itemCount: purchaseDetails.length,
          itemBuilder: (context, index) {
            final item = purchaseDetails[index];
            final profit = item.profit;
            Color profitColor = profit > 0 ? Colors.blue.shade700 : (profit < 0 ? Colors.red.shade700 : Colors.black87);

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.raceName,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('投資: ${currencyFormatter.format(item.investment)}円 / 払戻: ${currencyFormatter.format(item.payout)}円'),
              trailing: Text(
                '${profit >= 0 ? '+' : ''}${currencyFormatter.format(profit)}',
                style: TextStyle(color: profitColor, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
