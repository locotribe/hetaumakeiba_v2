import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';

class TrackConditionTrendCard extends StatelessWidget {
  final TrackConditionTrendResult result;

  const TrackConditionTrendCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // データが全て0（未取得など）の場合は表示しない
    if (result.avgCushion == 0 && result.avgTurfMoisture == 0 && result.avgDirtMoisture == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '過去の馬場状態の傾向',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (result.avgCushion > 0) ...[
              _buildRow('クッション値 平均', result.avgCushion.toStringAsFixed(1), Colors.green.shade700),
              _buildRow('クッション値 最大 (最も硬い)', result.maxCushion.toStringAsFixed(1), Colors.grey.shade700),
              _buildRow('クッション値 最小 (最も軟らかい)', result.minCushion.toStringAsFixed(1), Colors.grey.shade700),
              const Divider(height: 24),
            ],
            if (result.avgTurfMoisture > 0)
              _buildRow('芝 含水率 平均', '${result.avgTurfMoisture.toStringAsFixed(1)} %', Colors.blue.shade700),
            if (result.avgDirtMoisture > 0)
              _buildRow('ダート 含水率 平均', '${result.avgDirtMoisture.toStringAsFixed(1)} %', Colors.brown.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}