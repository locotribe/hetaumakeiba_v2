// lib/widgets/shutuba_tabs/starters_tab.dart

import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';

class StartersTabWidget extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function(int) buildGateNumber;
  final Widget Function(int, int) buildHorseNumber;
  final Future<HorseProfile?> Function(String) getHorseProfile;
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) buildDataTableForTab;

  const StartersTabWidget({
    Key? key,
    required this.horses,
    required this.onSort,
    required this.buildMarkDropdown,
    required this.buildGateNumber,
    required this.buildHorseNumber,
    required this.getHorseProfile,
    required this.buildDataTableForTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('枠\n番'), fixedWidth: 40, onSort: (i, asc) => onSort(SortableColumn.gateNumber)),
        DataColumn2(label: const Text('馬\n番'), fixedWidth: 40, onSort: (i, asc) => onSort(SortableColumn.horseNumber)),
        const DataColumn2(label: Text('服'), fixedWidth: 40),
        DataColumn2(label: const Text('馬名'), fixedWidth: 130, onSort: (i, asc) => onSort(SortableColumn.horseName)),
        DataColumn2(label: const Text('人気'), fixedWidth: 65, numeric: true, onSort: (i, asc) => onSort(SortableColumn.popularity)),
        DataColumn2(label: const Text('オッズ'), fixedWidth: 70, numeric: true, onSort: (i, asc) => onSort(SortableColumn.odds)),
      ],
      horses: horses,
      cellBuilder: (horse) => [
        DataCell(
          horse.isScratched
              ? const Text('取消', style: TextStyle(color: Colors.red))
              : buildMarkDropdown(horse),
        ),
        DataCell(buildGateNumber(horse.gateNumber)),
        DataCell(buildHorseNumber(horse.horseNumber, horse.gateNumber)),
        DataCell(
          FutureBuilder<HorseProfile?>(
            future: getHorseProfile(horse.horseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data!.ownerImageLocalPath.isNotEmpty) {
                return Center(
                  child: Image.file(
                    File(snapshot.data!.ownerImageLocalPath),
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        DataCell(
          Text(
            horse.horseName,
            style: TextStyle(
              decoration: horse.isScratched ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(horse.popularity?.toString() ?? '--')),
        DataCell(Text(horse.odds?.toString() ?? '--')),
      ],
    );
  }
}