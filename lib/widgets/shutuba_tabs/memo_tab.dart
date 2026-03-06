// lib/widgets/shutuba_tabs/memo_tab.dart

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/bulk_memo_edit_page.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/info_tab.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class _PastMemoDetail {
  final String raceName;
  final String date;
  final String rank; // "1着", "取消" など
  final String predictionMemo;
  final String reviewMemo;

  _PastMemoDetail({
    required this.raceName,
    required this.date,
    required this.rank,
    required this.predictionMemo,
    required this.reviewMemo,
  });
}

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
  final VoidCallback reloadData;

  const MemoTabWidget({
    Key? key,
    required this.raceId,
    required this.predictionRaceData,
    required this.horses,
    required this.onSort,
    required this.buildMarkDropdown,
    required this.buildDataTableForTab,
    required this.reloadData,
  }) : super(key: key);

  @override
  State<MemoTabWidget> createState() => _MemoTabWidgetState();
}

class _MemoTabWidgetState extends State<MemoTabWidget> {
  final HorseRepository _horseRepo = HorseRepository();

  Future<void> _showMemoDialog(PredictionHorseDetail horse) async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final memoController = TextEditingController(text: horse.userMemo?.predictionMemo);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${horse.horseName} - 予想メモ'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: memoController,
              autofocus: true,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'ここにメモを入力...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newMemo = HorseMemo(
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: memoController.text,
                    reviewMemo: horse.userMemo?.reviewMemo,
                    odds: horse.userMemo?.odds,
                    popularity: horse.userMemo?.popularity,
                    timestamp: DateTime.now(),
                  );
                  await _horseRepo.insertOrUpdateHorseMemo(newMemo);
                  if (mounted) {
                    Navigator.of(context).pop();
                    widget.reloadData();
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportMemosAsCsv(PredictionRaceData raceData) async {
    final List<List<dynamic>> rows = [];
    rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'predictionMemo', 'reviewMemo']);

    for (final horse in raceData.horses) {
      rows.add([
        widget.raceId,
        horse.horseId,
        horse.horseNumber,
        horse.horseName,
        horse.userMemo?.predictionMemo ?? '',
        horse.userMemo?.reviewMemo ?? '',
      ]);
    }

    final String csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${widget.raceId}_memos.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: '${raceData.raceName} のメモ');
  }

  Future<void> _importMemosFromCsv() async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final csvString = await file.readAsString();

      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) {
        throw Exception('CSVファイルにデータがありません。');
      }
      final header = rows.first;
      if (header.join(',') != 'raceId,horseId,horseNumber,horseName,predictionMemo,reviewMemo') {
        throw Exception('CSVファイルのヘッダー形式が正しくありません。');
      }

      final List<HorseMemo> memosToUpdate = [];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final csvRaceId = row[0].toString();

        if (csvRaceId != widget.raceId) {
          throw Exception('CSVファイルのレースIDが、現在表示しているレースと一致しません。');
        }

        memosToUpdate.add(HorseMemo(
          userId: userId,
          raceId: csvRaceId,
          horseId: row[1].toString(),
          predictionMemo: row[4].toString(),
          reviewMemo: row[5].toString(),
          timestamp: DateTime.now(),
        ));
      }

      await _horseRepo.insertOrUpdateMultipleMemos(memosToUpdate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${memosToUpdate.length}件のメモをインポートしました。')),
        );
        widget.reloadData();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポートエラー: ${e.toString()}')),
        );
      }
    }
  }

  Future<List<_PastMemoDetail>> _fetchPastMemoDetails(String horseId) async {
    final userId = localUserId;
    if (userId == null) return [];

    final records = await _horseRepo.getHorsePerformanceRecords(horseId);

    final targetRecords = records
        .where((r) => r.raceId.isNotEmpty && r.raceId != widget.raceId)
        .take(5)
        .toList();

    if (targetRecords.isEmpty) return [];

    final raceIds = targetRecords.map((r) => r.raceId).toList();

    final memos = await _horseRepo.getMemosForHorseByRaceIds(userId, horseId, raceIds);

    final memosMap = {for (var m in memos) m.raceId: m};

    final List<_PastMemoDetail> details = [];

    for (final record in targetRecords) {
      final memo = memosMap[record.raceId];

      if (memo != null &&
          ((memo.predictionMemo != null && memo.predictionMemo!.isNotEmpty) ||
              (memo.reviewMemo != null && memo.reviewMemo!.isNotEmpty))) {

        String date = record.date.replaceAll('-', '/').replaceAll('年', '/').replaceAll('月', '/').replaceAll('日', '');
        if (date.startsWith('20')) {
          date = date.substring(2);
        }

        final rankInt = int.tryParse(record.rank);
        String rankText = rankInt != null ? '${rankInt}着' : (record.rank.isNotEmpty ? record.rank : '他');

        details.add(_PastMemoDetail(
          raceName: record.raceName,
          date: date,
          rank: rankText,
          predictionMemo: memo.predictionMemo ?? '',
          reviewMemo: memo.reviewMemo ?? '',
        ));
      }
    }

    return details;
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
          onPressed: horse.isScratched ? null : () => _showMemoDialog(horse),
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
                  if (result == true) {
                    widget.reloadData();
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
                onPressed: _importMemosFromCsv,
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
                  _exportMemosAsCsv(widget.predictionRaceData);
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
                FutureBuilder<List<_PastMemoDetail>>(
                  future: _fetchPastMemoDetails(horse.horseId),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: snapshot.data!.map((detail) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${detail.date} ${detail.raceName} (${detail.rank})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                if (detail.predictionMemo.isNotEmpty)
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style.copyWith(fontSize: 11),
                                      children: [
                                        const TextSpan(text: '[予] ', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                        TextSpan(text: detail.predictionMemo),
                                      ],
                                    ),
                                  ),
                                if (detail.reviewMemo.isNotEmpty)
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style.copyWith(fontSize: 11),
                                      children: [
                                        const TextSpan(text: '[顧] ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                        TextSpan(text: detail.reviewMemo),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
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