// lib/widgets/volatility_components/gender_chart_card.dart
// [追加] 性別（牡・牝・セ）別の入線分布カード (v.2026.9.9+26090904)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GenderChartCard extends StatelessWidget {
  final Map<String, dynamic> genderStats;

  const GenderChartCard({super.key, required this.genderStats});

  // [追加] statisticsJson の値を安全に整数化する (v.2026.9.9+26090904)
  int _statInt(String gender, String key) {
    final data = genderStats[gender];
    if (data is! Map) return 0;
    final value = data[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final genders = ['牡', '牝', 'セ'];

    // [追加] 集計側は累積(win=1着 / place=2着以内 / show=3着以内)なので各着順へ差分化する (v.2026.9.9+26090904)
    final Map<String, int> firstCounts = {};
    final Map<String, int> secondCounts = {};
    final Map<String, int> thirdCounts = {};
    final Map<String, int> totalCounts = {};
    int grandTotal = 0;

    for (final g in genders) {
      final total = _statInt(g, 'total');
      final win = _statInt(g, 'win');
      final place = _statInt(g, 'place');
      final show = _statInt(g, 'show');
      final second = place - win;
      final third = show - place;
      firstCounts[g] = win < 0 ? 0 : win;
      secondCounts[g] = second < 0 ? 0 : second;
      thirdCounts[g] = third < 0 ? 0 : third;
      totalCounts[g] = total < 0 ? 0 : total;
      grandTotal += totalCounts[g]!;
    }

    if (grandTotal == 0) return const SizedBox.shrink();

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < genders.length; i++) {
      final g = genders[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: (firstCounts[g] ?? 0).toDouble(), color: Colors.amber, width: 12, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (secondCounts[g] ?? 0).toDouble(), color: Colors.blueGrey, width: 12, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (thirdCounts[g] ?? 0).toDouble(), color: Colors.brown.shade400, width: 12, borderRadius: BorderRadius.circular(2)),
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
            const Text('性別 入線分布 (1〜3着)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= genders.length) {
                            return const SizedBox.shrink();
                          }
                          final g = genders[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '$g\n(${totalCounts[g] ?? 0}頭)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
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
