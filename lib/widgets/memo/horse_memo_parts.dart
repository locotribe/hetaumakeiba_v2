// lib/widgets/memo/horse_memo_parts.dart

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hetaumakeiba_v2/utils/memo_csv_util.dart'; // [追加] CSVメモ入出力改善 (v.2026.9.24+26092401)

// [追加] 馬詳細タブStep2: メモタブ（memo_tab.dart）のメモ入力ダイアログ・過去メモ・CSV入出力をここへ移した。
// 見た目・文言・処理内容は移す前と同じ。馬詳細タブ（Step3）からも使う (v.2026.9.23+26092307)

/// 過去メモ1走分の表示用データ
class PastMemoDetail {
  final String raceName;
  final String date;
  final String rank; // "1着", "取消" など
  final String predictionMemo;
  final String reviewMemo;

  PastMemoDetail({
    required this.raceName,
    required this.date,
    required this.rank,
    required this.predictionMemo,
    required this.reviewMemo,
  });
}

/// 過去メモの対象の走（今回のレースを除いた直近5走）
List<HorseRaceRecord> selectPastMemoTargetRecords(
    List<HorseRaceRecord> records, String currentRaceId) {
  return records
      .where((r) => r.raceId.isNotEmpty && r.raceId != currentRaceId)
      .take(5)
      .toList();
}

