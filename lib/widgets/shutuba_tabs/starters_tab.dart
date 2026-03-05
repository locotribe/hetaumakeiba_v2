// lib/widgets/shutuba_tabs/starters_tab.dart

import 'dart:io';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/widgets/leg_style_indicator.dart';

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

  Color _getAffiliationColor(String affiliation) {
    if (affiliation.contains('美') || affiliation.contains('美浦')) {
      return Colors.lightBlue.shade50; // 関東馬は水色
    } else if (affiliation.contains('栗') || affiliation.contains('栗東')) {
      return Colors.pink.shade50; // 関西馬はピンク
    } else if (affiliation.contains('地') || affiliation.contains('地方')) {
      return Colors.orange.shade50; // 地方馬はオレンジ
    } else if (affiliation.contains('外') || affiliation.contains('海外')) {
      return Colors.green.shade50; // 外国馬は緑
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印\n枠'), fixedWidth: 35, onSort: (i, asc) => onSort(SortableColumn.horseNumber)),

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
      ],
      horses: horses,
      cellBuilder: (horse) {
        final father = (horse.fatherName?.isNotEmpty == true) ? horse.fatherName : '--';
        final mother = (horse.motherName?.isNotEmpty == true) ? horse.motherName : '--';
        final mf = (horse.mfName?.isNotEmpty == true) ? horse.mfName : '--';
        final owner = (horse.ownerName?.isNotEmpty == true) ? horse.ownerName : '--';

        return [
          // 1列目: 印（薄いグレー背景）、馬番（枠色背景）
          DataCell(
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey.shade200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  horse.isScratched
                      ? const Text('取消', style: TextStyle(color: Colors.red, fontSize: 12))
                      : buildMarkDropdown(horse),
                  const SizedBox(height: 6),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: horse.gateNumber > 0 ? horse.gateNumber.gateBackgroundColor : Colors.white,
                      border: Border.all(color: horse.gateNumber > 0 ? horse.gateNumber.gateBackgroundColor : Colors.grey),
                    ),
                    child: Text(
                      horse.horseNumber.toString(),
                      style: TextStyle(
                        color: (horse.gateNumber.gateBackgroundColor == Colors.black) ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2列目: 人気、オッズ（9.9以下なら赤文字）
          DataCell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${horse.popularity ?? '--'}人気', style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 8),
                Text(
                  horse.odds?.toString() ?? '--',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (horse.odds != null && horse.odds! <= 9.9) ? Colors.red : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // 3列目: 勝負服、(替)騎手名、騎手との戦績(初)、斤量、馬主
          DataCell(
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (horse.ownerImageLocalPath != null && horse.ownerImageLocalPath!.isNotEmpty)
                    Image.file(File(horse.ownerImageLocalPath!), width: 22, height: 22, errorBuilder: (c, e, s) => const SizedBox(height: 22))
                  else
                    const SizedBox(height: 22),
                  const SizedBox(height: 2),
                  Text(
                    owner!,
                    style: const TextStyle(fontSize: 6, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(horse.previousJockey != null && horse.jockey != horse.previousJockey) ? '替 ' : ''}${horse.jockey}',
                    style: TextStyle(
                      fontSize: 10,
                      color: (horse.previousJockey != null && horse.jockey != horse.previousJockey) ? Colors.orange.shade800 : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    horse.jockeyComboStats?.isFirstRide == true ? '初' : (horse.jockeyComboStats?.recordString ?? '--'),
                    style: const TextStyle(fontSize: 9, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 2),
                  Text('${horse.carriedWeight}kg', style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),

          // 4列目(新規): 所属、調教師（所属に応じた背景色付き）
          DataCell(
            Container(
              width: double.infinity,
              height: double.infinity,
              color: _getAffiliationColor(horse.trainerAffiliation),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    horse.trainerAffiliation,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    horse.trainerName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // 5列目: 父、性齢 馬名、母(母父)、馬体重 前馬体重、脚質分布図
          DataCell(
            Column(
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
                Text('馬体重: ${horse.horseWeight ?? '--'} (前走: ${horse.previousHorseWeight ?? '--'})', style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 2),
                LegStyleIndicator(legStyleProfile: horse.legStyleProfile),
              ],
            ),
          ),
        ];
      },
    );
  }
}