// lib/widgets/shutuba_tabs/info_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/widgets/leg_style_indicator.dart';

class InfoTabWidget extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) buildDataTableForTab;

  const InfoTabWidget({
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
        DataColumn2(label: const Text('脚質'), fixedWidth: 130, onSort: (i, asc) => onSort(SortableColumn.legStyle)),
        const DataColumn2(label: Text('性齢'), fixedWidth: 40),
        DataColumn2(label: const Text('斤量'), fixedWidth: 50, onSort: (i, asc) => onSort(SortableColumn.carriedWeight)),
        DataColumn2(label: const Text('馬体重'), fixedWidth: 70, onSort: (i, asc) => onSort(SortableColumn.horseWeight)),
        const DataColumn2(label: Text('前走馬体重'), fixedWidth: 70),
      ],
      horses: horses,
      cellBuilder: (horse) {
        String? parsedPreviousWeight;
        if (horse.previousHorseWeight != null && horse.previousHorseWeight!.contains('(')) {
          parsedPreviousWeight = horse.previousHorseWeight!.split('(').first;
        } else if (horse.previousHorseWeight != null) {
          parsedPreviousWeight = horse.previousHorseWeight;
        }
        return [
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
          DataCell(LegStyleIndicator(legStyleProfile: horse.legStyleProfile)),
          DataCell(Text(horse.sexAndAge)),
          DataCell(Text(horse.carriedWeight.toString())),
          DataCell(Text(horse.horseWeight ?? '--')),
          DataCell(Text(parsedPreviousWeight ?? '--')),
        ];
      },
    );
  }
}