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
        alignment: BarChartAlignment.spaceAround,
        maxY: _getChartMaxY(sortedSummaries),
        barGroups: _generateBarGroups(sortedSummaries),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedSummaries.length) return const SizedBox.shrink();

                final summary = sortedSummaries[index];
                final String displayName = title == '式別 収支'
                    ? (bettingDict[summary.name] ?? summary.name)
                    : summary.name;

                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4.0,
                  child: Text(displayName, style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 20,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final summary = sortedSummaries[group.x.toInt()];
              final String displayName = title == '式別 収支'
                  ? (bettingDict[summary.name] ?? summary.name)
                  : summary.name;

              return BarTooltipItem(
                '$displayName\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: '${summary.recoveryRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: summary.recoveryRate >= 100 ? Colors.lightBlueAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '\n収支: ${currencyFormatter.format(summary.profit)}円',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: summary.recoveryRate,
            color: summary.recoveryRate >= 100 ? Colors.blue : Colors.red,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  double _getChartMaxY(List<CategorySummary> sortedSummaries) {
    if (sortedSummaries.isEmpty) return 120.0;
    final maxRate = sortedSummaries.map((s) => s.recoveryRate).reduce((a, b) => a > b ? a : b);
    return maxRate > 100 ? maxRate * 1.2 : 120;
  }
}