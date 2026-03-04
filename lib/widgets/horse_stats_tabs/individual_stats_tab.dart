import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';

class IndividualStatsTab extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, HorseStats> statsMap;

  const IndividualStatsTab({
    super.key,
    required this.horses,
    required this.statsMap,
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
            DataColumn(label: Text('馬番')),
            DataColumn(label: Text('馬名')),
            DataColumn(label: Text('出走数'), numeric: true),
            DataColumn(label: Text('勝率'), numeric: true),
            DataColumn(label: Text('連対率'), numeric: true),
            DataColumn(label: Text('複勝率'), numeric: true),
            DataColumn(label: Text('単回率'), numeric: true),
            DataColumn(label: Text('複回率'), numeric: true),
            DataColumn(label: Text('G1')),
            DataColumn(label: Text('G2')),
            DataColumn(label: Text('G3')),
            DataColumn(label: Text('OP')),
            DataColumn(label: Text('条件戦')),
          ],
          rows: horses.map((horse) {
            final stats = statsMap[horse.horseId] ?? HorseStats();
            return DataRow(
              cells: [
                DataCell(Text(horse.horseNumber.toString())),
                DataCell(Text(horse.horseName)),
                DataCell(Text(stats.raceCount.toString())),
                DataCell(Text('${stats.winRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.placeRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.showRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.winRecoveryRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.showRecoveryRate.toStringAsFixed(1)}%')),
                DataCell(Text(stats.g1Stats)),
                DataCell(Text(stats.g2Stats)),
                DataCell(Text(stats.g3Stats)),
                DataCell(Text(stats.opStats)),
                DataCell(Text(stats.conditionStats)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}