// lib/widgets/rating/views/rating_suitability_view.dart
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

class RatingSuitabilityView extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, HorseRatingProfile> profiles;
  final String raceDate;
  final Function(PredictionHorseDetail, List<RatingAnalyzedResult>) onRowTap;

  const RatingSuitabilityView({
    super.key,
    required this.horses,
    required this.profiles,
    required this.raceDate,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    // 今回の開催月を取得
    int currentMonth = 1;
    final dateMatch = RegExp(r'\d{4}[^\d]*(\d{1,2})[^\d]*\d{1,2}').firstMatch(raceDate);
    if (dateMatch != null) currentMonth = int.parse(dateMatch.group(1)!);

    return DataTable2(
      columnSpacing: 8, horizontalMargin: 4, minWidth: 600,
      headingRowHeight: 50, dataRowHeight: 60,
      columns: const [
        DataColumn2(label: Text('馬番'), fixedWidth: 40),
        DataColumn2(label: Text('馬名'), size: ColumnSize.L),
        DataColumn2(label: Text('クラス壁\n突破'), fixedWidth: 80),
        DataColumn2(label: Text('斤量適性'), size: ColumnSize.M),
        DataColumn2(label: Text('季節適性'), size: ColumnSize.M),
      ],
      rows: horses.map((horse) {
        final profile = profiles[horse.horseId];
        if (profile == null) return DataRow2(cells: List.generate(5, (_) => const DataCell(Text('-'))));

        // クラス壁の判定
        Widget classClearWidget = profile.isClassCleared
            ? const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width:4), Text('突破済', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))])
            : const Row(children: [Icon(Icons.warning, color: Colors.red, size: 16), SizedBox(width:4), Text('壁あり', style: TextStyle(fontSize: 12, color: Colors.red))]);

        // 斤量判定（今回の斤量がベストRt時より重いか）
        String weightDesc = '-';
        if (profile.bestRatingWeight > 0) {
          final diff = horse.carriedWeight - profile.bestRatingWeight;
          if (diff > 1.0) weightDesc = '過去ベスト時より\n重い(酷量)';
          else if (diff < -1.0) weightDesc = '過去ベスト時より\n軽い(恵量)';
          else weightDesc = '適量';
        }

        // 季節判定
        String seasonDesc = '-';
        if (profile.bestRatingMonth > 0) {
          final mDiff = (currentMonth - profile.bestRatingMonth).abs();
          if (mDiff <= 2 || mDiff >= 10) seasonDesc = '好相性\n(同季節に高Rt)';
          else seasonDesc = '普通';
        }

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
            DataCell(classClearWidget),
            DataCell(Text(weightDesc, style: const TextStyle(fontSize: 11, height: 1.2))),
            DataCell(Text(seasonDesc, style: const TextStyle(fontSize: 11, height: 1.2))),
          ],
        );
      }).toList(),
    );
  }
}