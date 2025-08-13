// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';


class ShutubaTablePage extends StatefulWidget {
  final String raceId;

  const ShutubaTablePage({Key? key, required this.raceId}) : super(key: key);

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

class _ShutubaTablePageState extends State<ShutubaTablePage> {
  late Future<PredictionRaceData?> _predictionRaceDataFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadShutubaData();
  }

  Future<void> _loadShutubaData() async {
    setState(() {
      _predictionRaceDataFuture = _loadDataWithUserMarks();
    });
  }

  /// ユーザーの印情報を取得し、レースデータにマージする
  Future<PredictionRaceData?> _loadDataWithUserMarks() async {
    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
    if (userId == null) {
      // ユーザーがいない場合は印なしのデータを表示
      return await ScraperService.scrapeFullPredictionData(widget.raceId);
    }

    // 1. まず、スクレイピングで基本的なレースデータを取得
    final raceData = await ScraperService.scrapeFullPredictionData(widget.raceId);
    if (raceData == null) {
      return null;
    }

    // 2. 次に、このユーザーの印データとメモデータをDBから並行して取得
    final results = await Future.wait([
      _dbHelper.getAllUserMarksForRace(userId, widget.raceId),
      _dbHelper.getMemosForRace(userId, widget.raceId),
    ]);

    final userMarks = results[0] as List<UserMark>;
    final userMemos = results[1] as List<HorseMemo>;

    final marksMap = {for (var mark in userMarks) mark.horseId: mark};
    final memosMap = {for (var memo in userMemos) memo.horseId: memo};


    // 3. レースデータにユーザーの印とメモ情報を付加する
    for (var horse in raceData.horses) {
      if (marksMap.containsKey(horse.horseId)) {
        horse.userMark = marksMap[horse.horseId];
      }
      if (memosMap.containsKey(horse.horseId)) {
        horse.userMemo = memosMap[horse.horseId];
      }
    }

    return raceData;
  }

  /// 過去レースの詳細情報をポップアップで表示するメソッド
  void _showPastRaceDetailsPopup(BuildContext context, HorseRaceRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(record.raceName),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('日付:', record.date),
                _buildDetailRow('開催:', record.venue),
                _buildDetailRow('天候/馬場:', '${record.weather} / ${record.trackCondition}'),
                _buildDetailRow('R:', record.raceNumber),
                _buildDetailRow('頭数:', record.numberOfHorses),
                _buildDetailRow('枠/馬:', '${record.frameNumber} / ${record.horseNumber}'),
                _buildDetailRow('人気/オッズ:', '${record.popularity}番人気 / ${record.odds}倍'),
                _buildDetailRow('着順:', record.rank),
                _buildDetailRow('騎手/斤量:', '${record.jockey} / ${record.carriedWeight}kg'),
                _buildDetailRow('距離:', record.distance),
                _buildDetailRow('タイム/着差:', '${record.time} / ${record.margin}'),
                _buildDetailRow('通過:', record.cornerPassage),
                _buildDetailRow('ペース/上り:', '${record.pace} / ${record.agari}'),
                _buildDetailRow('馬体重:', record.horseWeight),
                _buildDetailRow('勝ち馬:', record.winnerOrSecondHorse),
                _buildDetailRow('賞金:', record.prizeMoney),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// ポップアップ内の詳細表示用のヘルパーウィジェット
  Widget _buildDetailRow(String label, String value) {
    if (value.trim().isEmpty || value.trim() == '-') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showMemoDialog(PredictionHorseDetail horse) async {
    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
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
              maxLines: null, // 複数行の入力を許可
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
                    // 既存のメモがあればそのIDと総評メモを引き継ぐ
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: memoController.text,
                    reviewMemo: horse.userMemo?.reviewMemo, // 既存の総評メモを保持
                    timestamp: DateTime.now(),
                  );
                  await _dbHelper.insertOrUpdateHorseMemo(newMemo);
                  Navigator.of(context).pop();
                  _loadShutubaData(); // データを再読み込みしてUIを更新
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
    // ヘッダー行
    rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'predictionMemo', 'reviewMemo']);

