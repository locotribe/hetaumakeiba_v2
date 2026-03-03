// lib/widgets/shutuba_tabs/jockey_trainer_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';

class JockeyTrainerTabWidget extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) buildDataTableForTab;

  const JockeyTrainerTabWidget({
    Key? key,
    required this.horses,
    required this.onSort,
    required this.buildMarkDropdown,
    required this.buildDataTableForTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => onSort(SortableColumn.horseName)),
        const DataColumn2(label: Text('騎手'), fixedWidth: 80),
        const DataColumn2(label: Text('前走騎手'), fixedWidth: 80),
        const DataColumn2(label: Text('所属'), fixedWidth: 50),
        DataColumn2(label: const Text('調教師'), fixedWidth: 80, onSort: (i, asc) => onSort(SortableColumn.trainer)),
        DataColumn2(label: const Text('馬主'), fixedWidth: 250, onSort: (i, asc) => onSort(SortableColumn.owner)),
      ],
      horses: horses,
      cellBuilder: (horse) => [
        DataCell(
          horse.isScratched
              ? const Text('取消', style: TextStyle(color: Colors.red))
              : buildMarkDropdown(horse),
        ),
        DataCell(
          Text(
            horse.horseName,
            style: TextStyle(
              decoration: horse.isScratched ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        DataCell(Text(horse.jockey)),
        DataCell(Text(horse.previousJockey ?? '--')),
        DataCell(Text(horse.trainerAffiliation)),
        DataCell(Text(horse.trainerName)),
        DataCell(Text(horse.ownerName ?? '--')),
      ],
    );
  }
}