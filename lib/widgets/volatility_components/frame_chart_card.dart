import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class FrameChartCard extends StatelessWidget {
  final FrameAnalysisResult result;

  const FrameChartCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.totalCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 1; i <= 8; i++) {
      double win = (result.winCounts[i] ?? 0).toDouble();
      double place = (result.placeCounts[i] ?? 0).toDouble();
      double show = (result.showCounts[i] ?? 0).toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: win,
              color: Colors.amber,
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: place,
              color: Colors.blueGrey,
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: show,
              color: Colors.brown.shade400,
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('枠番別 有利不利 (1〜8枠)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.square, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  const Text('勝数', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.square, color: Colors.blueGrey, size: 12),
                  const SizedBox(width: 4),
                  const Text('連対数(2着内)', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.brown.shade400, size: 12),
                  const SizedBox(width: 4),
                  const Text('複勝数(3着内)', style: TextStyle(fontSize: 11))
                ]),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          int frame = value.toInt();
                          if (frame >= 1 && frame <= 8) {
                            int total = result.totalCounts[frame] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('$frame枠\n($total頭)',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}