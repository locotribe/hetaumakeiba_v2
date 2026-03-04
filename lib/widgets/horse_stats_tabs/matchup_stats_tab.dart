import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/matchup_stats_model.dart';

class MatchupStatsTab extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final List<MatchupStats> matchupStats;

  const MatchupStatsTab({
    super.key,
    required this.horses,
    required this.matchupStats,
  });

  @override
  Widget build(BuildContext context) {
    if (matchupStats.isEmpty) {
      return const Center(child: Text('直接対決の成績はありません。'));
    }

    const double cellWidth = 50.0;
    const double cellHeight = 50.0;
    const double headerHeight = 50.0;
    const double totalCellWidth = 70.0;

    final Map<String, Map<String, int>> horseTotals = {};
    for (final horseA in horses) {
      int totalOpponentWins = 0;
      int totalWinLegs = 0;
      int totalLossLegs = 0;

      for (final horseB in horses) {
        if (horseA.horseId == horseB.horseId) continue;

        MatchupStats? stats;
        try {
          stats = matchupStats.firstWhere((m) =>
          (m.horseIdA == horseA.horseId && m.horseIdB == horseB.horseId) ||
              (m.horseIdA == horseB.horseId && m.horseIdB == horseA.horseId));
        } catch (e) {
          stats = null;
        }

        if (stats != null) {
          final wins = (stats.horseIdA == horseA.horseId) ? stats.horseAWins : stats.horseBWins;
          final losses = stats.matchupCount - wins;
          totalWinLegs += wins;
          totalLossLegs += losses;
          if (wins > losses) {
            totalOpponentWins++;
          }
        }
      }
      horseTotals[horseA.horseId] = {
        'Win': totalOpponentWins,
        'WinLeg': totalWinLegs,
        'LosLeg': totalLossLegs,
      };
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: headerHeight),
                ...horses.map((horse) {
                  return Container(
                    height: cellHeight,
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    child: Text(
                      horse.horseName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...horses.map((horse) {
                        final horseName = horse.horseName;
                        final displayName = horseName.length > 3 ? horseName.substring(0, 3) : horseName;
                        return Container(
                          width: cellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                            ),
                          ),
                          child: Text(
                            '${horse.horseNumber}\n$displayName',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }),
                      Container(
                          width: totalCellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          child: const Text('WIN',
                              style: TextStyle(fontSize: 14),
                              textAlign: TextAlign.center
                          )
                      ),
                      Container(
                          width: totalCellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          child: const Text('W-Leg',
                              style: TextStyle(fontSize: 12),
                              textAlign: TextAlign.center
                          )
                      ),
                      Container(
                          width: totalCellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          child: const Text('L-Leg',
                              style: TextStyle(fontSize: 12),
                              textAlign: TextAlign.center
                          )
                      ),
                    ],
                  ),
                  ...horses.map((horseA) {
                    final totals = horseTotals[horseA.horseId] ?? {'Win': 0, 'WinLeg': 0, 'LosLeg': 0};
                    return Row(
                      children: [
                        ...horses.map((horseB) {
                          String cellText = '';
                          Color? cellColor;
                          if (horseA.horseId == horseB.horseId) {
                            cellText = '';
                            cellColor = Colors.grey.shade500;
                          } else {
                            MatchupStats? stats;
                            try {
                              stats = matchupStats.firstWhere((m) =>
                              (m.horseIdA == horseA.horseId && m.horseIdB == horseB.horseId) ||
                                  (m.horseIdA == horseB.horseId && m.horseIdB == horseA.horseId));
                            } catch (e) {
                              stats = null;
                            }

                            if (stats != null) {
                              int wins = (stats.horseIdA == horseA.horseId) ? stats.horseAWins : stats.horseBWins;
                              int losses = stats.matchupCount - wins;
                              cellText = '$wins-$losses';
                            }
                          }
                          return Container(
                            width: cellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cellColor,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                            ),
                            child: Builder(
                              builder: (context) {
                                Widget symbolWidget = const SizedBox.shrink();
                                if (cellText.isNotEmpty && cellText != '-') {
                                  final parts = cellText.split('-');
                                  if (parts.length == 2) {
                                    final wins = int.tryParse(parts[0]);
                                    final losses = int.tryParse(parts[1]);
                                    if (wins != null && losses != null) {
                                      if (wins > losses) {
                                        symbolWidget = const Text(
                                          '〇',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      } else if (wins < losses) {
                                        symbolWidget = const Text(
                                          '✕',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    symbolWidget,
                                    Text(
                                      cellText,
                                      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        }),
                        Container(
                            width: totalCellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            child: Text(totals['Win'].toString(),
                                style: const TextStyle(fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue
                                )
                            )
                        ),
                        Container(
                            width: totalCellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            child: Text(totals['WinLeg'].toString(),
                                style: const TextStyle(fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue
                                )
                            )
                        ),
                        Container(
                            width: totalCellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            child: Text(totals['LosLeg'].toString(),
                                style: const TextStyle(fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red
                                )
                            )
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}