// lib/widgets/odds_tabs/odds_win_place_widget.dart

import 'package:flutter/material.dart';
import '../../models/race_data.dart';
import '../../utils/gate_color_utils.dart';

class OddsWinPlaceWidget extends StatelessWidget {
  final List<Map<String, String>> oddsData;
  final PredictionRaceData raceData;

  const OddsWinPlaceWidget({super.key, required this.oddsData, required this.raceData});

  @override
  Widget build(BuildContext context) {
    final sortedHorses = List<PredictionHorseDetail>.from(raceData.horses)
      ..sort((a, b) => a.horseNumber.compareTo(b.horseNumber));

    final Map<String, String> oddsMap = {
      for (var item in oddsData) (item['combination'] ?? ''): (item['odds'] ?? '--')
    };

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columnSpacing: 8,
        horizontalMargin: 12,
        headingRowHeight: 45,
        dataRowMinHeight: 50,
        dataRowMaxHeight: 50,
        columns: const [
          DataColumn(label: Text('馬番', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('馬名', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('単勝', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('複勝', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: sortedHorses.map((horse) {
          final hNumStr = horse.horseNumber.toString().padLeft(2, '0');
          final winOdds = oddsMap['1_$hNumStr'] ?? '--';
          final placeOdds = oddsMap['2_$hNumStr'] ?? '--';

          return DataRow(
            color: MaterialStateProperty.resolveWith<Color?>((states) {
              if (horse.isScratched) return Colors.grey.shade100;
              return null;
            }),
            cells: [
              DataCell(Center(child: _buildHorseBox(horse))),
              DataCell(
                  Text(
                      horse.horseName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: horse.isScratched ? TextDecoration.lineThrough : null,
                        color: horse.isScratched ? Colors.grey : Colors.black87,
                      )
                  )
              ),
              DataCell(_buildOddsText(winOdds)),
              DataCell(_buildOddsText(placeOdds)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHorseBox(PredictionHorseDetail horse) {
    final gateNum = horse.gateNumber;
    return Container(
      width: 28, height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gateNum.gateBackgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: gateNum == 1 ? Border.all(color: Colors.grey.shade400) : Border.all(color: Colors.black.withOpacity(0.2)),
      ),
      child: Text(
        horse.horseNumber.toString(),
        style: TextStyle(color: gateNum.gateTextColor, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildOddsText(String odds) {
    final val = double.tryParse(odds) ?? 999.0;
    return Center(
      child: Text(
        odds,
        style: TextStyle(
          color: val <= 9.9 ? Colors.red : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}