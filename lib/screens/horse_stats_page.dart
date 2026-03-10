// lib/screens/horse_stats_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/logic/horse_stats_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_stats_cache_model.dart';
import 'package:hetaumakeiba_v2/models/matchup_stats_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';

import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/individual_stats_tab.dart';
import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/matchup_stats_tab.dart';
import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/jockey_combo_stats_tab.dart';
import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/condition_based_analysis_tab.dart';
import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/relative_battle_tab.dart';

import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/training_time_chart_tab.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class HorseStatsPage extends StatefulWidget {
  final String raceId;
  final String raceName;
  final List<PredictionHorseDetail> horses;
  final PredictionRaceData? raceData;

  const HorseStatsPage({
    super.key,
    required this.raceId,
    required this.raceName,
    required this.horses,
    this.raceData,
  });

  @override
  State<HorseStatsPage> createState() => _HorseStatsPageState();
}

class _HorseStatsPageState extends State<HorseStatsPage> with SingleTickerProviderStateMixin {
  final HorseRepository _horseRepository = HorseRepository();
  final RaceRepository _raceRepository = RaceRepository();
  bool _isLoading = true;
  String _loadingMessage = '';
  double _loadingProgress = 0.0;
  Map<String, HorseStats> _statsMap = {};
  String? _errorMessage;
  late TabController _tabController;
  List<MatchupStats> _matchupStats = [];
  Map<String, JockeyComboStats> _jockeyComboStats = {};

  final TrainingRepository _trainingRepository = TrainingRepository(); // 追加
  Map<String, List<TrainingTimeModel>> _trainingDataMap = {}; // 追加
  Map<String, List<HorseRaceRecord>> _pastRecordsMap = {}; // 既存のローカル変数をクラス変数に昇格させるか、再計算時に保持する

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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

    final cache = await _horseRepository.getHorseStatsCache(widget.raceId);
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
      final records = await _horseRepository.getHorsePerformanceRecords(horse.horseId);
      allPerformanceRecords[horse.horseId] = records;
    }

    final allPastRaceIds = allPerformanceRecords.values
        .expand((records) => records)
        .map((record) => record.raceId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final allRaceResults = await _raceRepository.getMultipleRaceResults(allPastRaceIds.toList());

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

    final Map<String, List<TrainingTimeModel>> newTrainingDataMap = {};
    for (final horse in widget.horses) {
      final trainingTimes = await _trainingRepository.getTrainingTimesForHorse(horse.horseId);
      newTrainingDataMap[horse.horseId] = trainingTimes;
    }

    setState(() {
      _trainingDataMap = newTrainingDataMap;
      _pastRecordsMap = allPerformanceRecords; // 過去成績もグラフに渡すために保持
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
      final allPastRaceIds = <String>{};
      final Map<String, List<HorseRaceRecord>> allPerformanceRecords = {};

      int horseIndex = 0;
      for (final horse in widget.horses) {
        horseIndex++;
        if (mounted) {
          setState(() {
            _loadingMessage = 'データ取得中: ${horse.horseName} ($horseIndex/${widget.horses.length})';
            _loadingProgress = (horseIndex / widget.horses.length) * 0.5;
          });
        }

        try {
          final scrapedRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horse.horseId);
          for (final record in scrapedRecords) {
            await _horseRepository.insertOrUpdateHorsePerformance(record);
          }
        } catch (e) {
          print('Error scraping horse ${horse.horseName} (${horse.horseId}): $e');
        }

        final records = await _horseRepository.getHorsePerformanceRecords(horse.horseId);
        allPerformanceRecords[horse.horseId] = records;

        for (final record in records) {
          if (record.raceId.isNotEmpty) {
            allPastRaceIds.add(record.raceId);
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      final existingResults = await _raceRepository.getMultipleRaceResults(allPastRaceIds.toList());
      final raceIdsToFetch = allPastRaceIds.where((id) => !existingResults.containsKey(id)).toList();

      final Map<String, RaceResult> fetchedResults = {};
      if (raceIdsToFetch.isNotEmpty) {
        for (int i = 0; i < raceIdsToFetch.length; i++) {
          final raceId = raceIdsToFetch[i];
          if (!mounted) return;
          setState(() {
            _loadingMessage = 'レース詳細データを取得中 (${i + 1}/${raceIdsToFetch.length})';
            _loadingProgress = 0.5 + ((i + 1) / raceIdsToFetch.length * 0.5);
          });
          try {
            final result = await RaceResultScraperService.scrapeRaceDetails(generateRaceResultUrl(raceId));
            await _raceRepository.insertOrUpdateRaceResult(result);
            fetchedResults[raceId] = result;
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            print('Failed to fetch race result for $raceId: $e');
          }
        }
      }

      final allRaceResults = {...existingResults, ...fetchedResults};

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

      final Map<String, List<TrainingTimeModel>> newTrainingDataMap = {};
      for (final horse in widget.horses) {
        final trainingTimes = await _trainingRepository.getTrainingTimesForHorse(horse.horseId);
        newTrainingDataMap[horse.horseId] = trainingTimes;
      }

      final cacheToSave = HorseStatsCache(
        raceId: widget.raceId,
        statsMap: newStatsMap,
        lastUpdatedAt: DateTime.now(),
      );
      await _horseRepository.insertOrUpdateHorseStatsCache(cacheToSave);

      if (!mounted) return;
      setState(() {
        _statsMap = newStatsMap;
        _matchupStats = newMatchupStats;
        _jockeyComboStats = newJockeyComboStats;
        _trainingDataMap = newTrainingDataMap;
        _pastRecordsMap = allPerformanceRecords;
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
    return Column(
      children: [
        // ★Rowを使ってTabBarと更新ボタンを横1行に並べる
        Row(
          children: [
            Expanded( // タブエリアに横幅を最大限使わせる
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: '調教タイム'),
                  Tab(text: '個別成績'),
                  Tab(text: '対戦成績'),
                  Tab(text: 'コンビ成績'),
                  Tab(text: '好走条件'),
                  Tab(text: '相対評価'),
                ],
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.black,
                indicatorColor: Colors.blue,
              ),
            ),
            // ★タブの右端に更新ボタンを配置
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _showConfirmationDialog(isRefresh: true),
                tooltip: 'データを更新',
                color: Colors.blue, // タブの選択色に合わせると統一感が出ます
              ),
          ],
        ),
        if (_isLoading)
          LinearProgressIndicator(
            value: _loadingProgress,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: _buildBody(),
        ),
      ],
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

    // ▼ 切り出したウィジェットを呼び出すように変更
    return TabBarView(
      controller: _tabController,
      children: [
        TrainingTimeChartTab( // ★一番前に追加
          horses: widget.horses,
          trainingDataMap: _trainingDataMap,
          pastRecordsMap: _pastRecordsMap,
        ),
        IndividualStatsTab(
          horses: widget.horses,
          statsMap: _statsMap,
        ),
        MatchupStatsTab(
          horses: widget.horses,
          matchupStats: _matchupStats,
        ),
        JockeyComboStatsTab(
          horses: widget.horses,
          jockeyComboStats: _jockeyComboStats,
        ),
        ConditionBasedAnalysisTab(
          raceData: widget.raceData ?? PredictionRaceData(
            raceId: widget.raceId,
            raceName: widget.raceName,
            raceDate: '',
            venue: '',
            raceNumber: '',
            shutubaTableUrl: '',
            raceGrade: '',
            horses: widget.horses,
          ),
        ),
        RelativeBattleTab(
          horses: widget.horses,
          raceData: widget.raceData,
        ),
      ],
    );
  }
}