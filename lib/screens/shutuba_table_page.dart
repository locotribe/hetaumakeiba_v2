// lib/screens/shutuba_table_page.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/stats_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/horse_profile_sync_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/info_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/jockey_trainer_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/memo_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/performance_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/starters_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/time_tab.dart';
import 'package:hetaumakeiba_v2/widgets/themed_tab_bar.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/training_tab.dart'; // ▼ 新規追加

enum SortableColumn {
  mark,
  gateNumber,
  horseNumber,
  horseName,
  popularity,
  odds,
  carriedWeight,
  horseWeight,
  bestTime,
  fastestAgari,
  legStyle,
  trainer,
  owner,
}

class ShutubaTablePage extends StatefulWidget {
  final String raceId;
  final RaceResult? raceResult;
  final PredictionRaceData? predictionRaceData;
  final Function(PredictionRaceData)? onDataRefreshed;

  const ShutubaTablePage({super.key, required this.raceId, this.raceResult,
    this.predictionRaceData, this.onDataRefreshed, });

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

class _ShutubaTablePageState extends State<ShutubaTablePage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  PredictionRaceData? _predictionRaceData;
  bool _isLoading = true;
  final ShutubaTableScraperService _scraperService = ShutubaTableScraperService();

  final RaceRepository _raceRepo = RaceRepository();
  final HorseRepository _horseRepo = HorseRepository();
  final UserRepository _userRepo = UserRepository();
  final HorseProfileSyncService _horseProfileSyncService = HorseProfileSyncService();

  SortableColumn _sortColumn = SortableColumn.horseNumber;
  bool _isAscending = true;
  late TabController _tabController;
  String? _highlightedRaceId;

  @override
  bool get wantKeepAlive => true;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadShutubaData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<PredictionRaceData?> _getShutubaDataWithProfile(String raceId) async {
    final cache = await _raceRepo.getShutubaTableCache(raceId);
    if (cache != null) {
      var data = cache.predictionRaceData;
      final List<PredictionHorseDetail> updatedHorses = [];

      for (var horse in data.horses) {
        final profile = await _horseRepo.getHorseProfile(horse.horseId);
        if (profile != null) {
          updatedHorses.add(PredictionHorseDetail(
            horseId: horse.horseId,
            horseNumber: horse.horseNumber,
            gateNumber: horse.gateNumber,
            horseName: horse.horseName,
            sexAndAge: horse.sexAndAge,
            jockey: horse.jockey,
            jockeyId: horse.jockeyId,
            carriedWeight: horse.carriedWeight,
            trainerName: horse.trainerName,
            trainerAffiliation: horse.trainerAffiliation,
            odds: horse.odds,
            effectiveOdds: horse.effectiveOdds,
            popularity: horse.popularity,
            horseWeight: horse.horseWeight,
            userMark: horse.userMark,
            userMemo: horse.userMemo,
            isScratched: horse.isScratched,
            predictionScore: horse.predictionScore,
            conditionFit: horse.conditionFit,
            distanceCourseAptitudeStats: horse.distanceCourseAptitudeStats,
            trackAptitudeLabel: horse.trackAptitudeLabel,
            bestTimeStats: horse.bestTimeStats,
            fastestAgariStats: horse.fastestAgariStats,
            overallScore: horse.overallScore,
            expectedValue: horse.expectedValue,
            legStyleProfile: horse.legStyleProfile,
            previousHorseWeight: horse.previousHorseWeight,
            previousJockey: horse.previousJockey,
            ownerName: (profile.ownerName.isNotEmpty) ? profile.ownerName : horse.ownerName,
            ownerId: (profile.ownerId.isNotEmpty) ? profile.ownerId : horse.ownerId,
            ownerImageLocalPath: (profile.ownerImageLocalPath.isNotEmpty) ? profile.ownerImageLocalPath : horse.ownerImageLocalPath,
            breederName: (profile.breederName.isNotEmpty) ? profile.breederName : horse.breederName,
            fatherName: (profile.fatherName.isNotEmpty) ? profile.fatherName : horse.fatherName,
            motherName: (profile.motherName.isNotEmpty) ? profile.motherName : horse.motherName,
          ));
        } else {
          updatedHorses.add(horse);
        }
      }

      return PredictionRaceData(
        raceId: data.raceId,
        raceName: data.raceName,
        raceDate: data.raceDate,
        venue: data.venue,
        raceNumber: data.raceNumber,
        shutubaTableUrl: data.shutubaTableUrl,
        raceGrade: data.raceGrade,
        raceDetails1: data.raceDetails1,
        horses: updatedHorses,
        racePacePrediction: data.racePacePrediction,
      );
    }
    return null;
  }

