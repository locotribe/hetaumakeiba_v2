// lib/widgets/rating/views/rating_momentum_view.dart
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

class RatingMomentumView extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, HorseRatingProfile> profiles;
  final Function(PredictionHorseDetail, List<RatingAnalyzedResult>) onRowTap;

  const RatingMomentumView({
    super.key,
    required this.horses,
    required this.profiles,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing: 8, horizontalMargin: 4, minWidth: 600,
      headingRowHeight: 50, dataRowHeight: 60,
      columns: const [
        DataColumn2(label: Text('馬番'), fixedWidth: 40),
        DataColumn2(label: Text('馬名'), size: ColumnSize.L),
        DataColumn2(label: Text('安定度'), fixedWidth: 60),
        DataColumn2(label: Text('状態サイクル'), fixedWidth: 100),
        DataColumn2(label: Text('診断メモ'), size: ColumnSize.L),
      ],
      rows: horses.map((horse) {
        final profile = profiles[horse.horseId];
        if (profile == null) return DataRow2(cells: List.generate(5, (_) => const DataCell(Text('-'))));

        Color statusColor = Colors.black87;
        String note = '';
        if (profile.momentumStatus == '反動警戒') { statusColor = Colors.red; note = '前走で実力以上に激走。疲労による凡走に注意。'; }
        else if (profile.momentumStatus == '上昇期') { statusColor = Colors.orange; note = '直近でRtを上げており、さらなる前進が見込める。'; }
        else if (profile.momentumStatus == '叩き一変注意') { statusColor = Colors.blue; note = '近走は不振だが地力はある。一変の余地あり。'; }
        else { note = '大きな波は見られず平行線。'; }

        return DataRow2(
          onTap: () => onRowTap(horse, profile.history),
          cells: [
            DataCell(Center(
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: horse.gateNumber.gateBackgroundColor, borderRadius: BorderRadius.circular(4)),
                alignment: Alignment.center,
                child: Text(horse.horseNumber.toString(), style: TextStyle(color: horse.gateNumber.gateTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )),
            DataCell(Text(horse.horseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataCell(Text(profile.stabilityRank, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: profile.stabilityRank == 'A' ? Colors.green : Colors.black87))),
            DataCell(Text(profile.momentumStatus, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13))),
            DataCell(Text(note, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          ],
        );
      }).toList(),
    );
  }
}