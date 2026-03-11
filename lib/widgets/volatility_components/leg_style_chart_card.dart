import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class LegStyleChartCard extends StatelessWidget {
  final LegStyleAnalysisResult result;

  const LegStyleChartCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.winCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, Color> colorMap = {
      '逃げ・先行': Colors.redAccent,
      '差し': Colors.blueAccent,
      '追込': Colors.amber,
      '不明': Colors.grey,
    };

    List<PieChartSectionData> sections = [];
    result.winCounts.forEach((style, count) {
      if (count > 0 && style != '不明') {
        sections.add(
          PieChartSectionData(
            color: colorMap[style] ?? Colors.grey,
            value: count.toDouble(),
            title: '$style\n$count勝',
            radius: 60,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
    });

    if (sections.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('脚質別 勝率シェア',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sections,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}