  Future<void> _loadShutubaData({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      PredictionRaceData? data;

      if (!refresh) {
        data = await _getShutubaDataWithProfile(widget.raceId);
      }

      if (data == null && widget.predictionRaceData != null && !refresh) {
        data = widget.predictionRaceData;
      }
      else if (data == null && widget.raceResult != null && !refresh) {
        data = _createPredictionDataFromRaceResult(widget.raceResult!);
      }

      if (data == null || refresh) {
        data = await _fetchDataWithUserMarks();
        if (data != null) {
          final cache = ShutubaTableCache(
            raceId: data.raceId,
            predictionRaceData: data,
            lastUpdatedAt: DateTime.now(),
          );
          await _raceRepo.insertOrUpdateShutubaTableCache(cache);
        }
      }

      if (mounted) {
        if (data != null) {
          if (widget.onDataRefreshed != null) {
            widget.onDataRefreshed!(data);
          }
        }

        setState(() {
          _predictionRaceData = data;
          _isLoading = false;
        });

        if (data != null) {
          _horseProfileSyncService.syncMissingHorseProfiles(data.horses, (updatedHorseId) async {
            if (!mounted) return;

            final updatedData = await _getShutubaDataWithProfile(widget.raceId);
            if (updatedData != null && mounted) {
              setState(() {
                _predictionRaceData = updatedData;
              });
            }
          });
        }
      }
    } catch (e) {
      print('出馬表データの読み込みに失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateMarkAndSaveInBackground(UserMark mark) async {
    await _userRepo.insertOrUpdateUserMark(mark);
    if (_predictionRaceData != null) {
      final newCache = ShutubaTableCache(
        raceId: widget.raceId,
        predictionRaceData: _predictionRaceData!,
        lastUpdatedAt: DateTime.now(),
      );
      await _raceRepo.insertOrUpdateShutubaTableCache(newCache);
    }
  }

  Future<void> _deleteMarkAndSaveInBackground(PredictionHorseDetail horse) async {
    final userId = localUserId;
    if (userId == null) return;

    await _userRepo.deleteUserMark(userId, widget.raceId, horse.horseId);
    if (_predictionRaceData != null) {
      final newCache = ShutubaTableCache(
        raceId: widget.raceId,
        predictionRaceData: _predictionRaceData!,
        lastUpdatedAt: DateTime.now(),
      );
      await _raceRepo.insertOrUpdateShutubaTableCache(newCache);
    }
  }

  PredictionRaceData _createPredictionDataFromRaceResult(RaceResult raceResult) {
    final horses = raceResult.horseResults.map((hr) {
      final weightMatch = RegExp(r'(\d+)\((.*?)\)').firstMatch(hr.horseWeight);
      final trainerName = hr.trainerName;
      final trainerAffiliation = hr.trainerAffiliation;

      return PredictionHorseDetail(
        horseId: hr.horseId,
        horseNumber: int.tryParse(hr.horseNumber) ?? 0,
        gateNumber: int.tryParse(hr.frameNumber) ?? 0,
        horseName: hr.horseName,
        sexAndAge: hr.sexAndAge,
        jockey: hr.jockeyName,
        jockeyId: hr.jockeyId,
        carriedWeight: double.tryParse(hr.weightCarried) ?? 0.0,
        trainerName: trainerName,
        trainerAffiliation: trainerAffiliation,
        odds: double.tryParse(hr.odds),
        popularity: int.tryParse(hr.popularity),
        horseWeight: weightMatch?.group(1),
        isScratched: int.tryParse(hr.rank) == null,
      );
    }).toList();

    final raceNumber = raceResult.raceId.length >= 2
        ? int.tryParse(raceResult.raceId.substring(raceResult.raceId.length - 2))?.toString() ?? ''
        : '';


    return PredictionRaceData(
      raceId: raceResult.raceId,
      raceName: raceResult.raceTitle,
      raceDate: raceResult.raceDate,
      venue: racecourseDict.entries.firstWhere((e) => raceResult.raceInfo.contains(e.value), orElse: () => const MapEntry("", "")).value,
      raceNumber: raceNumber,
      shutubaTableUrl: 'https://db.netkeiba.com/race/${raceResult.raceId}',
      raceGrade: raceResult.raceGrade,
      raceDetails1: raceResult.raceInfo,
      horses: horses,
    );
  }

  Future<void> _updateDynamicData() async {
    if (widget.raceResult != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('レース結果確定後はオッズを更新できません。')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最新情報を取得中...')));
    try {
      await _loadShutubaData(refresh: true);

      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('情報を更新しました。')));
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('情報の更新に失敗しました: $e')));
      }
    }
  }

  Future<PredictionRaceData?> _fetchDataWithUserMarks() async {
    final userId = localUserId;
    if (userId == null) {
      return await _scraperService.scrapeAllData(widget.raceId);
    }

    final raceData = await _scraperService.scrapeAllData(widget.raceId);

    final results = await Future.wait([
      _userRepo.getAllUserMarksForRace(userId, widget.raceId),
      _horseRepo.getMemosForRace(userId, widget.raceId),
    ]);

    final userMarks = results[0] as List<UserMark>;
    final userMemos = results[1] as List<HorseMemo>;

    final marksMap = {for (var mark in userMarks) mark.horseId: mark};
    final memosMap = {for (var memo in userMemos) memo.horseId: memo};

    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    final Set<String> pastRaceIdsToFetch = {};

    for (var horse in raceData.horses) {
      if (marksMap.containsKey(horse.horseId)) {
        horse.userMark = marksMap[horse.horseId];
      }
      if (memosMap.containsKey(horse.horseId)) {
        horse.userMemo = memosMap[horse.horseId];
        if (memosMap[horse.horseId]!.odds != null) {
          horse.odds = memosMap[horse.horseId]!.odds;
        }
        if (memosMap[horse.horseId]!.popularity != null) {
          horse.popularity = memosMap[horse.horseId]!.popularity;
        }
      }
      final pastRecords = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;

      if (pastRecords.isNotEmpty) {
        final previousRaceId = pastRecords.first.raceId;
        if (previousRaceId.isNotEmpty) {
          pastRaceIdsToFetch.add(previousRaceId);
        }
      }
    }

    final pastRaceResults = await _raceRepo.getMultipleRaceResults(pastRaceIdsToFetch.toList());

    for (var horse in raceData.horses) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];

      if (pastRecords.isNotEmpty) {
        final previousRecord = pastRecords.first;
        horse.previousJockey = previousRecord.jockey;
        horse.previousHorseWeight = previousRecord.horseWeight;

        final previousRaceResult = pastRaceResults[previousRecord.raceId];
        if (previousRaceResult != null) {
          try {
            final horseResult = previousRaceResult.horseResults.firstWhere((hr) => hr.horseId == horse.horseId);
            horse.ownerName = horseResult.ownerName;
          } catch (e) {
          }
        }
      }

      horse.legStyleProfile = LegStyleAnalyzer.getRunningStyle(pastRecords);
      horse.distanceCourseAptitudeStats = StatsAnalyzer.analyzeDistanceCourseAptitude(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.trackAptitudeLabel = StatsAnalyzer.analyzeTrackAptitude(
        pastRecords: pastRecords,
      );
      horse.bestTimeStats = StatsAnalyzer.analyzeBestTime(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.fastestAgariStats = StatsAnalyzer.analyzeFastestAgari(
        pastRecords: pastRecords,
      );
    }

    raceData.racePacePrediction = RaceAnalyzer.predictRacePace(
        raceData.horses, allPastRecords, []);
    return raceData;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _predictionRaceData == null
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('レース情報の読み込みに失敗しました。'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadShutubaData(),
            child: const Text('再試行'),
          )
        ],
      ),
    )
        : Column(
      children: [
        if (widget.raceResult == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _updateDynamicData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('オッズ・馬体重を更新'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              ThemedTabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: '出走馬'),
                  Tab(text: '情報'),
                  Tab(text: '騎手・調教師'),
                  Tab(text: '時計'),
                  Tab(text: '成績'),
                  Tab(text: 'メモ'),
                  Tab(text: '調教'), // ▼ 新規追加
                ],
              ),
              Expanded(
                child: Builder(
                    builder: (context) {
                      final sortedHorses = List<PredictionHorseDetail>.from(_predictionRaceData!.horses);
                      sortedHorses.sort((a, b) {
                        int comparison;
                        int compareNullsLast(Comparable? valA, Comparable? valB) {
                          if (valA == null && valB == null) return 0;
                          if (valA == null) return 1;
                          if (valB == null) return -1;
                          return valA.compareTo(valB);
                        }

                        switch (_sortColumn) {
                          case SortableColumn.mark:
                            const markOrder = {'◎': 0, '〇': 1, '▲': 2, '△': 3, '✕': 4, '★': 5, '消': 6};
                            final aMark = markOrder[a.userMark?.mark] ?? 99;
                            final bMark = markOrder[b.userMark?.mark] ?? 99;
                            comparison = aMark.compareTo(bMark);
                            break;
                          case SortableColumn.gateNumber:
                            comparison = a.gateNumber.compareTo(b.gateNumber);
                            break;
                          case SortableColumn.horseNumber:
                            comparison = a.horseNumber.compareTo(b.horseNumber);
                            break;
                          case SortableColumn.horseName:
                            comparison = a.horseName.compareTo(b.horseName);
                            break;
                          case SortableColumn.popularity:
                            comparison = compareNullsLast(a.popularity, b.popularity);
                            break;
                          case SortableColumn.odds:
                            comparison = compareNullsLast(a.odds, b.odds);
                            break;
                          case SortableColumn.carriedWeight:
                            comparison = a.carriedWeight.compareTo(b.carriedWeight);
                            break;
                          case SortableColumn.horseWeight:
                            final aWeight = int.tryParse(a.horseWeight?.split('(').first ?? '');
                            final bWeight = int.tryParse(b.horseWeight?.split('(').first ?? '');
                            comparison = compareNullsLast(aWeight, bWeight);
                            break;
                          case SortableColumn.bestTime:
                            final aTime = a.bestTimeStats?.timeInSeconds;
                            final bTime = b.bestTimeStats?.timeInSeconds;
                            if (aTime == null && bTime == null) comparison = 0;
                            else if (aTime == null) comparison = 1;
                            else if (bTime == null) comparison = -1;
                            else comparison = aTime.compareTo(bTime);
                            break;
                          case SortableColumn.fastestAgari:
                            final aAgari = a.fastestAgariStats?.agariInSeconds;
                            final bAgari = b.fastestAgariStats?.agariInSeconds;
                            comparison = compareNullsLast(aAgari, bAgari);
                            break;
                          case SortableColumn.trainer:
                            comparison = a.trainerName.compareTo(b.trainerName);
                            break;
                          case SortableColumn.owner:
                            comparison = compareNullsLast(a.ownerName, b.ownerName);
                            break;

                          default:
                            comparison = a.horseNumber.compareTo(b.horseNumber);
                            break;
                        }
                        return _isAscending ? comparison : -comparison;
                      });

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          StartersTabWidget(
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: _buildMarkDropdown,
                            buildGateNumber: _buildGateNumber,
                            buildHorseNumber: _buildHorseNumber,
                            getHorseProfile: _horseRepo.getHorseProfile,
                            buildDataTableForTab: _buildDataTableForTab,
                          ),
                          InfoTabWidget(
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: _buildMarkDropdown,
                            buildDataTableForTab: _buildDataTableForTab,
                          ),
                          JockeyTrainerTabWidget(
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: _buildMarkDropdown,
                            buildDataTableForTab: _buildDataTableForTab,
                          ),
                          TimeTabWidget(
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: _buildMarkDropdown,
                            buildDataTableForTab: _buildDataTableForTab,
                          ),
                          PerformanceTabWidget(
                            predictionRaceData: _predictionRaceData!,
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: _buildMarkDropdown,
                            buildDataTableForTab: _buildDataTableForTab,
                            highlightedRaceId: _highlightedRaceId,
                            onRaceHighlightChanged: (String raceId) {
                              setState(() {
                                if (_highlightedRaceId == raceId) {
                                  _highlightedRaceId = null;
                                } else {
                                  _highlightedRaceId = raceId;
                                }
                              });
                            },
                          ),
                          MemoTabWidget(
                            raceId: widget.raceId,
                            predictionRaceData: _predictionRaceData!,
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: _buildMarkDropdown,
                            buildDataTableForTab: _buildDataTableForTab,
                            reloadData: () {
                              _loadShutubaData(refresh: true);
                            },
                          ),
                          TrainingTabWidget(
                            raceId: widget.raceId,
                            raceDate: _predictionRaceData!.raceDate,
                            horses: sortedHorses,
                          ),
                        ],
                      );
                    }
                ),
              ),
            ],
          ),
        ),
        _buildScrapingProgressIndicator(),
      ],
    );
  }

  Widget _buildScrapingProgressIndicator() {
    return StreamBuilder<ScrapingStatus>(
      stream: ScrapingManager().statusStream,
      initialData: ScrapingStatus.idle(),
      builder: (context, snapshot) {
        final status = snapshot.data!;

        if (!status.isRunning) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blueGrey.shade800,
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${status.currentTaskName} (残り: ${status.queueLength}件)',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSort(SortableColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
      _predictionRaceData?.horses.sort((a, b) {
        int comparison;
        int compareNullsLast(Comparable? valA, Comparable? valB) {
          if (valA == null && valB == null) return 0;
          if (valA == null) return 1;
          if (valB == null) return -1;
          return valA.compareTo(valB);
        }

        switch (_sortColumn) {
          case SortableColumn.mark:
            const markOrder = {'◎': 0, '〇': 1, '▲': 2, '△': 3, '✕': 4, '★': 5, '消': 6};
            final aMark = markOrder[a.userMark?.mark] ?? 99;
            final bMark = markOrder[b.userMark?.mark] ?? 99;
            comparison = aMark.compareTo(bMark);
            break;
          case SortableColumn.gateNumber:
            comparison = a.gateNumber.compareTo(b.gateNumber);
            break;
          case SortableColumn.horseNumber:
            comparison = a.horseNumber.compareTo(b.horseNumber);
            break;
          case SortableColumn.horseName:
            comparison = a.horseName.compareTo(b.horseName);
            break;
          case SortableColumn.legStyle:
            const styleOrder = {'逃げ': 0, '先行': 1, '差し': 2, '追い込み': 3, '自在': 4, 'マクリ': 5, '不明': 99};
            final aStyle = styleOrder[a.legStyleProfile?.primaryStyle] ?? 99;
            final bStyle = styleOrder[b.legStyleProfile?.primaryStyle] ?? 99;
            comparison = aStyle.compareTo(bStyle);
            break;
          case SortableColumn.popularity:
            comparison = compareNullsLast(a.popularity, b.popularity);
            break;
          case SortableColumn.odds:
            comparison = compareNullsLast(a.odds, b.odds);
            break;
          case SortableColumn.carriedWeight:
            comparison = a.carriedWeight.compareTo(b.carriedWeight);
            break;
          case SortableColumn.horseWeight:
            final aWeight = int.tryParse(a.horseWeight?.split('(').first ?? '');
            final bWeight = int.tryParse(b.horseWeight?.split('(').first ?? '');
            comparison = compareNullsLast(aWeight, bWeight);
            break;
          case SortableColumn.bestTime:
            final aTime = a.bestTimeStats?.timeInSeconds;
            final bTime = b.bestTimeStats?.timeInSeconds;
            comparison = compareNullsLast(aTime, bTime);
            break;
          case SortableColumn.fastestAgari:
            final aAgari = a.fastestAgariStats?.agariInSeconds;
            final bAgari = b.fastestAgariStats?.agariInSeconds;
            comparison = compareNullsLast(aAgari, bAgari);
            break;
          default:
            comparison = a.horseNumber.compareTo(b.horseNumber);
            break;
        }
        return _isAscending ? comparison : -comparison;
      });
    });
  }

  /// 各タブのDataTableを生成するための共通ラッパー
  Widget _buildDataTableForTab({
    required List<DataColumn2> columns,
    required List<PredictionHorseDetail> horses,
    required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) {
    return DataTable2(
      key: ValueKey(_predictionRaceData.hashCode),
      minWidth: 2000,
      fixedTopRows: 1,
      sortColumnIndex: columns.indexWhere((c) => (c.onSort != null)),
      sortAscending: _isAscending,
      columnSpacing: 6.0,
      headingRowHeight: 50,
      dataRowHeight: 90,
      headingTextStyle: const TextStyle(
        fontSize: 12.0, // ヘッダーの文字サイズ
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      dataTextStyle: const TextStyle(
        fontSize: 14.0, // セルの文字サイズ
        color: Colors.black87,
      ),
      columns: columns,
      rows: horses.map((horse) => DataRow(cells: cellBuilder(horse))).toList(),
    );
  }

  Widget _buildMarkDropdown(PredictionHorseDetail horse) {
    return PopupMenuButton<String>(
      constraints: const BoxConstraints(
        minWidth: 2.0 * 24.0, // 最小幅を指定
        maxWidth: 2.0 * 24.0,  // 最大幅を指定
      ),

      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        ...['◎', '〇', '▲', '△', '✕', '★'].map((String value) {
          return PopupMenuItem<String>(
            value: value,
            height: 36, // 高さを詰める
            child: Center(child: Text(value)), // 中央揃えにする
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '消',
          height: 36, // 高さを詰める
          child: Center(child: Text('消')), // 中央揃えにする
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '--',
          height: 36, // 高さを詰める
          child: Center(child: Text('--')), // 中央揃えにする
        ),
      ],
      onSelected: (String newValue) {
        final userId = localUserId;
        if (userId == null) return;

        if (newValue == '--') {
          if (horse.userMark != null) {
            setState(() {
              horse.userMark = null;
            });
            _deleteMarkAndSaveInBackground(horse);
          }
        } else {
          final userMark = UserMark(
            userId: userId,
            raceId: widget.raceId,
            horseId: horse.horseId,
            mark: newValue,
            timestamp: DateTime.now(),
          );
          setState(() {
            horse.userMark = userMark;
          });
          _updateMarkAndSaveInBackground(userMark);
        }
      },
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          horse.userMark?.mark ?? '--',
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 枠番表示を作成
  Widget _buildGateNumber(int gateNumber) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gateNumber.gateBackgroundColor,
        border: gateNumber == 1 ? Border.all(color: Colors.grey) : null,
      ),
      child: Text(
        gateNumber.toString(),
        style: TextStyle(
          color: gateNumber.gateTextColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 馬番表示を作成
  Widget _buildHorseNumber(int horseNumber, int gateNumber) {
    // 追加: 拡張メソッドを使って色を一度だけ取得する
    final frameColor = gateNumber.gateBackgroundColor;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(
          color: frameColor, // 修正: _getGateColor(gateNumber) を変数に置き換え
          width: 2.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        horseNumber.toString(),
        style: TextStyle(
          // 修正: _getGateColor(gateNumber) を変数に置き換え
          color: frameColor == Colors.black ? Colors.black : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHelpIcon(String title, String content) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 4.0),
        child: Icon(Icons.help_outline, color: Colors.grey, size: 16),
      ),
    );
  }
}