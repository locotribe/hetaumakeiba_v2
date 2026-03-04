import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';

class JockeyComboStatsTab extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, JockeyComboStats> jockeyComboStats;

  const JockeyComboStatsTab({
    super.key,
    required this.horses,
    required this.jockeyComboStats,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16.0,
          columns: const [
            DataColumn(label: Text('馬名')),
            DataColumn(label: Text('騎手')),
            DataColumn(label: Text('成績')),
            DataColumn(label: Text('勝率'), numeric: true),
            DataColumn(label: Text('連対率'), numeric: true),
            DataColumn(label: Text('複勝率'), numeric: true),
            DataColumn(label: Text('単回率'), numeric: true),
            DataColumn(label: Text('複回率'), numeric: true),
          ],
          rows: horses.map((horse) {
            final stats = jockeyComboStats[horse.horseId] ?? JockeyComboStats();
            return DataRow(
              cells: [
                DataCell(Text(horse.horseName)),
                DataCell(Text(horse.jockey)),
                DataCell(
                  stats.isFirstRide
                      ? const Text('初', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))
                      : Text(stats.recordString),
                ),
                DataCell(Text('${stats.winRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.placeRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.showRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.winRecoveryRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.showRecoveryRate.toStringAsFixed(1)}%')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}