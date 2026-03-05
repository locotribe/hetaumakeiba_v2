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

  // ▼▼ 新規追加: 芝・ダートを判別して文字色を返すメソッド ▼▼
  Color _getTrackColor(String? venueAndDistance) {
    if (venueAndDistance == null) return Colors.black87;
    // 視認性を高めるため、少し暗めの緑と茶色（shade700）を使用します
    if (venueAndDistance.contains('芝')) return Colors.green.shade700;
    if (venueAndDistance.contains('ダ')) return Colors.brown.shade700;
    return Colors.black87; // 該当しない場合は黒
  }
  // ▲▲ 新規追加 ▲▲

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

        // ヘッダーはそのまま（幅85）
        DataColumn2(
          label: const Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('持ち時計\n馬場/C\nG/4c', textAlign: TextAlign.center),
            ),
          ),
          fixedWidth: 85,
          onSort: (i, asc) => onSort(SortableColumn.bestTime),
        ),
        DataColumn2(
          label: const Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('上がり最速\n馬場/C\nG/4c', textAlign: TextAlign.center),
            ),
          ),
          fixedWidth: 85,
          onSort: (i, asc) => onSort(SortableColumn.fastestAgari),
        ),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final father = (horse.fatherName?.isNotEmpty == true) ? horse.fatherName : '--';
        final mother = (horse.motherName?.isNotEmpty == true) ? horse.motherName : '--';
        final mf = (horse.mfName?.isNotEmpty == true) ? horse.mfName : '--';
        final owner = (horse.ownerName?.isNotEmpty == true) ? horse.ownerName : '--';

        // ▼ 第6列・第7列の文字色をコースによって決定 ▼
        final bestTimeColor = _getTrackColor(horse.bestTimeStats?.venueAndDistance);
        final agariColor = _getTrackColor(horse.fastestAgariStats?.venueAndDistance);

        return [
          // 1列目: 印・枠
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

          // 2列目: 人気・オッズ
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

          // 3列目: 騎手・斤量・馬主
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

          // 4列目: 所属・調教師
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

          // 5列目: 馬情報
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

          // ▼ 修正: 第6列 (持ち時計) 開催場から数字を排除して「東京 芝1800」のように整形 ▼
          DataCell(
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      horse.bestTimeStats?.formattedTime ?? '--',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: bestTimeColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${horse.bestTimeStats?.trackCondition ?? '--'} / ${horse.bestTimeStats?.cushionValue != null ? 'C:${horse.bestTimeStats!.cushionValue}' : '--'}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bestTimeColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (horse.bestTimeStats?.moistureGoal != null || horse.bestTimeStats?.moisture4c != null)
                          ? 'G:${horse.bestTimeStats?.moistureGoal ?? '-'}\n4c:${horse.bestTimeStats?.moisture4c ?? '-'}'
                          : '--',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: bestTimeColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (() {
                        // ▼ ここで「4東京4芝1800」から「東京 芝1800」へ整形
                        final raw = horse.bestTimeStats?.venueAndDistance;
                        if (raw == null || raw.isEmpty) return '--';
                        final match = RegExp(r'^(.*?)([芝ダ障].*)$').firstMatch(raw);
                        if (match != null) {
                          // 前半(開催場)の数字とスペースを除去し、後半(距離)と結合
                          final v = match.group(1)!.replaceAll(RegExp(r'[0-9０-９\s]'), '');
                          return '$v ${match.group(2)}';
                        }
                        return raw;
                      })(),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: bestTimeColor),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ▼ 修正: 第7列 (上がり最速) 開催場から数字を排除して「東京 芝1800」のように整形 ▼
          DataCell(
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      horse.fastestAgariStats?.formattedAgari ?? '--',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: agariColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${horse.fastestAgariStats?.trackCondition ?? '--'} / ${horse.fastestAgariStats?.cushionValue != null ? 'C:${horse.fastestAgariStats!.cushionValue}' : '--'}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: agariColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (horse.fastestAgariStats?.moistureGoal != null || horse.fastestAgariStats?.moisture4c != null)
                          ? 'G:${horse.fastestAgariStats?.moistureGoal ?? '-'}\n4c:${horse.fastestAgariStats?.moisture4c ?? '-'}'
                          : '--',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: agariColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (() {
                        // ▼ ここで「4東京4芝1800」から「東京 芝1800」へ整形
                        final raw = horse.fastestAgariStats?.venueAndDistance;
                        if (raw == null || raw.isEmpty) return '--';
                        final match = RegExp(r'^(.*?)([芝ダ障].*)$').firstMatch(raw);
                        if (match != null) {
                          // 前半(開催場)の数字とスペースを除去し、後半(距離)と結合
                          final v = match.group(1)!.replaceAll(RegExp(r'[0-9０-９\s]'), '');
                          return '$v ${match.group(2)}';
                        }
                        return raw;
                      })(),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: agariColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}