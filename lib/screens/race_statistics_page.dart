// lib/screens/race_statistics_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/services/past_race_id_fetcher_service.dart';
import 'package:hetaumakeiba_v2/widgets/stats_match_tab.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

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
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<RaceStatistics?>? _statisticsFuture;
  List<PredictionHorseDetail> _horses = []; // 出走馬リストを保持

  // 配当タブで使用する辞書定義
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

  // 出馬表データの読み込み（過去傾向タブ用）
  Future<void> _loadShutubaData() async {
    try {
      final cache = await _dbHelper.getShutubaTableCache(widget.raceId);
      if (cache != null && mounted) {
        setState(() {
          _horses = cache.predictionRaceData.horses;
        });
      }
    } catch (e) {
      debugPrint('Error loading shutuba data: $e');
    }
  }

  void _checkAndLoadStatistics() {
    setState(() {
      _statisticsFuture = _dbHelper.getRaceStatistics(widget.raceId);
    });
  }

  /// データ取得のメインロジック（ユーザー提示のコードを維持）
  void _startFetchingProcess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text("過去レースを検索中..."),
            ],
          ),
        );
      },
    );

    final PastRaceIdResult result = await _pastRaceIdFetcher.fetchPastRaceIds(widget.raceName); // IDではなくNameで検索が一般的ですが元のコードに従います

    if (mounted) Navigator.of(context).pop(); // ローディングダイアログを閉じる

    switch (result.status) {
      case FetchStatus.success:
        final bool? confirmed = await _showRaceIdConfirmationDialog(result.pastRaces);
        if (confirmed == true && mounted) {
          setState(() {
            _statisticsFuture = _statisticsService.processAndSaveRaceStatisticsByIds(
              raceId: widget.raceId,
              raceName: widget.raceName,
              pastRaceIds: result.pastRaces.keys.toList(),
            );
          });
        }
        break;
      case FetchStatus.pageNotSupported:
      case FetchStatus.empty:
        if (mounted) _showFallbackConfirmation(isNotSupported: true);
        break;
      case FetchStatus.temporaryError:
        if (mounted) _showManualRetryOrFallbackDialog(result.message);
        break;
    }
  }

  Future<bool?> _showRaceIdConfirmationDialog(Map<String, String> pastRaces) {
    final raceNames = pastRaces.values.toList();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('過去レースデータ取得の確認', style: TextStyle(fontSize: 20.0)),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.35,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${pastRaces.length}件の過去レースが見つかりました。\nこれらのレースデータを取得しますか？'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: raceNames.length,
                  itemBuilder: (context, index) => Text('⫸✅ ${raceNames[index]}'),
                ),
              ),
            ],
          ),
        ),
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
  }

  void _showFallbackConfirmation({bool isNotSupported = false, String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNotSupported ? 'レースIDでの検索非対応' : 'レースIDでの検索失敗'),
        content: Text(
            isNotSupported
                ? 'このレースは重賞ではないため、レースIDによる過去データ検索に対応していません。\n\n代わりにレース名「${widget.raceName}」で検索しますか？\n（精度が低下する場合があります）'
                : 'エラーが発生しました。\n$error\n\n代わりにレース名「${widget.raceName}」で検索しますか？\n（精度が低下する場合があります）'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _statisticsFuture = _statisticsService.processAndSaveRaceStatistics(widget.raceId, widget.raceName);
              });
            },
            child: const Text('レース名で検索'),
          ),
        ],
      ),
    );
  }

  void _showManualRetryOrFallbackDialog(String? errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ取得エラー'),
        content: Text('通信エラーによりデータの取得に失敗しました。\n詳細: $errorMessage'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showFallbackConfirmation(error: errorMessage);
            },
            child: const Text('レース名で検索'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startFetchingProcess();
            },
            child: const Text('もう一度試す'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // タブ構成: 配当, 人気, 枠番, 脚質, 馬体重, 騎手, 調教師, 詳細分析, 過去傾向 (計9つ)
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              child: const TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: '配当'),
                  Tab(text: '人気'),
                  Tab(text: '枠番'),
                  Tab(text: '脚質'),
                  Tab(text: '馬体重'),
                  Tab(text: '騎手'),
                  Tab(text: '調教師'),
                  Tab(text: '詳細分析'),
                  Tab(text: '過去傾向'),
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
                    // データがない場合の初期画面（全タブ共通または専用表示）
                    // ここではタブViewの中に初期画面を表示する形にします
                    return TabBarView(
                      children: List.generate(9, (index) => _buildInitialView()),
                    );
                  }

                  final data = json.decode(stats.statisticsJson);

                  return TabBarView(
                    children: [
                      // 1. 配当
                      _buildTabContent(child: _buildPayoutTable(data['payoutStats'] ?? const {})),
                      // 2. 人気
                      _buildTabContent(child: _buildPopularityTable(data['popularityStats'] ?? const {})),
                      // 3. 枠番
                      _buildTabContent(child: _buildFrameStatsCard(data['frameStats'] ?? const {})),
                      // 4. 脚質 (復活)
                      _buildTabContent(child: _buildLegStyleStatsCard(data['legStyleStats'] ?? const {})),
                      // 5. 馬体重 (復活)
                      _buildTabContent(child: _buildHorseWeightStatsCard(
                          data['horseWeightChangeStats'] ?? const {},
                          (data['avgWinningHorseWeight'] ?? 0.0).toDouble()
                      )),
                      // 6. 騎手
                      _buildTabContent(child: _buildJockeyStatsTable(data['jockeyStats'] ?? const {})),
                      // 7. 調教師
                      _buildTabContent(child: _buildTrainerStatsTable(data['trainerStats'] ?? const {})),
                      // 8. 詳細分析 (実装中)
                      const Center(child: Text('詳細分析機能は実装中です')),
                      // 9. 過去傾向マッチ (StatsMatchTab)
                      _horses.isEmpty
                          ? const Center(child: Text('出馬表データが見つかりません。\n先にレース詳細画面を開いてください。'))
                          : StatsMatchTab(
                        raceId: widget.raceId,
                        raceName: widget.raceName,
                        horses: _horses,
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
              style: TextStyle(fontSize: 18),
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

  // --- 以下、元のカード構築メソッド群 (復元) ---

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
      // orderにないキーは後ろへ
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