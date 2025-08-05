// lib/widgets/yearly_summary_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/widgets/monthly_details_popup.dart';
import 'package:intl/intl.dart';

class YearlySummaryCard extends StatelessWidget {
  final YearlySummary yearlySummary;
  final List<int> availableYears;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  const YearlySummaryCard({
    super.key,
    required this.yearlySummary,
    required this.availableYears,
    required this.selectedYear,
    required this.onYearChanged,
  });

  void _showMonthlyDetails(BuildContext context, int month) {
    // 該当月の購入履歴リストをフィルタリングして渡す
    final detailsForMonth = yearlySummary.monthlyPurchaseDetails
        .where((detail) => detail.month == month)
        .toList();
    showDialog(
      context: context,
      builder: (context) {
        return MonthlyDetailsPopup(
          year: selectedYear,
          month: month,
          purchaseDetails: detailsForMonth,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYearSelector(),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildBarChart(context),
          ),
          const SizedBox(height: 24),
          _buildSummaryTable(currencyFormatter),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left),
          onPressed: () {
            final currentIndex = availableYears.indexOf(selectedYear);
            if (currentIndex < availableYears.length - 1) {
              onYearChanged(availableYears[currentIndex + 1]);
            }
          },
        ),
        Text(
          '$selectedYear年',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: () {
            final currentIndex = availableYears.indexOf(selectedYear);
            if (currentIndex > 0) {
              onYearChanged(availableYears[currentIndex - 1]);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getChartMaxY(),
        minY: _getChartMinY(),
        barGroups: _generateBarGroups(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()}月', style: const TextStyle(fontSize: 10)),
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
              final month = group.x.toInt();
              final profit = rod.toY.toInt();
              return BarTooltipItem(
                '$month月\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: NumberFormat.decimalPattern('ja').format(profit),
                    style: TextStyle(
                      color: profit >= 0 ? Colors.lightBlueAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text: ' 円',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              );
            },
          ),
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (event is FlTapUpEvent && barTouchResponse != null && barTouchResponse.spot != null) {
              final month = barTouchResponse.spot!.touchedBarGroup.x;
              _showMonthlyDetails(context, month);
            }
          },
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
    return yearlySummary.monthlyData.map((data) {
      final profit = data.profit.toDouble();
      return BarChartGroupData(
        x: data.month,
        barRods: [
          BarChartRodData(
            toY: profit,
            color: profit >= 0 ? Colors.blue : Colors.red,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  double _getChartMaxY() {
    final maxProfit = yearlySummary.monthlyData.map((d) => d.profit).reduce((a, b) => a > b ? a : b);
    return maxProfit > 0 ? maxProfit * 1.2 : 1000;
  }

  double _getChartMinY() {
    final minProfit = yearlySummary.monthlyData.map((d) => d.profit).reduce((a, b) => a < b ? a : b);
    return minProfit < 0 ? minProfit * 1.2 : 0;
  }

  Widget _buildSummaryTable(NumberFormat formatter) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      children: [
        _buildTableRow('総投資額', '${formatter.format(yearlySummary.totalInvestment)}円'),
        _buildTableRow('総払戻額', '${formatter.format(yearlySummary.totalPayout)}円'),
        _buildTableRow('総収支', '${formatter.format(yearlySummary.totalProfit)}円', isProfit: true, profit: yearlySummary.totalProfit),
        _buildTableRow('的中率', '${yearlySummary.totalHitRate.toStringAsFixed(1)}%'),
        _buildTableRow('回収率', '${yearlySummary.totalRecoveryRate.toStringAsFixed(1)}%'),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, {bool isProfit = false, int profit = 0}) {
    Color valueColor = Colors.black87;
    if (isProfit) {
      if (profit > 0) valueColor = Colors.blue.shade700;
      if (profit < 0) valueColor = Colors.red.shade700;
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor),
          ),
        ),
      ],
    );
  }
}