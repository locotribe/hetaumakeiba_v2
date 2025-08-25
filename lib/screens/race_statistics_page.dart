// lib/screens/race_statistics_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

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
    final analyzedYearsCount = (data['analyzedYears'] as List).length;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          '過去$analyzedYearsCount年 データ分析サマリー',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        _buildPayoutTable(data['payoutStats'] ?? const {}),
        const SizedBox(height: 16),
        _buildPopularityTable(data['popularityStats'] ?? const {}),
        const SizedBox(height: 16),
        _buildFrameStatsCard(data['frameStats'] ?? const {}),
        const SizedBox(height: 16),
        _buildLegStyleStatsCard(data['legStyleStats'] ?? const {}),
        const SizedBox(height: 16),
        _buildHorseWeightStatsCard(data['horseWeightChangeStats'] ?? const {}, data['avgWinningHorseWeight'] ?? 0.0),
        const SizedBox(height: 16),
        _buildJockeyStatsTable(data['jockeyStats'] ?? const {}),
        const SizedBox(height: 16),
        _buildTrainerStatsTable(data['trainerStats'] ?? const {}),
      ],
    );
  }

  Widget _buildPopularityTable(Map<String, dynamic> stats) {
    final rows = <DataRow>[];
    final sortedKeys = stats.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    for (final key in sortedKeys) {
      if ((stats[key]['total'] as int) > 0) {
        final data = stats[key] as Map<String, dynamic>;
        final total = data['total'] as int;
        final win = data['win'] as int;
        final place = data['place'] as int;
        final show = data['show'] as int;

        rows.add(DataRow(
          cells: [
            DataCell(Text(key)),
            DataCell(Text('${(win / total * 100).toStringAsFixed(1)}% ($win/$total)')),
            DataCell(Text('${(place / total * 100).toStringAsFixed(1)}% ($place/$total)')),
            DataCell(Text('${(show / total * 100).toStringAsFixed(1)}% ($show/$total)')),
          ],
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('人気別成績', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 8.0,
                columns: const [
                  DataColumn(label: Text('人気')),
                  DataColumn(label: Text('勝率'), numeric: true),
                  DataColumn(label: Text('連対率'), numeric: true),
                  DataColumn(label: Text('複勝率'), numeric: true),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameStatsCard(Map<String, dynamic> stats) {
    final sortedKeys = stats.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('枠番別成績', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...sortedKeys.map((key) {
              final data = stats[key];
              final total = data['total'] as int;
              if (total == 0) return const SizedBox.shrink();
              final winRate = (data['win'] / total * 100);
              final placeRate = (data['place'] / total * 100);
              final showRate = (data['show'] / total * 100);
              return ListTile(
                leading: Text('$key枠', style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text('勝率 ${winRate.toStringAsFixed(1)}% / 連対率 ${placeRate.toStringAsFixed(1)}% / 複勝率 ${showRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13)),
                subtitle: Text('($total回)'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegStyleStatsCard(Map<String, dynamic> stats) {
    final order = ['逃げ', '先行', '差し', '追込'];
    final sortedKeys = stats.keys.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('脚質別成績 (最終コーナー位置)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...sortedKeys.map((key) {
              final data = stats[key];
              final total = data['total'] as int;
              if (total == 0) return const SizedBox.shrink();
              final winRate = (data['win'] / total * 100);
              final placeRate = (data['place'] / total * 100);
              final showRate = (data['show'] / total * 100);
              return ListTile(
                title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('勝率 ${winRate.toStringAsFixed(1)}% / 連対率 ${placeRate.toStringAsFixed(1)}% / 複勝率 ${showRate.toStringAsFixed(1)}%\n($total頭)'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHorseWeightStatsCard(Map<String, dynamic> stats, double avgWeight) {
    final categories = ['-10kg以下', '-4~-8kg', '-2~+2kg', '+4~+8kg', '+10kg以上'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('馬体重別成績', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              leading: const Icon(Icons.scale),
              title: Text('勝ち馬の平均馬体重: ${avgWeight.toStringAsFixed(1)} kg'),
            ),
            const Divider(),
            ...categories.where((cat) => stats.containsKey(cat) && (stats[cat]['total'] as int) > 0).map((key) {
              final data = stats[key];
              final total = data['total'] as int;
              final winRate = (data['win'] / total * 100);
              final placeRate = (data['place'] / total * 100);
              final showRate = (data['show'] / total * 100);
              return ListTile(
                title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('勝率 ${winRate.toStringAsFixed(1)}% / 連対率 ${placeRate.toStringAsFixed(1)}% / 複勝率 ${showRate.toStringAsFixed(1)}% \n($total頭)'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildJockeyStatsTable(Map<String, dynamic> stats) {
    final sortedJockeys = stats.entries.where((e) => e.value['total'] > 1).toList()
      ..sort((a, b) => (b.value['show'] / b.value['total']).compareTo(a.value['show'] / a.value['total']));

    if (sortedJockeys.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('騎手別成績 (2回以上騎乗)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0,
                columns: const [
                  DataColumn(label: Text('騎手')),
                  DataColumn(label: Text('勝率'), numeric: true),
                  DataColumn(label: Text('連対率'), numeric: true),
                  DataColumn(label: Text('複勝率'), numeric: true),
                  DataColumn(label: Text('度数')),
                ],
                rows: sortedJockeys.take(10).map((entry) {
                  final data = entry.value;
                  final total = data['total'] as int;
                  final winRate = (data['win'] / total * 100);
                  final placeRate = (data['place'] / total * 100);
                  final showRate = (data['show'] / total * 100);
                  return DataRow(cells: [
                    DataCell(Text(entry.key)),
                    DataCell(Text('${winRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${placeRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${showRate.toStringAsFixed(1)}%')),
                    DataCell(Text('(${data['win']}-${data['place']-data['win']}-${data['show']-data['place']}-${total-data['show']})')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerStatsTable(Map<String, dynamic> stats) {
    final sortedTrainers = stats.entries.where((e) => e.value['total'] > 1).toList()
      ..sort((a, b) => (b.value['show'] / b.value['total']).compareTo(a.value['show'] / a.value['total']));

    if (sortedTrainers.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('調教師別成績 (2回以上出走)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0,
                columns: const [
                  DataColumn(label: Text('調教師')),
                  DataColumn(label: Text('勝率'), numeric: true),
                  DataColumn(label: Text('連対率'), numeric: true),
                  DataColumn(label: Text('複勝率'), numeric: true),
                  DataColumn(label: Text('度数')),
                ],
                rows: sortedTrainers.take(10).map((entry) {
                  final data = entry.value;
                  final total = data['total'] as int;
                  final winRate = (data['win'] / total * 100);
                  final placeRate = (data['place'] / total * 100);
                  final showRate = (data['show'] / total * 100);
                  return DataRow(cells: [
                    DataCell(Text(entry.key)),
                    DataCell(Text('${winRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${placeRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${showRate.toStringAsFixed(1)}%')),
                    DataCell(Text('(${data['win']}-${data['place']-data['win']}-${data['show']-data['place']}-${total-data['show']})')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutTable(Map<String, dynamic> stats) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');
    final rows = <DataRow>[];

    // bettingDictのキーの順序（ID順）でループ
    bettingDict.forEach((key, value) {
      if (stats.containsKey(value)) {
        final data = stats[value];
        rows.add(DataRow(
          cells: [
            DataCell(Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${currencyFormatter.format(data['average'])}円')),
            DataCell(Text('${currencyFormatter.format(data['max'])}円')),
            DataCell(Text('${currencyFormatter.format(data['min'])}円')),
          ],
        ));
      }
    });

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('配当傾向', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24.0,
                columns: const [
                  DataColumn(label: Text('馬券種')),
                  DataColumn(label: Text('平均'), numeric: true),
                  DataColumn(label: Text('最高'), numeric: true),
                  DataColumn(label: Text('最低'), numeric: true),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
