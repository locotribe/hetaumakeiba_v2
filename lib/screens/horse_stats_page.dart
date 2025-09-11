// lib/screens/horse_stats_page.dart

import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/horse_stats_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_cache_model.dart';
import 'package:hetaumakeiba_v2/models/matchup_stats_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';

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

class _HorseStatsPageState extends State<HorseStatsPage> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  String _loadingMessage = '';
  double _loadingProgress = 0.0;
  Map<String, HorseStats> _statsMap = {};
  String? _errorMessage;
  late TabController _tabController;
  List<MatchupStats> _matchupStats = [];
  Map<String, JockeyComboStats> _jockeyComboStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = '分析データを確認中...';
    });

    final cache = await _dbHelper.getHorseStatsCache(widget.raceId);
    if (cache != null) {
      await _recalculateExtraStats(cache.statsMap);
      setState(() {
        _statsMap = cache.statsMap;
        _isLoading = false;
      });
    } else {
      _showConfirmationDialog();
    }
  }

  Future<void> _recalculateExtraStats(Map<String, HorseStats> stats) async {
    final Map<String, List<HorseRaceRecord>> allPerformanceRecords = {};
    for (final horse in widget.horses) {
      final records = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPerformanceRecords[horse.horseId] = records;
    }

    final allPastRaceIds = allPerformanceRecords.values
        .expand((records) => records)
        .map((record) => record.raceId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final allRaceResults = await _dbHelper.getMultipleRaceResults(allPastRaceIds.toList());

    final matchups = HorseStatsAnalyzer.analyzeMatchups(
      horses: widget.horses,
      allPerformanceRecords: allPerformanceRecords,
    );

    final jockeyCombos = <String, JockeyComboStats>{};
    for (final horse in widget.horses) {
      jockeyCombos[horse.horseId] = HorseStatsAnalyzer.analyzeJockeyCombo(
        currentJockeyId: horse.jockeyId,
        performanceRecords: allPerformanceRecords[horse.horseId] ?? [],
        raceResults: allRaceResults,
      );
    }

    setState(() {
      _matchupStats = matchups;
      _jockeyComboStats = jockeyCombos;
    });
  }


  Future<void> _showConfirmationDialog({bool isRefresh = false}) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isRefresh ? 'データ更新の確認' : '過去データ取得の確認'),
        content: Text(isRefresh
            ? '最新のデータを再取得し、分析結果を更新します。よろしいですか？'
            : '全出走馬の全過去レース結果を取得します。データ量に応じて時間がかかる場合があります。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isRefresh ? '更新' : '取得開始'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _fetchAndCalculateStats();
    } else if (!isRefresh) {
      Navigator.of(context).pop();
    }
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

      // 2. DBにないレース結果のみをダウンロード対象とする
      final existingResults = await _dbHelper.getMultipleRaceResults(allPastRaceIds.toList());
      final raceIdsToFetch = allPastRaceIds.where((id) => !existingResults.containsKey(id)).toList();

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
            final result = await RaceResultScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/$raceId');
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
      final newJockeyComboStats = <String, JockeyComboStats>{};
      for (final horse in widget.horses) {
        final records = allPerformanceRecords[horse.horseId] ?? [];
        newStatsMap[horse.horseId] = HorseStatsAnalyzer.calculate(
          performanceRecords: records,
          raceResults: allRaceResults,
        );
        newJockeyComboStats[horse.horseId] = HorseStatsAnalyzer.analyzeJockeyCombo(
          currentJockeyId: horse.jockeyId,
          performanceRecords: records,
          raceResults: allRaceResults,
        );
      }

      final newMatchupStats = HorseStatsAnalyzer.analyzeMatchups(
        horses: widget.horses,
        allPerformanceRecords: allPerformanceRecords,
      );

      // 6. 計算結果をキャッシュに保存
      final cacheToSave = HorseStatsCache(
        raceId: widget.raceId,
        statsMap: newStatsMap,
        lastUpdatedAt: DateTime.now(),
      );
      await _dbHelper.insertOrUpdateHorseStatsCache(cacheToSave);

      if (!mounted) return;
      setState(() {
        _statsMap = newStatsMap;
        _matchupStats = newMatchupStats;
        _jockeyComboStats = newJockeyComboStats;
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
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _showConfirmationDialog(isRefresh: true),
              tooltip: 'データを更新',
            ),
        ],
        bottom: _isLoading
            ? PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: _loadingProgress,
            backgroundColor: Colors.transparent,
          ),
        )
            : TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '個別成績'),
            Tab(text: '対戦成績'),
            Tab(text: 'コンビ成績'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 12,
                ),
              ),
            ],
          ),
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

    return TabBarView(
      controller: _tabController,
      children: [
        _buildIndividualStatsTab(),
        _buildMatchupStatsTab(),
        _buildJockeyComboStatsTab(),
      ],
    );
  }

  Widget _buildIndividualStatsTab() {
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

  Widget _buildMatchupStatsTab() {
    if (_matchupStats.isEmpty) {
      return const Center(child: Text('直接対決の成績はありません。'));
    }

    const double cellWidth = 50.0;
    const double cellHeight = 50.0;
    const double headerHeight = 50.0;
    const double totalCellWidth = 70.0; // 集計列の幅

    // 各馬の対戦成績を集計
    final Map<String, Map<String, int>> horseTotals = {};
    for (final horseA in widget.horses) {
      int totalOpponentWins = 0;
      int totalWinLegs = 0;
      int totalLossLegs = 0;

      for (final horseB in widget.horses) {
        if (horseA.horseId == horseB.horseId) continue;

        MatchupStats? stats;
        try {
          stats = _matchupStats.firstWhere((m) =>
          (m.horseIdA == horseA.horseId && m.horseIdB == horseB.horseId) ||
              (m.horseIdA == horseB.horseId && m.horseIdB == horseA.horseId));
        } catch (e) {
          stats = null;
        }

        if (stats != null) {
          final wins = (stats.horseIdA == horseA.horseId) ? stats.horseAWins : stats.horseBWins;
          final losses = stats.matchupCount - wins;
          totalWinLegs += wins;
          totalLossLegs += losses;
          if (wins > losses) {
            totalOpponentWins++;
          }
        }
      }
      horseTotals[horseA.horseId] = {
        'Win': totalOpponentWins,
        'WinLeg': totalWinLegs,
        'LosLeg': totalLossLegs,
      };
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 固定された行ヘッダー
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: headerHeight), // 左上の空セル
                ...widget.horses.map((horse) {
                  return Container(
                    height: cellHeight,
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    child: Text(
                      horse.horseName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ],
            ),
          ),
          // 水平スクロール可能なデータ部分
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // スクロールする列ヘッダー
                  Row(
                    children: [
                      ...widget.horses.map((horse) {
                        final horseName = horse.horseName;
                        final displayName = horseName.length > 3 ? horseName.substring(0, 3) : horseName;
                        return Container(
                          width: cellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                            ),
                          ),
                          child: Text(
                            '${horse.horseNumber}\n$displayName',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }),
                      // 追加ヘッダー
                      Container(
                          width: totalCellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          child: const Text('WIN',
                              style: TextStyle(fontSize: 20),
                              textAlign: TextAlign.center
                          )
                      ),
                      Container(
                          width: totalCellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          child: const Text('W-Leg',
                              style: TextStyle(fontSize: 20),
                              textAlign: TextAlign.center
                          )
                      ),
                      Container(
                          width: totalCellWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          child: const Text('L-Leg',
                              style: TextStyle(fontSize: 20),
                              textAlign: TextAlign.center
                          )
                      ),
                    ],
                  ),
                  // データ行
                  ...widget.horses.map((horseA) {
                    final totals = horseTotals[horseA.horseId] ?? {'Win': 0, 'WinLeg': 0, 'LosLeg': 0};
                    return Row(
                      children: [
                        ...widget.horses.map((horseB) {
                          String cellText = '';
                          Color? cellColor;
                          if (horseA.horseId == horseB.horseId) {
                            cellText = '';
                            cellColor = Colors.grey.shade500;
                          } else {
                            MatchupStats? stats;
                            try {
                              stats = _matchupStats.firstWhere((m) =>
                              (m.horseIdA == horseA.horseId && m.horseIdB == horseB.horseId) ||
                                  (m.horseIdA == horseB.horseId && m.horseIdB == horseA.horseId));
                            } catch (e) {
                              stats = null;
                            }

                            if (stats != null) {
                              int wins = (stats.horseIdA == horseA.horseId) ? stats.horseAWins : stats.horseBWins;
                              int losses = stats.matchupCount - wins;
                              cellText = '$wins-$losses';
                            }
                          }
                          return Container(
                            width: cellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cellColor,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                            ),
                            child: Builder( // Builderウィジェットを追加
                              builder: (context) {
                                Widget symbolWidget = const SizedBox.shrink();
                                if (cellText.isNotEmpty && cellText != '-') {
                                  final parts = cellText.split('-');
                                  if (parts.length == 2) {
                                    final wins = int.tryParse(parts[0]);
                                    final losses = int.tryParse(parts[1]);
                                    if (wins != null && losses != null) {
                                      if (wins > losses) {
                                        symbolWidget = const Text(
                                          '〇',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      } else if (wins < losses) {
                                        symbolWidget = const Text(
                                          '✕',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    symbolWidget,
                                    Text(
                                      cellText,
                                      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        }),
                        // 追加セル
                        Container(
                            width: totalCellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            child: Text(totals['Win'].toString(),
                                style: const TextStyle(fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue
                                )
                            )
                        ),
                        Container(
                            width: totalCellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            child: Text(totals['WinLeg'].toString(),
                                style: const TextStyle(fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue
                                )
                            )
                        ),
                        Container(
                            width: totalCellWidth,
                            height: cellHeight,
                            alignment: Alignment.center,
                            child: Text(totals['LosLeg'].toString(),
                                style: const TextStyle(fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red
                                )
                            )
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJockeyComboStatsTab() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16.0,
          columns: const [
            DataColumn(label: Text('馬名')),
            DataColumn(label: Text('騎手')),
            DataColumn(label: Text('成績')),
            DataColumn(label: Text('勝率'), numeric: true),
            DataColumn(label: Text('連対率'), numeric: true),
            DataColumn(label: Text('複勝率'), numeric: true),
            DataColumn(label: Text('単回率'), numeric: true),
            DataColumn(label: Text('複回率'), numeric: true),
          ],
          rows: widget.horses.map((horse) {
            final stats = _jockeyComboStats[horse.horseId] ?? JockeyComboStats();
            return DataRow(
              cells: [
                DataCell(Text(horse.horseName)),
                DataCell(Text(horse.jockey)),
                DataCell(
                  stats.isFirstRide
                      ? const Text('初', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))
                      : Text(stats.recordString),
                ),
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
