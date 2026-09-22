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
// [追加] 調教タブ改修Step1: レース日より前への絞り込み (v.2026.9.22+26092210)
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
// [追加] 調教タブ改修Step6: netkeiba の調教（評価・併せ馬）を調教タイムタブへ渡す (v.2026.9.23+26092303)
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';

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

  final TrainingRepository _trainingRepository = TrainingRepository();
  Map<String, List<TrainingTimeModel>> _trainingDataMap = {};
  Map<String, List<HorseRaceRecord>> _pastRecordsMap = {};
  // [追加] 調教タブ改修Step6: netkeiba の調教（レース日より前） (v.2026.9.23+26092303)
  final NetkeibaTrainingRepository _netkeibaTrainingRepository = NetkeibaTrainingRepository();
  Map<String, List<NetkeibaTrainingSession>> _netkeibaTrainingMap = {};
  // [追加] 調教タブ改修Step7: 今回のレースの netkeiba 評価（相対評価の調教点に使う） (v.2026.9.23+26092305)
  Map<String, NetkeibaTrainingReview> _netkeibaReviews = {};

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
      // [追加] Phase 4-C: 全出走馬の過去成績が既にDBに揃っている場合は
      // 確認ダイアログを出さず直接計算する（Phase 2の冪等化により再スクレイプは走らない） (v.2026.9.5+26090503)
      bool allPerformanceRecordsExist = widget.horses.isNotEmpty;
      for (final horse in widget.horses) {
        final records = await _horseRepository.getHorsePerformanceRecords(horse.horseId);
        if (records.isEmpty) {
          allPerformanceRecordsExist = false;
          break;
        }
      }
      if (allPerformanceRecordsExist) {
        _fetchAndCalculateStats();
      } else {
        _showConfirmationDialog();
      }
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

    // [追加] 調教タブ改修Step6: netkeiba の調教も読む (v.2026.9.23+26092303)
    final newNetkeibaTrainingMap = await _loadNetkeibaTrainingBeforeRace();
    // [追加] 調教タブ改修Step7: 今回のレースの netkeiba 評価も読む (v.2026.9.23+26092305)
    final newNetkeibaReviews =
        await _netkeibaTrainingRepository.getReviewsForRace(widget.raceId);
    if (!mounted) return;
    setState(() {
      // [修正] 調教タブ改修Step1: レース当日以降の調教・成績を除外する (v.2026.9.22+26092210)
      _trainingDataMap = _trainingBeforeRace(newTrainingDataMap);
      _pastRecordsMap = _recordsBeforeRace(allPerformanceRecords);
      _netkeibaTrainingMap = newNetkeibaTrainingMap;
      // [追加] 調教タブ改修Step7 (v.2026.9.23+26092305)
      _netkeibaReviews = newNetkeibaReviews;
    });
  }

  // [追加] 調教タブ改修Step1: 調教データと過去成績をレース日より前だけに絞る。
  // レース日が不明（raceData が null・変換不可）の場合は絞らない (v.2026.9.22+26092210)
  String get _raceDateRaw => widget.raceData?.raceDate ?? '';

  Map<String, List<TrainingTimeModel>> _trainingBeforeRace(
      Map<String, List<TrainingTimeModel>> map) {
    if (toYyyymmdd(_raceDateRaw) == null) return map;
    return filterTrainingMapBeforeRace(map, _raceDateRaw);
  }

  Map<String, List<HorseRaceRecord>> _recordsBeforeRace(
      Map<String, List<HorseRaceRecord>> map) {
    final ymd = toYyyymmdd(_raceDateRaw);
    if (ymd == null) return map;
    final asOf = DateTime(
      int.parse(ymd.substring(0, 4)),
      int.parse(ymd.substring(4, 6)),
      int.parse(ymd.substring(6, 8)),
    );
    return map.map((horseId, records) =>
        MapEntry(horseId, filterRecordsBeforeAsOf(records, asOf: asOf)));
  }

  // [追加] 調教タブ改修Step6: netkeiba の調教を馬ごとに読み、レース日より前だけに絞る (v.2026.9.23+26092303)
  Future<Map<String, List<NetkeibaTrainingSession>>> _loadNetkeibaTrainingBeforeRace() async {
    final raceYmd = toYyyymmdd(_raceDateRaw);
    final result = <String, List<NetkeibaTrainingSession>>{};
    for (final horse in widget.horses) {
      var sessions = await _netkeibaTrainingRepository.getSessionsForHorse(horse.horseId);
      if (raceYmd != null) {
        sessions = sessions.where((s) => s.trainingDate.compareTo(raceYmd) < 0).toList();
      }
      result[horse.horseId] = sessions;
    }
    return result;
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
      // [修正] Phase 2: isRefreshをforceRefreshとして伝搬し、更新ボタン経由では
      // 従来どおり全馬を再スクレイプさせる (v.2026.9.4+26090405)
      _fetchAndCalculateStats(forceRefresh: isRefresh);
    } else if (!isRefresh) {
      Navigator.of(context).pop();
    }
  }

  // [修正] Phase 2: forceRefreshを追加。既にDBに成績がある馬はforceRefresh時以外
  // スクレイプをスキップする冪等化 (v.2026.9.4+26090405)
  Future<void> _fetchAndCalculateStats({bool forceRefresh = false}) async {
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

        // [修正] Phase 2: 既にDBに成績がある馬はforceRefresh時以外スクレイプをスキップする
        // 冪等化。500ms待機もスキップ側では行わない (v.2026.9.4+26090405)
        final existing = await _horseRepository.getHorsePerformanceRecords(horse.horseId);

        if (!forceRefresh && existing.isNotEmpty) {
          if (mounted) {
            setState(() {
              _loadingMessage =
                  'キャッシュ利用: ${horse.horseName} ($horseIndex/${widget.horses.length})';
            });
          }

          allPerformanceRecords[horse.horseId] = existing;

          for (final record in existing) {
            if (record.raceId.isNotEmpty) {
              allPastRaceIds.add(record.raceId);
            }
          }
        } else {
          try {
            final scrapedRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horse.horseId);
            for (final record in scrapedRecords) {
              await _horseRepository.insertOrUpdateHorsePerformance(record);
            }
          } catch (e) {
            debugPrint('Error scraping horse ${horse.horseName} (${horse.horseId}): $e');
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
            debugPrint('Failed to fetch race result for $raceId: $e');
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

      // [追加] 調教タブ改修Step6: netkeiba の調教も読み直す (v.2026.9.23+26092303)
      final newNetkeibaTrainingMap = await _loadNetkeibaTrainingBeforeRace();
      // [追加] 調教タブ改修Step7: 今回のレースの netkeiba 評価も読み直す (v.2026.9.23+26092305)
      final newNetkeibaReviews =
          await _netkeibaTrainingRepository.getReviewsForRace(widget.raceId);

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
        // [修正] 調教タブ改修Step1: レース当日以降の調教・成績を除外する (v.2026.9.22+26092210)
        _trainingDataMap = _trainingBeforeRace(newTrainingDataMap);
        _pastRecordsMap = _recordsBeforeRace(allPerformanceRecords);
        // [追加] 調教タブ改修Step6: netkeiba の調教 (v.2026.9.23+26092303)
        _netkeibaTrainingMap = newNetkeibaTrainingMap;
        // [追加] 調教タブ改修Step7 (v.2026.9.23+26092305)
        _netkeibaReviews = newNetkeibaReviews;
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
        Row(
          children: [
            Expanded(
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
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _showConfirmationDialog(isRefresh: true),
                tooltip: 'データを更新',
                color: Colors.blue,
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

    return TabBarView(
      controller: _tabController,
      children: [
        TrainingTimeChartTab(
          horses: widget.horses,
          trainingDataMap: _trainingDataMap,
          pastRecordsMap: _pastRecordsMap,
          // [追加] 調教タブ改修Step6: netkeiba の調教と今回のレース (v.2026.9.23+26092303)
          netkeibaTrainingMap: _netkeibaTrainingMap,
          raceName: widget.raceName,
          raceDate: _raceDateRaw,
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
          trainingDataMap: _trainingDataMap, // ★ここが抜けていたのを修正しました！
          // [追加] 調教タブ改修Step7: netkeiba の調教・評価も渡す (v.2026.9.23+26092305)
          netkeibaTrainingMap: _netkeibaTrainingMap,
          netkeibaReviews: _netkeibaReviews,
        ),
      ],
    );
  }
}