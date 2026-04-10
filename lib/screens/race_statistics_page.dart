// lib/screens/race_statistics_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/services/past_race_id_fetcher_service.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/widgets/analyzed_races_tab.dart';
import 'package:hetaumakeiba_v2/widgets/detailed_analysis_tab.dart';
import 'package:hetaumakeiba_v2/widgets/past_race_selection_dialog.dart';
import 'package:hetaumakeiba_v2/widgets/stats_match_tab.dart';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_analysis_tab.dart';

// ★追加：各カードウィジェットとアナライザーのインポート
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/payout_comparison_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/popularity_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/frame_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/leg_style_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/horse_weight_card.dart';

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
  final PastRaceIdFetcherService _pastRaceIdFetcher = PastRaceIdFetcherService();
  final RaceRepository _raceRepo = RaceRepository();

  Future<RaceStatistics?>? _statisticsFuture;
  List<PredictionHorseDetail> _horses = [];

  List<PredictionHorseDetail>? _resultHorses;
  bool _hasCacheData = false;
  bool get _showResultTab => _hasCacheData && _resultHorses != null;

  // ★追加：グラフ描画のために過去レース(RaceResult)のリストを保持する変数
  List<RaceResult> _pastRaces = [];

  final Map<String, String> bettingDict = {
    '1': '単勝',
    '2': '複勝',
    '3': '枠連',
    '4': '馬連',
    '5': 'ワイド',
    '6': '馬単',
    '7': '3連複',
    '8': '3連単',
  };

  @override
  void initState() {
    super.initState();
    _checkAndLoadStatistics();
    _loadShutubaData();
  }

  // 出馬表データの読み込み
  Future<void> _loadShutubaData() async {
    try {
      final cache = await _raceRepo.getShutubaTableCache(widget.raceId);
      if (cache != null) {
        _horses = cache.predictionRaceData.horses;
        _hasCacheData = true;
      } else {
        _hasCacheData = false;
      }

      final RaceResult? result = await _raceRepo.getRaceResult(widget.raceId);
      if (result != null) {
        _resultHorses = _convertResultsToDetails(result.horseResults, useRankAsPopularity: true);

        if (!_hasCacheData) {
          _horses = _convertResultsToDetails(result.horseResults, useRankAsPopularity: false);
        }
      } else {
        _resultHorses = null;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading shutuba data: $e');
    }
  }

  List<PredictionHorseDetail> _convertResultsToDetails(List<HorseResult> results, {bool useRankAsPopularity = false}) {
    return results.map((res) {
      final int hNum = int.tryParse(res.horseNumber) ?? 0;
      final int fNum = int.tryParse(res.frameNumber) ?? 0;
      final double weight = double.tryParse(res.weightCarried) ?? 57.0;
      final double? oddsVal = double.tryParse(res.odds);

      int? popVal;
      if (useRankAsPopularity) {
        popVal = int.tryParse(res.rank);
      } else {
        popVal = int.tryParse(res.popularity);
      }

      final bool isScratched = int.tryParse(res.rank) == null;

      return PredictionHorseDetail(
        horseId: res.horseId,
        horseNumber: hNum,
        gateNumber: fNum,
        horseName: res.horseName,
        sexAndAge: res.sexAndAge,
        jockey: res.jockeyName,
        jockeyId: res.jockeyId,
        carriedWeight: weight,
        trainerName: res.trainerName,
        trainerAffiliation: res.trainerAffiliation,
        horseWeight: res.horseWeight,
        odds: oddsVal,
        popularity: popVal,
        isScratched: isScratched,
        userMark: null,
        userMemo: res.userMemo,
        ownerName: res.ownerName,
      );
    }).toList();
  }

  // 統計データの読み込みと、グラフ描画に必要な過去レース詳細の取得
  void _checkAndLoadStatistics() {
    setState(() {
      _statisticsFuture = _raceRepo.getRaceStatistics(widget.raceId).then((stats) async {
        if (stats != null) {
          // statsに記録されている分析対象のRaceIDリストを使ってRaceResultを取得
          final pastIds = stats.analyzedRacesList.map((e) => e['raceId'] as String).toList();
          if (pastIds.isNotEmpty) {
            final resultsMap = await _raceRepo.getMultipleRaceResults(pastIds);
            _pastRaces = resultsMap.values.toList();
          }
        }
        return stats;
      });
    });
  }

  void _startFetchingProcess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final PastRaceIdResult result = await _pastRaceIdFetcher.fetchPastRaceIds(widget.raceId, widget.raceName);

    if (mounted) Navigator.of(context).pop();

    if (result.status == FetchStatus.temporaryError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: ${result.message}')),
        );
      }
      return;
    }

    if (mounted) {
      final List<PastRaceItem>? selectedItems = await showDialog<List<PastRaceItem>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PastRaceSelectionDialog(
          initialResult: result,
          defaultSearchText: widget.raceName,
        ),
      );

      if (selectedItems != null && selectedItems.isNotEmpty) {
        final List<String> idsToFetch = selectedItems.map((e) => e.raceId).toList();

        setState(() {
          _statisticsFuture = _statisticsService.processAndSaveRaceStatisticsByIds(
            raceId: widget.raceId,
            raceName: widget.raceName,
            pastRaceIds: idsToFetch,
          ).then((stats) async {
            if (stats != null) {
              final resultsMap = await _raceRepo.getMultipleRaceResults(idsToFetch);
              _pastRaces = resultsMap.values.toList();
            }
            return stats;
          });
        });
      }
    }
  }

  void _refetchDetailedData() {
    _startFetchingProcess();
  }

  Widget _buildRefetchView(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            '$titleを表示するための\n詳細データが保存されていません。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refetchDetailedData,
            icon: const Icon(Icons.refresh),
            label: const Text('詳細データを再取得して更新'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '※再取得時に不要なレースのチェックを外すことで除外できます',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(_showResultTab),
      length: _showResultTab ? 12 : 11,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(text: '総合'),
                  const Tab(text: '配当'),
                  const Tab(text: '人気'),
                  const Tab(text: '枠番'),
                  const Tab(text: '脚質'),
                  const Tab(text: '馬体重'),
                  const Tab(text: '騎手'),
                  const Tab(text: '調教師'),
                  const Tab(text: '人気分析'),
                  const Tab(text: '傾向分析'),
                  if (_showResultTab) const Tab(text: '結果分析'),
                  const Tab(text: '分析対象'),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<RaceStatistics?>(
                future: _statisticsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
                  }

                  final stats = snapshot.data;
                  if (stats == null) {
                    return TabBarView(
                      children: List.generate(_showResultTab ? 12 : 11, (index) => _buildInitialView()),
                    );
                  }

                  final data = json.decode(stats.statisticsJson);

                  return TabBarView(
                    children: [
                      // 総合
                      VolatilityAnalysisTab(
                        targetRaceIds: stats.analyzedRacesList.map((e) => e['raceId'] as String).toList(),
                      ),
                      // 1. 配当
                      _buildTabContent(child: Column(children: [
                        if (_pastRaces.isNotEmpty) PayoutComparisonCard(result: PayoutAnalyzer().analyze(_pastRaces)),
                        const SizedBox(height: 16),
                        _buildPayoutTable(data['payoutStats'] ?? const {}),
                      ])),
                      // 2. 人気
                      _buildTabContent(child: Column(children: [
                        if (_pastRaces.isNotEmpty) PopularityChartCard(result: PopularityAnalyzer().analyze(_pastRaces)),
                        const SizedBox(height: 16),
                        _buildPopularityTable(data['popularityStats'] ?? const {}),
                      ])),
                      // 3. 枠番
                      _buildTabContent(child: Column(children: [
                        if (_pastRaces.isNotEmpty) FrameChartCard(result: FrameAnalyzer().analyze(_pastRaces)),
                        const SizedBox(height: 16),
                        _buildFrameStatsCard(data['frameStats'] ?? const {}),
                      ])),
                      // 4. 脚質
                      _buildTabContent(child: Column(children: [
                        if (_pastRaces.isNotEmpty) LegStyleChartCard(result: LegStyleAnalyzer().analyze(_pastRaces)),
                        const SizedBox(height: 16),
                        _buildLegStyleStatsCard(data['legStyleStats'] ?? const {}),
                      ])),
                      // 5. 馬体重
                      _buildTabContent(child: Column(children: [
                        if (_pastRaces.isNotEmpty) HorseWeightCard(result: HorseWeightAnalyzer().analyze(_pastRaces)),
                        const SizedBox(height: 16),
                        _buildHorseWeightStatsCard(
                            data['horseWeightChangeStats'] ?? const {},
                            (data['avgWinningHorseWeight'] ?? 0.0).toDouble()
                        ),
                      ])),
                      // 6. 騎手
                      _buildTabContent(child: _buildJockeyStatsTable(data['jockeyStats'] ?? const {})),
                      // 7. 調教師
                      _buildTabContent(child: _buildTrainerStatsTable(data['trainerStats'] ?? const {})),
                      // 8. 詳細分析
                      stats.analyzedRacesList.isEmpty
                          ? const Center(child: Text('分析データがありません。'))
                          : DetailedAnalysisTab(
                        raceId: widget.raceId,
                        raceName: widget.raceName,
                        horses: _horses,
                        targetRaceIds: stats.analyzedRacesList.map((e) => e['raceId'] as String).toList(),
                      ),
                      // 9. 傾向マッチ (予想データ)
                      _horses.isEmpty
                          ? const Center(child: Text('出馬表データが見つかりません。\n先にレース詳細画面を開いてください。'))
                          : StatsMatchTab(
                        raceId: widget.raceId,
                        raceName: widget.raceName,
                        horses: _horses,
                        targetRaceIds: stats.analyzedRacesList.map((e) => e['raceId'] as String).toList(),
                      ),
                      // 10. 結果分析
                      if (_showResultTab)
                        StatsMatchTab(
                          raceId: widget.raceId,
                          raceName: widget.raceName,
                          horses: _resultHorses!,
                          targetRaceIds: stats.analyzedRacesList.map((e) => e['raceId'] as String).toList(),
                          comparisonTargets: _horses,
                        ),
                      // 11. 分析対象
                      stats.analyzedRacesList.isEmpty
                          ? _buildRefetchView('分析対象レース一覧')
                          : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _refetchDetailedData,
                                icon: const Icon(Icons.edit),
                                label: const Text('分析対象レースを再選択・更新'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade100,
                                  foregroundColor: Colors.brown,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: AnalyzedRacesTab(
                              analyzedRaces: stats.analyzedRacesList,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('データ取得を開始'),
              onPressed: _startFetchingProcess,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: child,
    );
  }

  Widget _buildPayoutTable(Map<String, dynamic> stats) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');
    final rows = <DataRow>[];

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

    if (rows.isEmpty) return const Text('データがありません');

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

    if (rows.isEmpty) return const Text('データがありません');

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
    if (sortedKeys.isEmpty) return const Text('データがありません');

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
    final sortedKeys = stats.keys.toList()..sort((a, b) {
      final indexA = order.indexOf(a);
      final indexB = order.indexOf(b);
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });

    if (sortedKeys.isEmpty) return const Text('データがありません');

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
            if (stats.isEmpty) const Text('データがありません'),
          ],
        ),
      ),
    );
  }

  Widget _buildJockeyStatsTable(Map<String, dynamic> stats) {
    final sortedJockeys = stats.entries.where((e) => e.value['total'] > 1).toList()
      ..sort((a, b) => (b.value['show'] / b.value['total']).compareTo(a.value['show'] / a.value['total']));

    if (sortedJockeys.isEmpty) return const Text('データがありません (2回以上騎乗のみ表示)');

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
                rows: sortedJockeys.take(20).map((entry) {
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

    if (sortedTrainers.isEmpty) return const Text('データがありません (2回以上出走のみ表示)');

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
                rows: sortedTrainers.take(20).map((entry) {
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
}