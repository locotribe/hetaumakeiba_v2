// lib/widgets/category_summary_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:intl/intl.dart';

class CategorySummaryCard extends StatelessWidget {
  final String title;
  final List<CategorySummary> summaries;

  const CategorySummaryCard({
    super.key,
    required this.title,
    required this.summaries,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    // 回収率で降順ソート
    final sortedSummaries = List<CategorySummary>.from(summaries)
      ..sort((a, b) => b.recoveryRate.compareTo(a.recoveryRate));

    final currencyFormatter = NumberFormat.decimalPattern('ja');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('カテゴリ')),
                  DataColumn(label: Text('回収率'), numeric: true),
                  DataColumn(label: Text('収支'), numeric: true),
                  DataColumn(label: Text('投資額'), numeric: true),
                  DataColumn(label: Text('払戻額'), numeric: true),
                ],
                rows: sortedSummaries.map((summary) {
                  final profit = summary.profit;
                  Color profitColor = Colors.black87;
                  if (profit > 0) profitColor = Colors.blue.shade700;
                  if (profit < 0) profitColor = Colors.red.shade700;

                  final String displayName = title == '式別 収支'
                      ? (bettingDict[summary.name] ?? summary.name)
                      : summary.name;

                  return DataRow(cells: [
                    DataCell(Text(displayName)),
                    DataCell(Text('${summary.recoveryRate.toStringAsFixed(1)}%')),
                    DataCell(Text(
                      currencyFormatter.format(profit),
                      style: TextStyle(color: profitColor),
                    )),
                    DataCell(Text(currencyFormatter.format(summary.investment))),
                    DataCell(Text(currencyFormatter.format(summary.payout))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}