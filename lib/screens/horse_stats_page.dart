// lib/screens/horse_stats_page.dart

import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/horse_stats_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';

class HorseStatsPage extends StatefulWidget {
  final String raceId;
  final String raceName;
  final List<PredictionHorseDetail> horses;

  const HorseStatsPage({
    super.key,
    required this.raceId,
    required this.raceName,
    required this.horses,
  });

  @override
  State<HorseStatsPage> createState() => _HorseStatsPageState();
}

class _HorseStatsPageState extends State<HorseStatsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  String _loadingMessage = '';
  double _loadingProgress = 0.0;
  Map<String, HorseStats> _statsMap = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _showConfirmationDialog();
  }

  Future<void> _showConfirmationDialog() async {
    // WidgetsBinding.instance.addPostFrameCallback ensures that the dialog is shown
    // after the first frame is rendered, which is necessary when showing a dialog in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('過去データ取得の確認'),
          content: const Text('全出走馬の全過去レース結果を取得します。データ量に応じて時間がかかる場合があります。よろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('取得開始'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        _fetchAndCalculateStats();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _fetchAndCalculateStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingMessage = '出走馬の過去成績を取得中...';
      _loadingProgress = 0.0;
    });

    try {
      // 1. 全出走馬の過去成績から、必要な全レースIDを収集
      final allPastRaceIds = <String>{};
      final Map<String, List<HorseRaceRecord>> allPerformanceRecords = {};

      for (final horse in widget.horses) {
        final records = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
        allPerformanceRecords[horse.horseId] = records;
        for (final record in records) {
          if (record.raceId.isNotEmpty) {
            allPastRaceIds.add(record.raceId);
          }
        }
      }
      // --- DEBUG PRINT START ---
      print('【デバッグ情報】収集した全過去レースID数: ${allPastRaceIds.length}');
      // --- DEBUG PRINT END ---

      // 2. DBにないレース結果のみをダウンロード対象とする
      final existingResults = await _dbHelper.getMultipleRaceResults(allPastRaceIds.toList());
      final raceIdsToFetch = allPastRaceIds.where((id) => !existingResults.containsKey(id)).toList();
      // --- DEBUG PRINT START ---
      print('【デバッグ情報】DBに存在したレース結果数: ${existingResults.length}');
      print('【デバッグ情報】新規にダウンロードするレース結果数: ${raceIdsToFetch.length}');
      // --- DEBUG PRINT END ---

      // 3. 不足しているレース結果をダウンロード
      final Map<String, RaceResult> fetchedResults = {};
      if (raceIdsToFetch.isNotEmpty) {
        for (int i = 0; i < raceIdsToFetch.length; i++) {
          final raceId = raceIdsToFetch[i];
          if (!mounted) return;
          setState(() {
            _loadingMessage = 'レース結果を取得中 (${i + 1}/${raceIdsToFetch.length})';
            _loadingProgress = (i + 1) / raceIdsToFetch.length;
          });
          try {
            // --- DEBUG PRINT START ---
            print('【デバッグ情報】ダウンロード中: $raceId (${i + 1}/${raceIdsToFetch.length})');
            // --- DEBUG PRINT END ---
            final result = await ScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/$raceId');
            await _dbHelper.insertOrUpdateRaceResult(result);
            fetchedResults[raceId] = result;
            await Future.delayed(const Duration(milliseconds: 200)); // サーバー負荷軽減
          } catch (e) {
            print('Failed to fetch race result for $raceId: $e');
          }
        }
      }

      // 4. 全てのレース結果を結合
      final allRaceResults = {...existingResults, ...fetchedResults};

      // 5. 各馬の統計を計算
      final newStatsMap = <String, HorseStats>{};
      for (final horse in widget.horses) {
        final records = allPerformanceRecords[horse.horseId] ?? [];
        newStatsMap[horse.horseId] = HorseStatsAnalyzer.calculate(
          performanceRecords: records,
          raceResults: allRaceResults,
        );
      }

      if (!mounted) return;
      setState(() {
        _statsMap = newStatsMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'データの処理中にエラーが発生しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.raceName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: AnimatedOpacity(
            opacity: _isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_loadingMessage),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16.0,
          columns: const [
            DataColumn(label: Text('馬番')),
            DataColumn(label: Text('馬名')),
            DataColumn(label: Text('出走数'), numeric: true),
            DataColumn(label: Text('勝率'), numeric: true),
            DataColumn(label: Text('連対率'), numeric: true),
            DataColumn(label: Text('複勝率'), numeric: true),
            DataColumn(label: Text('単回率'), numeric: true),
            DataColumn(label: Text('複回率'), numeric: true),
          ],
          rows: widget.horses.map((horse) {
            final stats = _statsMap[horse.horseId] ?? HorseStats();
            return DataRow(
              cells: [
                DataCell(Text(horse.horseNumber.toString())),
                DataCell(Text(horse.horseName)),
                DataCell(Text(stats.raceCount.toString())),
                DataCell(Text('${stats.winRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.placeRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.showRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.winRecoveryRate.toStringAsFixed(1)}%')),
                DataCell(Text('${stats.showRecoveryRate.toStringAsFixed(1)}%')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
