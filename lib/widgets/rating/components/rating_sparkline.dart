// lib/widgets/rating/components/rating_sparkline.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';

class RatingSparkline extends StatelessWidget {
  final List<RatingAnalyzedResult> analysis;

  const RatingSparkline({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.length < 2) {
      return const Center(child: Text('データ不足', style: TextStyle(fontSize: 9, color: Colors.grey)));
    }

    // 直近5走を表示
    final data = analysis.length > 5 ? analysis.sublist(analysis.length - 5) : analysis;
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.raceRating)).toList();

    return SizedBox(
      width: 80, height: 35,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false), // タッチ無効化
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue.shade400,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: false,
            drawVerticalLine: true,
            verticalInterval: 1, // 1レースごと
            getDrawingVerticalLine: (value) => FlLine(color: Colors.black12, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}