// lib/widgets/category_summary_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              '表示できるデータがありません。',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
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
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: (sortedSummaries.length * 50.0).clamp(MediaQuery.of(context).size.width - 64, double.infinity),
                  child: _buildChart(sortedSummaries, currencyFormatter),
                ),
              ),
            ),
            const SizedBox(height: 24),
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

  Widget _buildChart(List<CategorySummary> sortedSummaries, NumberFormat currencyFormatter) {
    return BarChart(
      BarChartData(
        barGroups: _generateBarGroups(sortedSummaries),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  currencyFormatter.format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedSummaries.length) return const SizedBox.shrink();
                final summary = sortedSummaries[index];
                final String displayName = title == '式別 収支'
                    ? (bettingDict[summary.name] ?? summary.name)
                    : summary.name;

                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    displayName,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final summary = sortedSummaries[groupIndex];
              final String displayName = title == '式別 収支'
                  ? (bettingDict[summary.name] ?? summary.name)
                  : summary.name;

              final investment = currencyFormatter.format(summary.investment);
              final payout = currencyFormatter.format(summary.payout);
              final recoveryRate = summary.recoveryRate.toStringAsFixed(1);

              return BarTooltipItem(
                '$displayName\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(text: '投資: $investment円\n', style: const TextStyle(fontSize: 12)),
                  TextSpan(text: '払戻: $payout円\n', style: const TextStyle(fontSize: 12)),
                  TextSpan(
                    text: '回収率: $recoveryRate%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade300),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups(List<CategorySummary> sortedSummaries) {
    return List.generate(sortedSummaries.length, (index) {
      final summary = sortedSummaries[index];
      const barWidth = 10.0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: summary.investment.toDouble(),
            color: Colors.grey.shade400,
            width: barWidth,
            borderRadius: BorderRadius.zero,
          ),
          BarChartRodData(
            toY: summary.payout.toDouble(),
            color: Colors.green.shade400,
            width: barWidth,
            borderRadius: BorderRadius.zero,
          ),
        ],
        showingTooltipIndicators: [],
      );
    });
  }
}