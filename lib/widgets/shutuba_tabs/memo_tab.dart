// lib/widgets/shutuba_tabs/memo_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/bulk_memo_edit_page.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/info_tab.dart';
// [修正] 馬詳細タブStep2: メモ入力ダイアログ・過去メモ・CSV入出力を共通ファイルに移した。見た目は変更なし (v.2026.9.23+26092307)
import 'package:hetaumakeiba_v2/widgets/memo/horse_memo_parts.dart';

class MemoTabWidget extends StatefulWidget {
  final String raceId;
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) buildDataTableForTab;
  // [修正] 馬詳細タブStep2: 保存後に出馬表を丸ごと取り直す reloadData をやめ、
  // 1頭の保存は onMemoSaved、一括編集・インポートは reloadMemos（メモだけ読み直す）にした (v.2026.9.23+26092307)
  final void Function(PredictionHorseDetail horse, HorseMemo memo) onMemoSaved;
  final Future<void> Function() reloadMemos;

  const MemoTabWidget({
    Key? key,
    required this.raceId,
    required this.predictionRaceData,
    required this.horses,
    required this.onSort,
    required this.buildMarkDropdown,
    required this.buildDataTableForTab,
    required this.onMemoSaved,
    required this.reloadMemos,
  }) : super(key: key);

  @override
  State<MemoTabWidget> createState() => _MemoTabWidgetState();
}

class _MemoTabWidgetState extends State<MemoTabWidget> {
  Future<void> _editMemo(PredictionHorseDetail horse) async {
    final memo = await showPredictionMemoDialog(
      context,
      horse: horse,
      raceId: widget.raceId,
    );
    if (memo != null && mounted) {
      widget.onMemoSaved(horse, memo);
    }
  }

  Future<void> _importMemos() async {
    final count = await importMemosFromCsv(context, raceId: widget.raceId);
    if (count != null && mounted) {
      await widget.reloadMemos();
    }
  }

  Widget _buildMemoCell(PredictionHorseDetail horse) {
    bool hasMemo = horse.userMemo?.predictionMemo != null && horse.userMemo!.predictionMemo!.isNotEmpty;
    return Row(
      children: [
        IconButton(
          icon: Icon(
            hasMemo ? Icons.speaker_notes : Icons.speaker_notes_off_outlined,
            color: hasMemo ? Colors.blueAccent : Colors.grey,
            size: 20,
          ),
          onPressed: horse.isScratched ? null : () => _editMemo(horse),
        ),
        Expanded(
          child: Text(
            horse.userMemo?.predictionMemo ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('一括編集'),
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BulkMemoEditPage(
                        horses: widget.predictionRaceData.horses,
                        raceId: widget.raceId,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    await widget.reloadMemos();
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('インポート'),
                onPressed: _importMemos,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('エクスポート'),
                onPressed: () {
                  exportMemosAsCsv(
                    raceId: widget.raceId,
                    raceData: widget.predictionRaceData,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.buildDataTableForTab(
            columns: [
              DataColumn2(label: const Text('印\n枠'), fixedWidth: 40, onSort: (i, asc) => widget.onSort(SortableColumn.horseNumber)),
              DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => widget.onSort(SortableColumn.horseName)),
              const DataColumn2(label: Text('今回の予想'), size: ColumnSize.M),
              const DataColumn2(label: Text('過去メモ(直近5走)'), size: ColumnSize.L),
            ],
            horses: widget.horses,
            cellBuilder: (horse) => [
              DataCell(MarkAndGateCell(horse: horse, buildMarkDropdown: widget.buildMarkDropdown)),
              DataCell(
                Text(
                  horse.horseName,
                  style: TextStyle(
                    decoration: horse.isScratched ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              DataCell(_buildMemoCell(horse)),
              DataCell(
                FutureBuilder<List<PastMemoDetail>>(
                  future: fetchPastMemoDetails(
                    horseId: horse.horseId,
                    currentRaceId: widget.raceId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('-', style: TextStyle(color: Colors.grey));
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: PastMemoList(details: snapshot.data!),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
