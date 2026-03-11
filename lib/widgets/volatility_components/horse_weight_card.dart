import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class HorseWeightCard extends StatelessWidget {
  final HorseWeightAnalysisResult result;

  const HorseWeightCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.winningWeights.isEmpty) {
      return const SizedBox.shrink();
    }

    final avg = result.averageWinningWeight;
    final median = result.medianWinningWeight;
    final min = result.winningWeights.reduce((a, b) => a < b ? a : b);
    final max = result.winningWeights.reduce((a, b) => a > b ? a : b);

    List<BarChartGroupData> barGroups = [];
    final categories = ['-10kg以下', '-4~-8kg', '-2~+2kg', '+4~+8kg', '+10kg以上'];
    int xIndex = 0;

    for (String cat in categories) {
      final stats = result.changeStats[cat];
      if (stats != null) {
        barGroups.add(
          BarChartGroupData(
            x: xIndex,
            barRods: [
              BarChartRodData(
                toY: stats.win.toDouble(),
                color: Colors.amber,
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: stats.place.toDouble(),
                color: Colors.blueGrey,
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: stats.show.toDouble(),
                color: Colors.brown.shade400,
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        );
      }
      xIndex++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('勝ち馬の馬体重傾向',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.scale, color: Colors.brown, size: 36),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('中央値: ${median.toStringAsFixed(1)} kg (実態)',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange)),
                  const SizedBox(height: 4),
                  Text('平均値: ${avg.toStringAsFixed(1)} kg',
                      style:
                      const TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                    '範囲: ${min.toStringAsFixed(0)}kg 〜 ${max.toStringAsFixed(0)}kg'),
              ),
            ),
            const Divider(height: 32),
            const Text('馬体重増減別 実績',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  const Text('勝数', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.blueGrey, size: 12),
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
              height: 180,
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
                          if (value.toInt() >= 0 &&
                              value.toInt() < categories.length) {
                            String cat = categories[value.toInt()];
                            int total =
                                result.changeStats[cat]?.total ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('$cat\n($total頭)',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
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