    // データ行
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
    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
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
        return; // ユーザーがファイル選択をキャンセル
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final csvString = await file.readAsString();

      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) {
        throw Exception('CSVファイルにデータがありません。');
      }
      // ヘッダーの検証
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

      await _dbHelper.insertOrUpdateMultipleMemos(memosToUpdate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${memosToUpdate.length}件のメモをインポートしました。')),
      );
      _loadShutubaData(); // データを再読み込み

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出馬表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'メモをインポート',
            onPressed: _importMemosFromCsv,
          ),
          FutureBuilder<PredictionRaceData?>(
            future: _predictionRaceDataFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'メモをエクスポート',
                  onPressed: () => _exportMemosAsCsv(snapshot.data!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<PredictionRaceData?>(
        future: _predictionRaceDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('レース情報が見つかりませんでした。ID: ${widget.raceId}'));
          }

          final predictionData = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _loadShutubaData,
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                _buildRaceInfoCard(predictionData),
                const SizedBox(height: 8),
                _buildHorseDataTable(predictionData.horses),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRaceInfoCard(PredictionRaceData race) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${race.raceDate} ${race.venue} ${race.raceNumber}R',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              race.raceName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(race.raceDetails1 ?? ''),
          ],
        ),
      ),
    );
  }

  /// 馬リストを表形式で表示するウィジェット
  Widget _buildHorseDataTable(List<PredictionHorseDetail> horses) {
    horses.sort((a, b) => a.horseNumber.compareTo(b.horseNumber));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12.0,
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('メモ')),
          DataColumn(label: Text('印')),
          DataColumn(label: Text('枠')),
          DataColumn(label: Text('馬番')),
          DataColumn(label: Text('馬名')),
          DataColumn(label: Text('性齢')),
          DataColumn(label: Text('斤量')),
          DataColumn(label: Text('騎手')),
          DataColumn(label: Text('調教師')),
          DataColumn(label: Text('馬体重')),
          DataColumn(label: Text('前走')),
          DataColumn(label: Text('前々走')),
          DataColumn(label: Text('3走前')),
          DataColumn(label: Text('4走前')),
          DataColumn(label: Text('5走前')),
        ],
        rows: horses.map((horse) {
          return DataRow(
            cells: [
              DataCell(
                _buildMemoCell(horse),
              ),
              DataCell(
                horse.isScratched
                    ? const Text('取消', style: TextStyle(color: Colors.red))
                    : _buildMarkDropdown(horse),
              ),
              DataCell(_buildGateNumber(horse.gateNumber)),
              DataCell(_buildHorseNumber(horse.horseNumber, horse.gateNumber)),
              DataCell(
                Text(
                  horse.horseName,
                  style: TextStyle(
                    decoration: horse.isScratched ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              DataCell(Text(horse.sexAndAge)),
              DataCell(Text(horse.carriedWeight.toString())),
              DataCell(Text(horse.jockey)),
              DataCell(Text(horse.trainer)),
              DataCell(Text(horse.horseWeight ?? '--')),
              ..._buildPastRaceCells(horse.horseId),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 印のドロップダウンを作成
  Widget _buildMarkDropdown(PredictionHorseDetail horse) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: horse.userMark?.mark,
        hint: const Icon(Icons.edit_note, size: 20),
        items: <String>['◎', '〇', '▲', '△', '✕', '消', '　'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(fontSize: 16.0)),
          );
        }).toList(),
        onChanged: (String? newValue) async {
          final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
          if (newValue != null && userId != null) {
            final userMark = UserMark(
              userId: userId,
              raceId: widget.raceId,
              horseId: horse.horseId,
              mark: newValue,
              timestamp: DateTime.now(),
            );
            await _dbHelper.insertOrUpdateUserMark(userMark);
            setState(() {
              horse.userMark = userMark;
            });
          }
        },
      ),
    );
  }

  Widget _buildMemoCell(PredictionHorseDetail horse) {
    bool hasMemo = horse.userMemo?.predictionMemo != null && horse.userMemo!.predictionMemo!.isNotEmpty;
    return IconButton(
      icon: Icon(
        hasMemo ? Icons.speaker_notes : Icons.speaker_notes_off_outlined,
        color: hasMemo ? Colors.blueAccent : Colors.grey,
        size: 20,
      ),
      onPressed: horse.isScratched ? null : () => _showMemoDialog(horse),
    );
  }

  /// 枠番表示を作成
  Widget _buildGateNumber(int gateNumber) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _getGateColor(gateNumber),
        border: gateNumber == 1 ? Border.all(color: Colors.grey) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        gateNumber.toString(),
        style: TextStyle(
          color: _getTextColorForGate(gateNumber),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 馬番表示を作成
  Widget _buildHorseNumber(int horseNumber, int gateNumber) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(
          color: _getGateColor(gateNumber),
          width: 2.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        horseNumber.toString(),
        style: TextStyle(
          color: _getGateColor(gateNumber) == Colors.black ? Colors.black : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 過去5走分のセルを作成
  List<DataCell> _buildPastRaceCells(String horseId) {
    return [
      for (int i = 0; i < 5; i++)
        DataCell(
          FutureBuilder<List<HorseRaceRecord>>(
            future: _dbHelper.getHorsePerformanceRecords(horseId),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.length > i) {
                final record = snapshot.data![i];

                Color backgroundColor = Colors.transparent;
                bool isTopThree = false;

                switch (record.rank) {
                  case '1':
                    backgroundColor = Colors.red.withOpacity(0.4);
                    isTopThree = true;
                    break;
                  case '2':
                    backgroundColor = Colors.grey.withOpacity(0.5);
                    isTopThree = true;
                    break;
                  case '3':
                    backgroundColor = Colors.yellow.withOpacity(0.5);
                    isTopThree = true;
                    break;
                }

                return InkWell(
                  onTap: () => _showPastRaceDetailsPopup(context, record),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isTopThree)
                          Text(
                            record.rank,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        Text(
                          record.raceName,
                          style: const TextStyle(color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
    ];
  }

  // 枠番の色分けロジック
  Color _getGateColor(int gateNumber) {
    switch (gateNumber) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink.shade200;
      default: return Colors.grey;
    }
  }

  Color _getTextColorForGate(int gateNumber) {
    switch (gateNumber) {
      case 1:
      case 5:
        return Colors.black;
      default:
        return Colors.white;
    }
  }
}