// lib/widgets/shutuba_tabs/time_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';

class TimeTabWidget extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) buildDataTableForTab;

  const TimeTabWidget({
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
        DataColumn2(label: const Text('持ち時計'), fixedWidth: 80, numeric: true, onSort: (i, asc) => onSort(SortableColumn.bestTime)),
        const DataColumn2(label: Text('馬場\n(記録時)'), fixedWidth: 60),
        DataColumn2(label: const Text('最速上がり'), fixedWidth: 80, numeric: true, onSort: (i, asc) => onSort(SortableColumn.fastestAgari)),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final bestTime = horse.bestTimeStats;
        final fastestAgari = horse.fastestAgariStats;
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
          DataCell(
            JustTheTooltip(
              triggerMode: TooltipTriggerMode.tap,
              backgroundColor: const Color.fromRGBO(0, 0, 0, 0.5),
              content: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(bestTime != null ? '${bestTime.date}\n${bestTime.raceName}' : 'データなし',
                  style: const TextStyle(color: Colors.white),),
              ),
              child: Text(bestTime?.formattedTime ?? '-'),
            ),
          ),
          DataCell(Text(bestTime?.trackCondition ?? '-')),
          DataCell(
            JustTheTooltip(
              triggerMode: TooltipTriggerMode.tap,
              backgroundColor: const Color.fromRGBO(0, 0, 0, 0.5),
              content: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(fastestAgari != null ? '${
                    fastestAgari.date}\n${
                    fastestAgari.raceName}\n馬場: ${
                    fastestAgari.trackCondition}' : 'データなし',
                  style: const TextStyle(color: Colors.white),),
              ),
              child: Text(fastestAgari?.formattedAgari ?? '-'),
            ),
          ),
        ];
      },
    );
  }
}