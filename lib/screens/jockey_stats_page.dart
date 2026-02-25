// lib/screens/jockey_stats_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/services/jockey_analysis_service.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

class JockeyStatsPage extends StatefulWidget {
  final PredictionRaceData raceData;

  const JockeyStatsPage({super.key, required this.raceData});

  @override
  State<JockeyStatsPage> createState() => _JockeyStatsPageState();
}

class _JockeyStatsPageState extends State<JockeyStatsPage> {
  late Future<Map<String, JockeyStats>> _jockeyStatsFuture;
  final JockeyAnalysisService _jockeyAnalysisService = JockeyAnalysisService();

  @override
  void initState() {
    super.initState();
    _loadJockeyStats();
  }

  void _loadJockeyStats() {
    final jockeyIds = widget.raceData.horses.map((h) => h.jockeyId).toList();
    _jockeyStatsFuture = _jockeyAnalysisService.analyzeAllJockeys(jockeyIds, raceData: widget.raceData);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, JockeyStats>>(
      future: _jockeyStatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('騎手データの分析中にエラーが発生しました: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('分析対象の騎手データがありません。'));
        }

        final jockeyStats = snapshot.data!;
        final sortedHorses = List<PredictionHorseDetail>.from(widget.raceData.horses)
          ..sort((a, b) => a.horseNumber.compareTo(b.horseNumber));

        return DataTable2(
          columnSpacing: 12.0,
          horizontalMargin: 12,
          minWidth: 400,
          columns: const [
            DataColumn2(label: Text('馬番'), fixedWidth: 50, numeric: true),
            DataColumn2(label: Text('人気'), fixedWidth: 50, numeric: true),
            DataColumn2(label: Text('騎手\n(当コース)'), fixedWidth: 100),
            DataColumn2(label: Text('1~3人気\n(複勝率)'), fixedWidth: 100),
            DataColumn2(label: Text('6人気~\n(単複回収率)'), size: ColumnSize.M),
          ],
          rows: sortedHorses.map((horse) {
            final stats = jockeyStats[horse.jockeyId];
            if (stats == null) {
              return DataRow(cells: [
                DataCell(Text(horse.horseNumber.toString())),
                DataCell(Text(horse.popularity?.toString() ?? '-')),
                DataCell(Text('${horse.jockey} (データなし)')),
                const DataCell(Text('-')),
                const DataCell(Text('-')),
              ]);
            }
            final courseStatsString = stats.courseStats?.recordString ?? '0-0-0-0';
            return DataRow(
              cells: [
                DataCell(
                  Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: horse.gateNumber.gateBackgroundColor,
                        border: horse.gateNumber == 1 ? Border.all(color: Colors.grey) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        horse.horseNumber.toString(),
                        style: TextStyle(
                          color: horse.gateNumber.gateTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(Text(horse.popularity?.toString() ?? '-')),
                DataCell(
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: <TextSpan>[
                        TextSpan(
                          text: stats.jockeyName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black, decoration: TextDecoration.none),
                        ),
                        TextSpan(
                          text: '\n($courseStatsString)',
                          style: const TextStyle(fontSize: 10, color: Colors.black, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                    Text(
                      '${stats.popularHorseStats.showRate.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    )
                ),
                DataCell(
                    Text(
                      '単 ${stats.unpopularHorseStats.winRecoveryRate.toStringAsFixed(0)}%\n複 ${stats.unpopularHorseStats.showRecoveryRate.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    )
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}