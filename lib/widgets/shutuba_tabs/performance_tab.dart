// lib/widgets/shutuba_tabs/performance_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/race_interval_analyzer.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/info_tab.dart';

class _PerformanceData {
  final List<HorseRaceRecord> records;
  final Map<String, RaceResult> raceResults;

  _PerformanceData(this.records, this.raceResults);
}

class PerformanceTabWidget extends StatelessWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) buildDataTableForTab;

  final String? highlightedRaceId;
  final Function(String) onRaceHighlightChanged;

  final HorseRepository _horseRepo = HorseRepository();
  final RaceRepository _raceRepo = RaceRepository();
  final UserRepository _userRepo = UserRepository();

  PerformanceTabWidget({
    Key? key,
    required this.predictionRaceData,
    required this.horses,
    required this.onSort,
    required this.buildMarkDropdown,
    required this.buildDataTableForTab,
    required this.highlightedRaceId,
    required this.onRaceHighlightChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印\n枠'), fixedWidth: 40, onSort: (i, asc) => onSort(SortableColumn.horseNumber)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => onSort(SortableColumn.horseName)),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('前走'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('前々走'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('3走前'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('4走前'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('5走前'))),
      ],
      horses: horses,
      cellBuilder: (horse) => [
        DataCell(MarkAndGateCell(horse: horse, buildMarkDropdown: buildMarkDropdown)),
        DataCell(
          Text(
            horse.horseName,
            style: TextStyle(
              decoration: horse.isScratched ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        ..._buildPerformanceCells(horse.horseId),
      ],
    );
  }

  List<DataCell> _buildPerformanceCells(String horseId) {
    final futurePerformanceData = Future<_PerformanceData>(() async {
      final records = await _horseRepo.getHorsePerformanceRecords(horseId);
      final raceIds = records.map((r) => r.raceId).where((id) => id.isNotEmpty).toSet().toList();
      final raceResults = await _raceRepo.getMultipleRaceResults(raceIds);
      return _PerformanceData(records, raceResults);
    });

    final List<DataCell> cells = [];

    cells.add(DataCell(
      FutureBuilder<_PerformanceData>(
        future: futurePerformanceData,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.records.isNotEmpty) {
            final currentRace = predictionRaceData;
            final previousRace = snapshot.data!.records.first;
            final interval = RaceIntervalAnalyzer.formatRaceInterval(currentRace.raceDate, previousRace.date);
            final distanceChange = RaceIntervalAnalyzer.formatDistanceChange(currentRace.raceDetails1 ?? '', previousRace.distance);
            return _buildIntervalCell(interval, distanceChange);
          }
          return const SizedBox(width: 70);
        },
      ),
    ));

    for (int i = 0; i < 5; i++) {
      cells.add(DataCell(
        FutureBuilder<_PerformanceData>(
          future: futurePerformanceData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.records.length > i) {
              final record = snapshot.data!.records[i];
              final raceResult = snapshot.data!.raceResults[record.raceId];
              HorseResult? horseResultInRace;
              if (raceResult != null) {
                try {
                  horseResultInRace = raceResult.horseResults.firstWhere((hr) => hr.horseId == record.horseId);
                } catch (e) {
                }
              }
              return _buildPastRaceDetailCard(record, horseResultInRace);
            }
            return const SizedBox(width: 250);
          },
        ),
      ));

      if (i < 4) {
        cells.add(DataCell(
          FutureBuilder<_PerformanceData>(
            future: futurePerformanceData,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.records.length > i + 1) {
                final current = snapshot.data!.records[i];
                final previous = snapshot.data!.records[i + 1];
                final interval = RaceIntervalAnalyzer.formatRaceInterval(current.date, previous.date);
                final distanceChange = RaceIntervalAnalyzer.formatDistanceChange(current.distance, previous.distance);
                return _buildIntervalCell(interval, distanceChange);
              }
              return const SizedBox(width: 70);
            },
          ),
        ));
      }
    }
    return cells;
  }

  Widget _buildIntervalCell(String interval, String distanceChange) {
    Color distanceColor;
    switch (distanceChange) {
      case '延長': distanceColor = Colors.blue; break;
      case '短縮': distanceColor = Colors.red; break;
      default: distanceColor = Colors.black87;
    }
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(interval, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(distanceChange, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: distanceColor)),
        ],
      ),
    );
  }

  Widget _buildPastRaceDetailCard(HorseRaceRecord record, HorseResult? horseResult) {
    final isHighlighted = record.raceId.isNotEmpty && record.raceId == highlightedRaceId;
    final textColor = isHighlighted ? Colors.white : Colors.black87;
    final rankInt = int.tryParse(record.rank);
    Color backgroundColor = Colors.transparent;
    if (isHighlighted) {
      backgroundColor = Colors.black54;
    } else if (rankInt != null) {
      if (rankInt == 1) backgroundColor = Colors.red.withAlpha(30);
      if (rankInt == 2) backgroundColor = Colors.blue.withAlpha(30);
      if (rankInt == 3) backgroundColor = Colors.yellow.withAlpha(80);
    }

    final legStyle = RaceDataParser.getSimpleLegStyle(record.cornerPassage, record.numberOfHorses);

    String extractedGrade = '';
    final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
    final match = gradePattern.firstMatch(record.raceName);
    if (match != null) extractedGrade = match.group(1)!;
    final gradeColor = getGradeColor(extractedGrade);

    final timeDiffMargin = record.margin;
    final stringMargin = horseResult?.margin ?? '';
    String displayMargin = timeDiffMargin;

    if (stringMargin.isNotEmpty && timeDiffMargin.isNotEmpty) {
      displayMargin = '$stringMargin / $timeDiffMargin';
    } else if (stringMargin.isNotEmpty) {
      displayMargin = stringMargin;
    }

    return GestureDetector(
      onTap: () {
        if (record.raceId.isNotEmpty) {
          onRaceHighlightChanged(record.raceId);
        }
      },
      child: Container(
        width: 270,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: gradeColor, width: 5.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 50,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      FutureBuilder<UserMark?>(
                        future: _userRepo.getUserMark(localUserId!, record.raceId, record.horseId),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data?.mark != null) {
                            return Text(
                              snapshot.data!.mark,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isHighlighted ? const Color.fromRGBO(255, 255, 255, 0.30) : const Color.fromRGBO(0, 0, 0, 0.20),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            record.rank,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: ['1','2','3'].contains(record.rank)
                                  ? Colors.red
                                  : textColor,
                            ),
                          ),
                          Text(
                            '${record.popularity}人気',
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                          Text(
                            legStyle,
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 4.0, 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${record.venue.replaceAll(RegExp(r'\d'), '')} ${record.weather}/${record.trackCondition}/${record.numberOfHorses}頭', style: TextStyle(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(record.time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${record.raceName.replaceAll(RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false), '').trim()}/${record.distance}', style: TextStyle(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(record.agari, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${record.horseNumber}番 ${record.horseWeight} ${record.jockey}(${record.carriedWeight})', style: TextStyle(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(displayMargin, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}