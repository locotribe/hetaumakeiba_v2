// lib/widgets/volatility_components/leg_style_chart_card.dart
// (このファイルの中身を、1-3着分布が見える棒グラフに書き換えます)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class LegStyleChartCard extends StatelessWidget {
  final LegStyleAnalysisResult result;

  const LegStyleChartCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final styles = ['逃げ', '先行', '差し', '追込'];

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < styles.length; i++) {
      String s = styles[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: (result.winCounts[s] ?? 0).toDouble(), color: Colors.amber, width: 12, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (result.placeCounts[s] ?? 0).toDouble(), color: Colors.blueGrey, width: 12, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (result.showCounts[s] ?? 0).toDouble(), color: Colors.brown.shade400, width: 12, borderRadius: BorderRadius.circular(2)),
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
            const Text('脚質別 入線分布 (1〜3着)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildLegend(),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(styles[value.toInt()], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          );
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

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      children: [
        _legendItem('1着', Colors.amber),
        _legendItem('2着', Colors.blueGrey),
        _legendItem('3着', Colors.brown.shade400),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.square, color: color, size: 12),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}