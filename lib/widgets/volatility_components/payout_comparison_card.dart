import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:intl/intl.dart' as intl;

class PayoutComparisonCard extends StatelessWidget {
  final PayoutAnalysisResult result;

  const PayoutComparisonCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.averages.isEmpty) return const SizedBox.shrink();

    final targetTypes = ['単勝', '複勝', '枠連', '馬連', 'ワイド', '馬単', '3連複', '3連単'];

    List<BarChartGroupData> barGroups = [];
    int xIndex = 0;
    List<String> labels = [];

    Map<String, int?> maxVals = {};
    Map<String, int?> minVals = {};

    final currencyFormatter = intl.NumberFormat.decimalPattern('ja');

    for (String label in targetTypes) {
      if (result.averages.containsKey(label)) {
        double avg = result.averages[label] ?? 0;
        double med = result.medians[label] ?? 0;

        labels.add(label);
        barGroups.add(
          BarChartGroupData(
            x: xIndex,
            barRods: [
              BarChartRodData(toY: avg, color: Colors.orange.shade300, width: 8, borderRadius: BorderRadius.circular(2)),
              BarChartRodData(toY: med, color: Colors.deepOrange, width: 8, borderRadius: BorderRadius.circular(2)),
            ],
          ),
        );

        final rawList = result.rawPayouts[label] ?? [];
        if (rawList.isNotEmpty) {
          maxVals[label] = rawList.reduce((a, b) => a > b ? a : b).toInt();
          minVals[label] = rawList.reduce((a, b) => a < b ? a : b).toInt();
        } else {
          maxVals[label] = null;
          minVals[label] = null;
        }
        xIndex++;
      }
    }

    if (barGroups.isEmpty) return const SizedBox.shrink();

    String formatShort(int? val) {
      if (val == null) return '-';
      if (val == 0) return '0';
      if (val >= 10000) {
        return '${(val / 10000).toStringAsFixed(1).replaceAll('.0', '')}万';
      }
      return currencyFormatter.format(val);
    }

    Widget buildTapCell(String text, int? exactVal) {
      Widget cellContent = SizedBox(
        height: 14,
        child: Center(
          child: Text(text, style: const TextStyle(fontSize: 9), maxLines: 1),
        ),
      );

      if (exactVal != null) {
        return Tooltip(
          message: '${currencyFormatter.format(exactVal)}円',
          triggerMode: TooltipTriggerMode.tap,
          preferBelow: false,
          decoration: BoxDecoration(
            color: Colors.black87.withOpacity(0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          child: cellContent,
        );
      }
      return cellContent;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('配当傾向 (平均値 vs 中央値)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.square, color: Color(0xFFFFB74D), size: 12), SizedBox(width: 4), Text('平均値', style: TextStyle(fontSize: 11)),
                SizedBox(width: 16),
                Icon(Icons.square, color: Colors.deepOrange, size: 12), SizedBox(width: 4), Text('中央値 (実態)', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 24),
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24.0),
                  child: SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        barTouchData: BarTouchData(enabled: false),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barGroups,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx >= 0 && idx < labels.length) {
                                  String L = labels[idx];
                                  double avg = result.averages[L] ?? 0;
                                  double med = result.medians[L] ?? 0;

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) {
                                      final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                      showMenu(
                                        context: context,
                                        position: RelativeRect.fromRect(
                                          details.globalPosition & const Size(40, 40),
                                          Offset.zero & overlay.size,
                                        ),
                                        color: Colors.black87.withOpacity(0.9),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        items: [
                                          PopupMenuItem(
                                            enabled: false,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(L, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                                const SizedBox(height: 4),
                                                Text('平均: ${currencyFormatter.format(avg.toInt())}円', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text('中央: ${currencyFormatter.format(med.toInt())}円', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(height: 14, child: Center(child: Text(L, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)))),
                                          buildTapCell(formatShort(minVals[L]), minVals[L]),
                                          buildTapCell(formatShort(maxVals[L]), maxVals[L]),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.only(top: 8.0),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 14),
                        SizedBox(height: 14, child: Center(child: Text('最低', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)))),
                        SizedBox(height: 14, child: Center(child: Text('最高', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}