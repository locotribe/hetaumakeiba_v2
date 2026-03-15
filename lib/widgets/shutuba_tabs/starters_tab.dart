// lib/widgets/shutuba_tabs/starters_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/widgets/leg_style_indicator.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/info_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/jockey_trainer_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/time_tab.dart';

class StartersTabWidget extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function(int) buildGateNumber;
  final Widget Function(int, int) buildHorseNumber;
  final Future<HorseProfile?> Function(String) getHorseProfile;
  final bool isCourseOnlyMode; // ▼ 新規追加
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
    required this.isCourseOnlyMode, // ▼ 新規追加
    required this.buildDataTableForTab,
  }) : super(key: key);

  Color _getAffiliationColor(String affiliation) {
    if (affiliation.contains('美') || affiliation.contains('美浦')) {
      return Colors.lightBlue.shade50;
    } else if (affiliation.contains('栗') || affiliation.contains('栗東')) {
      return Colors.pink.shade50;
    } else if (affiliation.contains('地') || affiliation.contains('地方')) {
      return Colors.orange.shade50;
    } else if (affiliation.contains('外') || affiliation.contains('海外')) {
      return Colors.green.shade50;
    }
    return Colors.transparent;
  }

  Color _getTrackColor(String? venueAndDistance) {
    if (venueAndDistance == null) return Colors.black87;
    if (venueAndDistance.contains('芝')) return Colors.green.shade700;
    if (venueAndDistance.contains('ダ')) return Colors.brown.shade700;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('枠\n印'), fixedWidth: 35, onSort: (i, asc) => onSort(SortableColumn.horseNumber)),
        DataColumn2(label: const Text('人\n気'), fixedWidth: 40, onSort: (i, asc) => onSort(SortableColumn.odds)),
        const DataColumn2(
          label: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('騎手\n斤量', textAlign: TextAlign.center),
            ),
          ),
          fixedWidth: 70,
        ),
        const DataColumn2(
          label: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('所属\n調教師', textAlign: TextAlign.center),
            ),
          ),
          fixedWidth: 35,
        ),
        DataColumn2(label: const Text('馬情報'), size: ColumnSize.L, onSort: (i, asc) => onSort(SortableColumn.horseName)),
        DataColumn2(
          label: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // ▼ ヘッダーの動的切り替え
              child: Text(isCourseOnlyMode ? '同コース時計\n馬場/ｸｯｼｮﾝ値\n含水 : ｺﾞｰﾙ前\n　　　4ｺｰﾅｰ' : '持ち時計\n馬場/ｸｯｼｮﾝ値\n含水 : ｺﾞｰﾙ前\n　　　4ｺｰﾅｰ', textAlign: TextAlign.center),
            ),
          ),
          fixedWidth: 85,
          onSort: (i, asc) => onSort(SortableColumn.bestTime),
        ),
        DataColumn2(
          label: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // ▼ ヘッダーの動的切り替え
              child: Text(isCourseOnlyMode ? '同コース上り\n馬場/ｸｯｼｮﾝ値\n含水 : ｺﾞｰﾙ前\n　　　4ｺｰﾅｰ' : '上り最速\n馬場/ｸｯｼｮﾝ値\n含水 : ｺﾞｰﾙ前\n　　　4ｺｰﾅｰ', textAlign: TextAlign.center),
            ),
          ),
          fixedWidth: 85,
          onSort: (i, asc) => onSort(SortableColumn.fastestAgari),
        ),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final String father = (horse.fatherName?.isNotEmpty == true) ? horse.fatherName! : '--';
        final String mother = (horse.motherName?.isNotEmpty == true) ? horse.motherName! : '--';
        final String mf = (horse.mfName?.isNotEmpty == true) ? horse.mfName! : '--';
        final String owner = (horse.ownerName?.isNotEmpty == true) ? horse.ownerName! : '--';

        // ▼ データの動的切り替え
        final currentBestTime = isCourseOnlyMode ? horse.bestCourseTimeStats : horse.bestTimeStats;
        final currentAgari = isCourseOnlyMode ? horse.fastestCourseAgariStats : horse.fastestAgariStats;

        final bestTimeColor = _getTrackColor(currentBestTime?.venueAndDistance);
        final agariColor = _getTrackColor(currentAgari?.venueAndDistance);

        return [
          DataCell(MarkAndGateCell(horse: horse, buildMarkDropdown: buildMarkDropdown)),
          DataCell(OddsCell(horse: horse)),
          DataCell(JockeyProfileCell(horse: horse, owner: owner)),
          DataCell(TrainerCell(
            horse: horse,
            backgroundColor: _getAffiliationColor(horse.trainerAffiliation),
          )),
          DataCell(HorseInfoCell(horse: horse, father: father, mother: mother, mf: mf)),
          DataCell(TrackStatsCell(
            formattedValue: currentBestTime?.formattedTime,
            trackCondition: currentBestTime?.trackCondition,
            cushionValue: currentBestTime?.cushionValue,
            moistureGoal: currentBestTime?.moistureGoal,
            moisture4c: currentBestTime?.moisture4c,
            venueAndDistance: currentBestTime?.venueAndDistance,
            textColor: bestTimeColor,
          )),
          DataCell(TrackStatsCell(
            formattedValue: currentAgari?.formattedAgari,
            trackCondition: currentAgari?.trackCondition,
            cushionValue: currentAgari?.cushionValue,
            moistureGoal: currentAgari?.moistureGoal,
            moisture4c: currentAgari?.moisture4c,
            venueAndDistance: currentAgari?.venueAndDistance,
            textColor: agariColor,
          )),
        ];
      },
    );
  }
}

class HorseInfoCell extends StatelessWidget {
  final PredictionHorseDetail horse;
  final String father;
  final String mother;
  final String mf;

  const HorseInfoCell({
    Key? key,
    required this.horse,
    required this.father,
    required this.mother,
    required this.mf,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('父: $father', style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
        Row(
          children: [
            Text('${horse.sexAndAge} ', style: const TextStyle(fontSize: 10)),
            Expanded(
              child: Text(
                horse.horseName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: horse.isScratched ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text('母: $mother (母父: $mf)', style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        // --- ▼▼ 馬体重の表示ロジック修正 ▼▼ ---
        Builder(
            builder: (context) {
              final hw = horse.horseWeight ?? '';
              if (hw.contains('(')) {
                // 増減カッコが含まれている＝レース結果から取得した当日馬体重
                return Text('馬体重: (当日: $hw)', style: const TextStyle(fontSize: 10));
              } else {
                // それ以外＝通常の出馬表表示
                return Text('馬体重: ${hw.isEmpty ? '--' : hw} (前走: ${horse.previousHorseWeight ?? '--'})', style: const TextStyle(fontSize: 10));
              }
            }
        ),
        // --- ▲▲ 馬体重の表示ロジック修正 ▲▲ ---
        const SizedBox(height: 2),
        LegStyleIndicator(legStyleProfile: horse.legStyleProfile),
      ],
    );
  }
}