/// 対象の走のうち、予想メモか回顧メモがある走だけを表示用データにする
List<PastMemoDetail> buildPastMemoDetails(
    List<HorseRaceRecord> targetRecords, Map<String, HorseMemo> memosByRaceId) {
  final List<PastMemoDetail> details = [];

  for (final record in targetRecords) {
    final memo = memosByRaceId[record.raceId];

    if (memo != null &&
        ((memo.predictionMemo != null && memo.predictionMemo!.isNotEmpty) ||
            (memo.reviewMemo != null && memo.reviewMemo!.isNotEmpty))) {

      String date = record.date.replaceAll('-', '/').replaceAll('年', '/').replaceAll('月', '/').replaceAll('日', '');
      if (date.startsWith('20')) {
        date = date.substring(2);
      }

      final rankInt = int.tryParse(record.rank);
      String rankText = rankInt != null ? '${rankInt}着' : (record.rank.isNotEmpty ? record.rank : '他');

      details.add(PastMemoDetail(
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

/// 過去メモ（直近5走のうちメモがある走）を読み込む
Future<List<PastMemoDetail>> fetchPastMemoDetails({
  required String horseId,
  required String currentRaceId,
}) async {
  final userId = UserSession().localUserId;
  if (userId == null) return [];

  final horseRepo = HorseRepository();
  final records = await horseRepo.getHorsePerformanceRecords(horseId);

  final targetRecords = selectPastMemoTargetRecords(records, currentRaceId);

  if (targetRecords.isEmpty) return [];

  final raceIds = targetRecords.map((r) => r.raceId).toList();

  final memos = await horseRepo.getMemosForHorseByRaceIds(userId, horseId, raceIds);

  final memosMap = {for (var m in memos) m.raceId: m};

  return buildPastMemoDetails(targetRecords, memosMap);
}

/// 予想メモの入力ダイアログ。保存したときは保存したメモを返す（キャンセル・未ログインは null）
Future<HorseMemo?> showPredictionMemoDialog(
  BuildContext context, {
  required PredictionHorseDetail horse,
  required String raceId,
}) async {
  final userId = UserSession().localUserId;
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ログインが必要です。')),
    );
    return null;
  }

  final memoController = TextEditingController(text: horse.userMemo?.predictionMemo);
  final formKey = GlobalKey<FormState>();
  final horseRepo = HorseRepository();

  return showDialog<HorseMemo>(
    context: context,
    builder: (dialogContext) {
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newMemo = HorseMemo(
                  id: horse.userMemo?.id,
                  userId: userId,
                  raceId: raceId,
                  horseId: horse.horseId,
                  predictionMemo: memoController.text,
                  reviewMemo: horse.userMemo?.reviewMemo,
                  odds: horse.userMemo?.odds,
                  popularity: horse.userMemo?.popularity,
                  timestamp: DateTime.now(),
                );
                await horseRepo.insertOrUpdateHorseMemo(newMemo);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(newMemo);
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

/// このレースの「予想メモ」を CSV にして共有する
Future<void> exportMemosAsCsv({
  required String raceId,
  required PredictionRaceData raceData,
}) async {
  final List<List<dynamic>> rows = [];
  // [修正] CSVメモ入出力改善: 予想メモCSVは予想メモのみ。回顧メモ列は出力しない (v.2026.9.24+26092401)
  rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'predictionMemo']);

  for (final horse in raceData.horses) {
    rows.add([
      raceId,
      horse.horseId,
      horse.horseNumber,
      horse.horseName,
      horse.userMemo?.predictionMemo ?? '',
    ]);
  }

  final String csv = const ListToCsvConverter().convert(rows);

  // [修正] CSVメモ入出力改善: ファイル名を「レースID_日付_レース名_予想メモ.csv」にする (v.2026.9.24+26092401)
  final fileName = buildMemoCsvFileName(
    raceId: raceId,
    raceDate: raceData.raceDate,
    raceName: raceData.raceName,
    suffix: '予想メモ',
  );

  final directory = await getTemporaryDirectory();
  final path = '${directory.path}/$fileName';
  final file = File(path);
  await file.writeAsString(csv);

  await Share.shareXFiles([XFile(path, name: fileName)], text: '${raceData.raceName} の予想メモ');
}

/// CSV からこのレースの「予想メモ」を取り込む。取り込んだ件数を返す（取り消し・未ログイン・エラーは null）
Future<int?> importMemosFromCsv(
  BuildContext context, {
  required String raceId,
}) async {
  final userId = UserSession().localUserId;
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ログインが必要です。')),
    );
    return null;
  }

  try {
    // [修正] CSVメモ入出力改善: Googleドライブ等のCSVも選べるよう FileType.any にし、選択後に拡張子を確認 (v.2026.9.24+26092401)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final picked = result.files.single;
    final ext = (picked.extension ?? '').toLowerCase();
    final filePath = picked.path!;
    if (ext != 'csv' && !filePath.toLowerCase().endsWith('.csv')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVファイルを選択してください。')),
      );
      return null;
    }

    final file = File(filePath);
    final csvString = await file.readAsString();

    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

    if (rows.length < 2) {
      throw Exception('CSVファイルにデータがありません。');
    }
    // [修正] CSVメモ入出力改善: 予想メモCSV専用のヘッダー。回顧メモCSVや旧形式は弾く (v.2026.9.24+26092401)
    final header = rows.first.map((e) => e.toString().trim()).toList();
    if (header.join(',') != 'raceId,horseId,horseNumber,horseName,predictionMemo') {
      throw Exception('予想メモ用のCSVを選択してください。（回顧メモCSVや旧形式は取り込めません）');
    }

    // [修正] CSVメモ入出力改善: 既存メモを取得し、回顧メモ・odds・人気・idを保持したまま予想メモだけ更新する (v.2026.9.24+26092401)
    final existingMemos = await HorseRepository().getMemosForRace(userId, raceId);
    final existingMap = {for (var m in existingMemos) m.horseId: m};

    final List<HorseMemo> memosToUpdate = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final csvRaceId = row[0].toString();

      if (csvRaceId != raceId) {
        throw Exception('CSVファイルのレースIDが、現在表示しているレースと一致しません。');
      }

      final horseId = row[1].toString();
      final csvPrediction = row.length > 4 ? row[4].toString() : '';
      final existing = existingMap[horseId];

      memosToUpdate.add(HorseMemo(
        id: existing?.id,
        userId: userId,
        raceId: csvRaceId,
        horseId: horseId,
        predictionMemo: csvPrediction,
        reviewMemo: existing?.reviewMemo,
        odds: existing?.odds,
        popularity: existing?.popularity,
        timestamp: DateTime.now(),
      ));
    }

    await HorseRepository().insertOrUpdateMultipleMemos(memosToUpdate);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${memosToUpdate.length}件の予想メモをインポートしました。')),
      );
    }
    return memosToUpdate.length;

  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: ${e.toString()}')),
      );
    }
    return null;
  }
}

/// 過去メモの一覧（日付・レース名・着順、[予]・[顧]）
class PastMemoList extends StatelessWidget {
  final List<PastMemoDetail> details;

  const PastMemoList({Key? key, required this.details}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details.map((detail) {
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
    );
  }
}
