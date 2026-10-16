// lib/widgets/volatility_components/past_race_lift_table_card.dart

// [追加] ローテ・血統タブのリフト化 Step3: 過去の出走馬を路線・父・母父ごとに数えた表（着度数・複勝率・倍率・今年の頭数）のカード。見た目は全部の作業が終わってから調整する (v.2026.10.16+26101613)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/factor_candidate_selector.dart';
import 'package:hetaumakeiba_v2/logic/analysis/past_race_lift.dart';

class PastRaceLiftTableCard extends StatelessWidget {
  /// カードの見出し（例「過去の出走馬の前走（路線別）」）
  final String title;

  /// 表の1列目の見出し（例「路線」「父」「母父」）
  final String rowHeader;

  final PastRaceLiftTable table;

  /// 今回の出走馬の馬ID → 馬名
  final Map<String, String> horseNames;

  /// 過去に同じ区分の出走が無い今回の出走馬を並べる行の見出し（例「過去に例の無い路線から来た馬」）
  final String noPastLabel;

  const PastRaceLiftTableCard({
    super.key,
    required this.title,
    required this.rowHeader,
    required this.table,
    required this.horseNames,
    required this.noPastLabel,
  });

  @override
  Widget build(BuildContext context) {
    final rows = table.shownRows;
    final noPast = [
      for (final id in table.currentHorsesWithoutPast) horseNames[id] ?? id,
    ];
    final baseShow = table.baseline.rate(FactorMetric.show);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '過去の出走 延べ${table.countedStarts}頭'
              '${table.missingStarts > 0 ? '・データが無く数えていない 延べ${table.missingStarts}頭' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text(
                '表に出せるデータがありません。',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12.0,
                  headingRowHeight: 32.0,
                  dataRowMinHeight: 28.0,
                  dataRowMaxHeight: 40.0,
                  columns: [
                    DataColumn(
                        label: Text(rowHeader,
                            style: const TextStyle(fontSize: 12))),
                    const DataColumn(
                        label: Text('着度数', style: TextStyle(fontSize: 12))),
                    const DataColumn(
                        label: Text('複勝率', style: TextStyle(fontSize: 12)),
                        numeric: true),
                    const DataColumn(
                        label: Text('倍率', style: TextStyle(fontSize: 12)),
                        numeric: true),
                    const DataColumn(
                        label: Text('今年', style: TextStyle(fontSize: 12)),
                        numeric: true),
                  ],
                  rows: rows.map((row) {
                    final lift =
                        table.liftsOf(row)[FactorMetric.show] ?? 0.0;
                    final currentCount = row.currentHorseIds.length;
                    return DataRow(cells: [
                      DataCell(Text(row.label,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(row.recordText,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                          '${row.rateFor(FactorMetric.show).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${lift.toStringAsFixed(2)}倍',
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                          currentCount > 0 ? '$currentCount頭' : '-',
                          style: const TextStyle(fontSize: 12))),
                    ]);
                  }).toList(),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '※ 倍率は複勝率を、過去の出走馬全体の複勝率（${baseShow.toStringAsFixed(1)}%）で割った値です。'
              '過去に1頭だけの行は、その馬が3着以内のときだけ出しています。'
              '「今年」は今回の出走馬のうち同じ$rowHeaderの頭数です。',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
            if (noPast.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '$noPastLabel: ${noPast.join('、')}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
