// lib/widgets/volatility_components/age_chart_card.dart
// [追加] 年齢（3歳〜7歳以上）別の入線分布カード (v.2026.10.30+26103002)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/age_category.dart';

class AgeChartCard extends StatelessWidget {
  final Map<String, dynamic> ageStats;

  const AgeChartCard({super.key, required this.ageStats});

  // statisticsJson の値を安全に整数化する
  int _statInt(String age, String key) {
    final data = ageStats[age];
    if (data is! Map) return 0;
    final value = data[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // 頭数が0の区分は出さない（4歳以上戦で「3歳 (0頭)」が並ばないようにする）
    final ages = kAgeCategories.where((a) => _statInt(a, 'total') > 0).toList();
    if (ages.isEmpty) return const SizedBox.shrink();

    // 集計側は累積(win=1着 / place=2着以内 / show=3着以内)なので各着順へ差分化する
    final Map<String, int> firstCounts = {};
    final Map<String, int> secondCounts = {};
    final Map<String, int> thirdCounts = {};
    final Map<String, int> totalCounts = {};

    for (final a in ages) {
      final total = _statInt(a, 'total');
      final win = _statInt(a, 'win');
      final place = _statInt(a, 'place');
      final show = _statInt(a, 'show');
      final second = place - win;
      final third = show - place;
      firstCounts[a] = win < 0 ? 0 : win;
      secondCounts[a] = second < 0 ? 0 : second;
      thirdCounts[a] = third < 0 ? 0 : third;
      totalCounts[a] = total;
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < ages.length; i++) {
      final a = ages[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: (firstCounts[a] ?? 0).toDouble(), color: Colors.amber, width: 10, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (secondCounts[a] ?? 0).toDouble(), color: Colors.blueGrey, width: 10, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (thirdCounts[a] ?? 0).toDouble(), color: Colors.brown.shade400, width: 10, borderRadius: BorderRadius.circular(2)),
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
            const Text('年齢 入線分布 (1〜3着)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          if (index < 0 || index >= ages.length) {
                            return const SizedBox.shrink();
                          }
                          final a = ages[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '$a\n(${totalCounts[a] ?? 0}頭)',
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
