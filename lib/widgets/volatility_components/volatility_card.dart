import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class VolatilityCard extends StatelessWidget {
  final VolatilityResult res;

  const VolatilityCard({super.key, required this.res});

  @override
  Widget build(BuildContext context) {
    Color diagColor;
    IconData diagIcon;

    if (res.diagnosis == '大波乱') {
      diagColor = Colors.red;
      diagIcon = Icons.warning_amber_rounded;
    } else if (res.diagnosis == '堅い') {
      diagColor = Colors.blue;
      diagIcon = Icons.shield;
    } else {
      diagColor = Colors.green;
      diagIcon = Icons.balance;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(diagIcon, size: 48, color: diagColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '波乱度: ${res.diagnosis}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: diagColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '上位馬平均人気: ${res.averagePopularity.toStringAsFixed(2)}番人気',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '分析レポート',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              res.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}