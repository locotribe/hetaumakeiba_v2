// lib/widgets/shutuba_tabs/training_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/services/training_data_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';

class TrainingTabWidget extends StatefulWidget {
  final String raceId;
  final String raceDate;
  final List<PredictionHorseDetail> horses;

  const TrainingTabWidget({
    Key? key,
    required this.raceId,
    required this.raceDate,
    required this.horses,
  }) : super(key: key);

  @override
  State<TrainingTabWidget> createState() => _TrainingTabWidgetState();
}

class _TrainingTabWidgetState extends State<TrainingTabWidget> {
  final TrainingRepository _repository = TrainingRepository();
  final TrainingDataService _service = TrainingDataService();
  Map<String, List<TrainingTimeModel>> _trainingData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
  }

  Future<void> _loadTrainingData() async {
    setState(() { _isLoading = true; });
    Map<String, List<TrainingTimeModel>> newData = {};
    for (var horse in widget.horses) {
      final records = await _repository.getTrainingTimesForHorse(horse.horseId);
      newData[horse.horseId] = records;
    }
    if (mounted) {
      setState(() {
        _trainingData = newData;
        _isLoading = false;
      });
    }
  }

  // どんな日付形式でもAPIが求める 'YYYYMMDD' (8桁) に変換する
  String _formatDateForApi(String rawDate) {
    final RegExp regExp = RegExp(r'(\d{4})[年/\-]\s*(\d{1,2})[月/\-]\s*(\d{1,2})');
    final match = regExp.firstMatch(rawDate);
    if (match != null) {
      final y = match.group(1)!;
      final m = match.group(2)!.padLeft(2, '0');
      final d = match.group(3)!.padLeft(2, '0');
      return '$y$m$d';
    }
    return rawDate.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _fetchFromApi() {
    final formattedDate = _formatDateForApi(widget.raceDate);
    final horseIds = widget.horses.map((h) => h.horseId).toList();

    print('DEBUG: [Training API] Request Date: $formattedDate, RaceID: ${widget.raceId}');

    ScrapingManager().addRequest('調教データ取得', () async {
      await _service.fetchAndSaveTrainingData(
        raceId: widget.raceId,
        raceDate: formattedDate,
        horseIds: horseIds,
      );
      if (mounted) {
        await _loadTrainingData();
      }
    });
  }

  // YYYYMMDD -> YYYY年M月D日(曜) に変換
  String _formatDateJP(String yyyymmdd) {
    if (yyyymmdd.length != 8) return yyyymmdd;
    try {
      final date = DateTime.parse(yyyymmdd);
      final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      final weekdayStr = weekdays[date.weekday - 1];
      return DateFormat('yyyy年M月d日').format(date) + '($weekdayStr)';
    } catch (e) {
      return yyyymmdd;
    }
  }

  // HHmm -> HH時mm分 に変換
  String _formatTimeJP(String hhmm) {
    if (hhmm.length != 4) return hhmm;
    return '${hhmm.substring(0, 2)}時${hhmm.substring(2, 4)}分';
  }

  // タイム表示とラップ計算・色付け用のウィジェット
  Widget _buildTimeAndLapRow(TrainingTimeModel r) {
    // データがあるハロンだけを抽出
    List<Map<String, dynamic>> furlongs = [];
    if (r.f6 != null) furlongs.add({'label': '6F', 'time': r.f6!});
    if (r.f5 != null) furlongs.add({'label': '5F', 'time': r.f5!});
    if (r.f4 != null) furlongs.add({'label': '4F', 'time': r.f4!});
    if (r.f3 != null) furlongs.add({'label': '3F', 'time': r.f3!});
    if (r.f2 != null) furlongs.add({'label': '2F', 'time': r.f2!});
    if (r.f1 != null) furlongs.add({'label': '1F', 'time': r.f1!});

    if (furlongs.isEmpty) return const Text('タイムデータなし');

    // ラップタイムの計算
    List<double?> laps = [];
    for (int i = 0; i < furlongs.length; i++) {
      if (i == 0) {
        laps.add(null); // 最初の区間は前のデータがないためラップなし(全体の最初のタイムそのままは出さない)
      } else {
        // 前のハロンタイム - 今のハロンタイム = その1Fのラップ
        double lap = furlongs[i - 1]['time'] - furlongs[i]['time'];
        laps.add(double.parse(lap.toStringAsFixed(1)));
      }
    }
    // 最後の1Fはそのままがラップになることが多いが、念のため
    laps[furlongs.length - 1] = furlongs.last['time'];

    // ラップ色の判定（最後の1Fが、その前のラップより速いか遅いか）
    Color lastLapColor = Colors.black87;
    if (laps.length >= 2 && laps.last != null && laps[laps.length - 2] != null) {
      if (laps.last! < laps[laps.length - 2]!) {
        lastLapColor = Colors.red; // 加速ラップ
      } else if (laps.last! > laps[laps.length - 2]!) {
        lastLapColor = Colors.blue; // 減速ラップ
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー (ハロン)
        Row(
          children: furlongs.map((f) => SizedBox(
              width: 45,
              child: Text(f['label'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey))
          )).toList(),
        ),
        // 全体時計
        Row(
          children: furlongs.map((f) => SizedBox(
              width: 45,
              child: Text(f['time'].toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))
          )).toList(),
        ),
        // ラップタイム
        Row(
          children: List.generate(furlongs.length, (i) {
            final isLast = i == furlongs.length - 1;
            final lapText = laps[i] != null ? '(${laps[i]!.toStringAsFixed(1)})' : '-';
            return SizedBox(
              width: 45,
              child: Text(
                lapText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isLast ? lastLapColor : Colors.grey[700],
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text('※直近の調教タイム・ラップ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              OutlinedButton.icon(
                onPressed: _fetchFromApi,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('調教データを取得'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: widget.horses.length,
            itemBuilder: (context, index) {
              final horse = widget.horses[index];
              final records = _trainingData[horse.horseId] ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Text(
                    '${horse.horseNumber}番 ${horse.horseName}',
                    style: TextStyle(
                      decoration: horse.isScratched ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // サブタイトル（最新の日付・場所）
                  subtitle: Text(
                    records.isNotEmpty
                        ? '最新: ${_formatDateJP(records.first.trainingDate)} (${records.first.trackType} / ${records.first.location})'
                        : '調教データなし',
                    style: TextStyle(color: records.isNotEmpty ? Colors.black87 : Colors.grey, fontSize: 13),
                  ),
                  children: records.map((r) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 日付・時間・場所
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_formatDateJP(r.trainingDate)}  ${_formatTimeJP(r.trainingTime)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.trackType == 'ウッド' ? Colors.green.shade100 : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${r.trackType} / ${r.location}',
                                    style: TextStyle(fontSize: 12, color: r.trackType == 'ウッド' ? Colors.green.shade800 : Colors.orange.shade800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // タイム・ラップ表示
                          _buildTimeAndLapRow(r),
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
    );
  }
}