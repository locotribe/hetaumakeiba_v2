// lib/screens/race_statistics_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'dart:convert';

class RaceStatisticsPage extends StatefulWidget {
  final String raceId;
  final String raceName;

  const RaceStatisticsPage({
    super.key,
    required this.raceId,
    required this.raceName,
  });

  @override
  State<RaceStatisticsPage> createState() => _RaceStatisticsPageState();
}

class _RaceStatisticsPageState extends State<RaceStatisticsPage> {
  final StatisticsService _statisticsService = StatisticsService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Future<RaceStatistics?>? _statisticsFuture;

  @override
  void initState() {
    super.initState();
    _checkAndLoadStatistics();
  }

  void _checkAndLoadStatistics() {
    setState(() {
      _statisticsFuture = _dbHelper.getRaceStatistics(widget.raceId);
    });
  }

  void _fetchAndLoadStatistics() {
    setState(() {
      _statisticsFuture = _statisticsService.processAndSaveRaceStatistics(
        widget.raceId,
        widget.raceName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.raceName} - 過去データ分析'),
      ),
      body: FutureBuilder<RaceStatistics?>(
        future: _statisticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('エラーが発生しました: ${snapshot.error}'),
              ),
            );
          }

          final stats = snapshot.data;
          if (stats == null) {
            return _buildInitialView();
          } else {
            return _buildStatisticsView(stats);
          }
        },
      ),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              '過去10年分のレースデータを取得しますか？',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'データ量に応じて時間がかかる場合があります。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('データ取得を開始'),
              onPressed: _fetchAndLoadStatistics,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsView(RaceStatistics stats) {
    final data = json.decode(stats.statisticsJson);
    final popularityStats = data['popularityStats'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          '人気別成績 (過去${(data['analyzedYears'] as List).length}年)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        _buildPopularityTable(popularityStats),
      ],
    );
  }

  Widget _buildPopularityTable(Map<String, dynamic> stats) {
    final rows = <DataRow>[];
    for (int i = 1; i <= 18; i++) {
      final key = i.toString();
      if (stats.containsKey(key) && (stats[key]['total'] as int) > 0) {
        final data = stats[key] as Map<String, dynamic>;
        final total = data['total'] as int;
        final win = data['win'] as int;
        final place = data['place'] as int;
        final show = data['show'] as int;

        rows.add(DataRow(
          cells: [
            DataCell(Text('$i番人気')),
            DataCell(Text('${(win / total * 100).toStringAsFixed(1)}% ($win/$total)')),
            DataCell(Text('${(place / total * 100).toStringAsFixed(1)}% ($place/$total)')),
            DataCell(Text('${(show / total * 100).toStringAsFixed(1)}% ($show/$total)')),
          ],
        ));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('人気')),
          DataColumn(label: Text('勝率'), numeric: true),
          DataColumn(label: Text('連対率'), numeric: true),
          DataColumn(label: Text('複勝率'), numeric: true),
        ],
        rows: rows,
      ),
    );
  }
}