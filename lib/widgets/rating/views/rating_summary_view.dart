// lib/widgets/rating/views/rating_summary_view.dart
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import '../components/rating_sparkline.dart';
import '../components/rating_level_badge.dart';

class RatingSummaryView extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, HorseRatingProfile> profiles;
  final Function(PredictionHorseDetail, List<RatingAnalyzedResult>) onRowTap;

  const RatingSummaryView({
    super.key,
    required this.horses,
    required this.profiles,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing: 8, horizontalMargin: 4, minWidth: 700,
      headingRowHeight: 50, dataRowHeight: 70,
      columns: const [
        DataColumn2(label: Text('馬番\n印'), fixedWidth: 45),
        DataColumn2(label: Text('馬名'), size: ColumnSize.L),
        DataColumn2(label: Text('今回オッズ\n(人気)'), fixedWidth: 85),
        DataColumn2(label: Text('実力\nTrend'), fixedWidth: 75, numeric: true),
        DataColumn2(label: Text('期待値\nGap/評価'), fixedWidth: 90, numeric: true),
        DataColumn2(label: Text('調子推移'), size: ColumnSize.M),
        DataColumn2(label: Text('前走Rt\n(評価)'), fixedWidth: 85),
      ],
      rows: horses.asMap().entries.map((entry) {
        final horse = entry.value;
        final profile = profiles[horse.horseId];
        final history = profile?.history ?? [];
        final lastPerf = history.isNotEmpty ? history.last : null;
        final trend = profile?.latestTrend ?? 0.0;

        final trendRank = entry.key + 1;
        final currentPop = horse.popularity ?? 10;
        final gap = currentPop - trendRank;

        return DataRow2(
          onTap: () => onRowTap(horse, history),
          cells: [
            DataCell(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: horse.gateNumber.gateBackgroundColor,
                    border: horse.gateNumber == 1 ? Border.all(color: Colors.grey) : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(horse.horseNumber.toString(), style: TextStyle(color: horse.gateNumber.gateTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Text(horse.userMark?.mark ?? '--', style: const TextStyle(fontSize: 10)),
              ],
            )),
            DataCell(Text(horse.horseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataCell(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${horse.odds ?? '--'}倍', style: TextStyle(color: (horse.odds ?? 99) < 10 ? Colors.red : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('(${horse.popularity ?? '--'}人)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            )),
            DataCell(Text(trend > 0 ? trend.toStringAsFixed(1) : '-', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: trend >= 105 ? Colors.red : Colors.blue.shade900))),
            DataCell(_buildGapWithDiagnosis(gap)),
            DataCell(RatingSparkline(analysis: history)),
            DataCell(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lastPerf != null ? lastPerf.raceRating.toStringAsFixed(1) : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                RatingLevelBadge(
                  level: lastPerf?.levelGrade ?? 'None',
                  rankStr: lastPerf?.record.rank ?? '99',
                ),
              ],
            )),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGapWithDiagnosis(int gap) {
    Color color = Colors.grey;
    String diag = '適正';
    if (gap >= 6) { color = Colors.red.shade700; diag = '過小評価★'; }
    else if (gap >= 3) { color = Colors.orange.shade800; diag = '妙味あり'; }
    else if (gap <= -6) { color = Colors.blue.shade800; diag = '過剰人気⚠'; }
    else if (gap <= -3) { color = Colors.blue.shade400; diag = '人気先行'; }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(gap > 0 ? '+$gap' : '$gap', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(diag, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}