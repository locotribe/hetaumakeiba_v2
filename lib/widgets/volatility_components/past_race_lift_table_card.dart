// lib/widgets/volatility_components/past_race_lift_table_card.dart

// [追加] ローテ・血統タブのリフト化 Step3: 過去の出走馬を路線・父・母父ごとに数えた表（着度数・複勝率・倍率・今年の頭数）のカード。見た目は全部の作業が終わってから調整する (v.2026.10.16+26101613)

import 'package:flutter/material.dart';
// [削除] ローテ・血統タブの見た目の調整 Step2: 複勝率・倍率の列をやめたので factor_candidate_selector.dart の import を外した (v.2026.10.19+26101907)
import 'package:hetaumakeiba_v2/logic/analysis/past_race_lift.dart';
// [追加] ローテ・血統タブの見た目の調整 Step2: 回収率の文字と色 (v.2026.10.19+26101907)
import 'package:hetaumakeiba_v2/widgets/volatility_components/past_race_return_style.dart';

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
    // [修正] ローテ・血統タブの見た目の調整 Step2: 3着以内の多い順に並べ、説明には全体の回収率を出す (v.2026.10.19+26101907)
    final rows = table.shownRowsByShow;
    final noPast = [
      for (final id in table.currentHorsesWithoutPast) horseNames[id] ?? id,
    ];
    final overall = table.overallReturns;

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
                  // [修正] ローテ・血統タブの見た目の調整 Step2: 列を 着度数・単回・複回・今年 にした。横スクロールせずに今年の列まで見えるよう、左右の余白と列の間を詰め、区分名は幅120で2行まで折り返す (v.2026.10.19+26101907)
                  horizontalMargin: 4.0,
                  columnSpacing: 10.0,
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
                        label: Text('単回', style: TextStyle(fontSize: 12)),
                        numeric: true),
                    const DataColumn(
                        label: Text('複回', style: TextStyle(fontSize: 12)),
                        numeric: true),
                    const DataColumn(
                        label: Text('今年', style: TextStyle(fontSize: 12)),
                        numeric: true),
                  ],
                  rows: rows.map((row) {
                    final winReturn = row.returns.winReturn;
                    final showReturn = row.returns.showReturn;
                    final currentCount = row.currentHorseIds.length;
                    return DataRow(cells: [
                      DataCell(SizedBox(
                        width: 120.0,
                        child: Text(row.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      )),
                      DataCell(Text(row.recordText,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(pastRaceReturnText(winReturn),
                          style: TextStyle(
                              fontSize: 12,
                              color: pastRaceReturnColor(
                                  winReturn, row.total)))),
                      DataCell(Text(pastRaceReturnText(showReturn),
                          style: TextStyle(
                              fontSize: 12,
                              color: pastRaceReturnColor(
                                  showReturn, row.total)))),
                      DataCell(Text(
                          currentCount > 0 ? '$currentCount頭' : '-',
                          style: const TextStyle(fontSize: 12))),
                    ]);
                  }).toList(),
                ),
              ),
            const SizedBox(height: 6),
            // [修正] ローテ・血統タブの見た目の調整 Step2: 倍率の説明をやめ、回収率の読み方と全体の回収率・色分けの説明にした (v.2026.10.19+26101907)
            Text(
              '※ 単回・複回は、この$rowHeaderの馬を毎回100円ずつ買ったときの単勝・複勝の回収率です'
              '（単勝はオッズ、複勝は払戻しから計算。オッズ・払戻しの無いレースは除く）。'
              '過去の出走馬全体では 単回 ${pastRaceReturnText(overall.winReturn)}・'
              '複回 ${pastRaceReturnText(overall.showReturn)} です。'
              '200%以上は赤、100%以上はオレンジ、80%未満は灰色です'
              '（過去の出走が${kReturnColorMinStarts - 1}頭以下の行は色を付けません）。'
              '3着以内の多い順に並べています。'
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
