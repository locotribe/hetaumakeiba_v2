// lib/screens/shutuba_table_page.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/stats_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/horse_stats_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/horse_profile_sync_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/memo_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/performance_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/starters_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/training_tab.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/user_mark_dropdown.dart';
import 'package:hetaumakeiba_v2/widgets/themed_tab_bar.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_info_tab.dart'; // ▼ 追加

enum SortableColumn {
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

  final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();

  final Map<String, String> _mfNameCache = {};
  final Map<String, JockeyComboStats> _jockeyComboCache = {};

  SortableColumn _sortColumn = SortableColumn.horseNumber;
  bool _isAscending = true;
  late TabController _tabController;
  String? _highlightedRaceId;

  bool _isCourseOnlyMode = true;

  @override
  bool get wantKeepAlive => true;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
          _mfNameCache[horse.horseId] = profile.mfName;
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
            bestCourseTimeStats: horse.bestCourseTimeStats, // ▼ 追加
            fastestCourseAgariStats: horse.fastestCourseAgariStats, // ▼ 追加
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
            mfName: (profile.mfName.isNotEmpty) ? profile.mfName : horse.mfName,
            jockeyComboStats: horse.jockeyComboStats,
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
        trackType: data.trackType,
        distanceValue: data.distanceValue,
        direction: data.direction,
        courseInOut: data.courseInOut,
        weather: data.weather,
        trackCondition: data.trackCondition,
        holdingTimes: data.holdingTimes,
        holdingDays: data.holdingDays,
        raceCategory: data.raceCategory,
        horseCount: data.horseCount,
        startTime: data.startTime,
        basePrize1st: data.basePrize1st,
        basePrize2nd: data.basePrize2nd,
        basePrize3rd: data.basePrize3rd,
        basePrize4th: data.basePrize4th,
        basePrize5th: data.basePrize5th,
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
          final enrichedData = await _getShutubaDataWithProfile(widget.raceId);
          if (enrichedData != null) {
            data = enrichedData;
          }
        }
      }

      // --- ▼▼ レース結果がある場合、当日の馬体重をマージする処理 ▼▼ ---
      if (data != null && widget.raceResult != null) {
        for (var horse in data.horses) {
          try {
            final resultHorse = widget.raceResult!.horseResults.firstWhere(
                  (hr) => hr.horseId == horse.horseId,
            );
            if (resultHorse.horseWeight.isNotEmpty && resultHorse.horseWeight != '--') {
              // 増減込みの馬体重をそのまま上書きする（例: "480(+2)"）
              horse.horseWeight = resultHorse.horseWeight;
            }
          } catch (_) {}
        }
      }
      // --- ▲▲ レース結果がある場合、当日の馬体重をマージする処理 ▲▲ ---

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
      _jockeyComboCache[horse.horseId] = HorseStatsAnalyzer.analyzeJockeyCombo(
        currentJockeyId: horse.jockeyId,
        performanceRecords: pastRecords,
        raceResults: pastRaceResults,
      );
      horse.legStyleProfile = LegStyleAnalyzer.getRunningStyle(pastRecords);
      horse.jockeyComboStats = HorseStatsAnalyzer.analyzeJockeyCombo(
        currentJockeyId: horse.jockeyId,
        performanceRecords: pastRecords,
        raceResults: pastRaceResults,
      );
      horse.distanceCourseAptitudeStats = StatsAnalyzer.analyzeDistanceCourseAptitude(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.trackAptitudeLabel = StatsAnalyzer.analyzeTrackAptitude(
        pastRecords: pastRecords,
      );

      // 1. 持ち時計（全成績）
      horse.bestTimeStats = StatsAnalyzer.analyzeBestTime(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      if (horse.bestTimeStats?.sourceRaceId != null && horse.bestTimeStats!.sourceRaceId!.length >= 10) {
        final prefix10 = horse.bestTimeStats!.sourceRaceId!.substring(0, 10);
        final trackCondition = await _trackConditionRepo.getLatestTrackConditionByPrefix(prefix10);
        if (trackCondition != null) {
          final isDirt = horse.bestTimeStats!.venueAndDistance?.contains('ダ') ?? false;
          horse.bestTimeStats = horse.bestTimeStats!.copyWithTrackCondition(
            cushionValue: trackCondition.cushionValue,
            moistureGoal: isDirt ? trackCondition.moistureDirtGoal : trackCondition.moistureTurfGoal,
            moisture4c: isDirt ? trackCondition.moistureDirt4c : trackCondition.moistureTurf4c,
          );
        }
      }

      // 2. 持ち時計（同コース限定）
      horse.bestCourseTimeStats = StatsAnalyzer.analyzeBestCourseTime(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      if (horse.bestCourseTimeStats?.sourceRaceId != null && horse.bestCourseTimeStats!.sourceRaceId!.length >= 10) {
        final prefix10 = horse.bestCourseTimeStats!.sourceRaceId!.substring(0, 10);
        final trackCondition = await _trackConditionRepo.getLatestTrackConditionByPrefix(prefix10);
        if (trackCondition != null) {
          final isDirt = horse.bestCourseTimeStats!.venueAndDistance?.contains('ダ') ?? false;
          horse.bestCourseTimeStats = horse.bestCourseTimeStats!.copyWithTrackCondition(
            cushionValue: trackCondition.cushionValue,
            moistureGoal: isDirt ? trackCondition.moistureDirtGoal : trackCondition.moistureTurfGoal,
            moisture4c: isDirt ? trackCondition.moistureDirt4c : trackCondition.moistureTurf4c,
          );
        }
      }

      // 3. 上がり最速（全成績）
      horse.fastestAgariStats = StatsAnalyzer.analyzeFastestAgari(
        pastRecords: pastRecords,
      );
      if (horse.fastestAgariStats?.sourceRaceId != null && horse.fastestAgariStats!.sourceRaceId!.length >= 10) {
        final prefix10 = horse.fastestAgariStats!.sourceRaceId!.substring(0, 10);
        final trackCondition = await _trackConditionRepo.getLatestTrackConditionByPrefix(prefix10);
        if (trackCondition != null) {
          final isDirt = horse.fastestAgariStats!.venueAndDistance?.contains('ダ') ?? false;
          horse.fastestAgariStats = horse.fastestAgariStats!.copyWithTrackCondition(
            cushionValue: trackCondition.cushionValue,
            moistureGoal: isDirt ? trackCondition.moistureDirtGoal : trackCondition.moistureTurfGoal,
            moisture4c: isDirt ? trackCondition.moistureDirt4c : trackCondition.moistureTurf4c,
          );
        }
      }

      // 4. 上がり最速（同コース限定）
      horse.fastestCourseAgariStats = StatsAnalyzer.analyzeFastestCourseAgari(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      if (horse.fastestCourseAgariStats?.sourceRaceId != null && horse.fastestCourseAgariStats!.sourceRaceId!.length >= 10) {
        final prefix10 = horse.fastestCourseAgariStats!.sourceRaceId!.substring(0, 10);
        final trackCondition = await _trackConditionRepo.getLatestTrackConditionByPrefix(prefix10);
        if (trackCondition != null) {
          final isDirt = horse.fastestCourseAgariStats!.venueAndDistance?.contains('ダ') ?? false;
          horse.fastestCourseAgariStats = horse.fastestCourseAgariStats!.copyWithTrackCondition(
            cushionValue: trackCondition.cushionValue,
            moistureGoal: isDirt ? trackCondition.moistureDirtGoal : trackCondition.moistureTurfGoal,
            moisture4c: isDirt ? trackCondition.moistureDirt4c : trackCondition.moistureTurf4c,
          );
        }
      }
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
        Expanded(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF303030),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ThemedTabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'レース情報'),
                          Tab(text: '出走馬'),
                          Tab(text: '成績'),
                          Tab(text: 'メモ'),
                          Tab(text: '調教'),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('同コース', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        Switch(
                          value: _isCourseOnlyMode,
                          onChanged: (value) {
                            setState(() {
                              _isCourseOnlyMode = value;
                            });
                          },
                          activeColor: Colors.amber,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    if (widget.raceResult == null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: TextButton.icon(
                          onPressed: _updateDynamicData,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('更新', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                  ],
                ),
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
                          // ▼▼ 変更: モードによってソート基準を切り替え ▼▼
                            final aStats = _isCourseOnlyMode ? a.bestCourseTimeStats : a.bestTimeStats;
                            final bStats = _isCourseOnlyMode ? b.bestCourseTimeStats : b.bestTimeStats;
                            final aTime = aStats?.timeInSeconds;
                            final bTime = bStats?.timeInSeconds;
                            if (aTime == null && bTime == null) comparison = 0;
                            else if (aTime == null) comparison = 1;
                            else if (bTime == null) comparison = -1;
                            else comparison = aTime.compareTo(bTime);
                            break;
                          case SortableColumn.fastestAgari:
                          // ▼▼ 変更: モードによってソート基準を切り替え ▼▼
                            final aStats = _isCourseOnlyMode ? a.fastestCourseAgariStats : a.fastestAgariStats;
                            final bStats = _isCourseOnlyMode ? b.fastestCourseAgariStats : b.fastestAgariStats;
                            final aAgari = aStats?.agariInSeconds;
                            final bAgari = bStats?.agariInSeconds;
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
                          RaceInfoTabWidget(
                            predictionRaceData: _predictionRaceData!,
                            horses: sortedHorses,
                            buildMarkDropdown: (horse) => UserMarkDropdown(
                              // ★ 確実な再描画のためのKey
                              key: ValueKey('info_${horse.horseId}_${horse.userMark}'),
                              horse: horse,
                              raceId: widget.raceId,
                              // ★ 原因はコレ！背景が白なので、枠色に関係なく文字は常に「黒」にする
                              textColor: Colors.black87,
                              onMarkChanged: (mark) {
                                // ★ 即座に見た目を更新する
                                setState(() {
                                  horse.userMark = mark;
                                });
                                _handleMarkChanged(horse, mark);
                              },
                            ),
                            buildGateNumber: _buildGateNumber,
                            buildHorseNumber: _buildHorseNumber,
                          ),
                          StartersTabWidget(
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: (horse) => UserMarkDropdown(
                              horse: horse,
                              raceId: widget.raceId,
                              textColor: horse.gateNumber > 0 ? horse.gateNumber.gateTextColor : Colors.black87,
                              onMarkChanged: (mark) {
                                _handleMarkChanged(horse, mark);
                              },
                            ),
                            buildGateNumber: _buildGateNumber,
                            buildHorseNumber: _buildHorseNumber,
                            getHorseProfile: _horseRepo.getHorseProfile,
                            isCourseOnlyMode: _isCourseOnlyMode,
                            buildDataTableForTab: _buildDataTableForTab,
                          ),
                          PerformanceTabWidget(
                            predictionRaceData: _predictionRaceData!,
                            horses: sortedHorses,
                            onSort: _onSort,
                            buildMarkDropdown: (horse) => UserMarkDropdown(
                              horse: horse,
                              raceId: widget.raceId,
                              textColor: horse.gateNumber > 0 ? horse.gateNumber.gateTextColor : Colors.black87,
                              onMarkChanged: (mark) => _handleMarkChanged(horse, mark),
                            ),
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
                            buildMarkDropdown: (horse) => UserMarkDropdown(
                              horse: horse,
                              raceId: widget.raceId,
                              textColor: horse.gateNumber > 0 ? horse.gateNumber.gateTextColor : Colors.black87,
                              onMarkChanged: (mark) => _handleMarkChanged(horse, mark),
                            ),
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
            const styleOrder = {'逃げ': 0, '先行': 1, '差し': 2, '追込': 3, '自在': 4, 'マクリ': 5, '不明': 99};
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
          // ▼▼ 変更: モードによってソート基準を切り替え ▼▼
            final aStats = _isCourseOnlyMode ? a.bestCourseTimeStats : a.bestTimeStats;
            final bStats = _isCourseOnlyMode ? b.bestCourseTimeStats : b.bestTimeStats;
            final aTime = aStats?.timeInSeconds;
            final bTime = bStats?.timeInSeconds;
            comparison = compareNullsLast(aTime, bTime);
            break;
          case SortableColumn.fastestAgari:
          // ▼▼ 変更: モードによってソート基準を切り替え ▼▼
            final aStats = _isCourseOnlyMode ? a.fastestCourseAgariStats : a.fastestAgariStats;
            final bStats = _isCourseOnlyMode ? b.fastestCourseAgariStats : b.fastestAgariStats;
            final aAgari = aStats?.agariInSeconds;
            final bAgari = bStats?.agariInSeconds;
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

  // 印が変更された時の共通処理
  void _handleMarkChanged(PredictionHorseDetail horse, UserMark? newMark) {
    if (newMark == null) {
      if (horse.userMark != null) {
        setState(() => horse.userMark = null);
        _deleteMarkAndSaveInBackground(horse);
      }
    } else {
      setState(() => horse.userMark = newMark);
      _updateMarkAndSaveInBackground(newMark);
    }
  }

  /// 各タブのDataTableを生成するための共通ラッパー
  Widget _buildDataTableForTab({
    required List<DataColumn2> columns,
    required List<PredictionHorseDetail> horses,
    required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) {
    int? getSortColumnIndex() {
      for (int i = 0; i < columns.length; i++) {
        final col = columns[i];
        if (col.onSort != null) {
          // 列のラベルや、期待されるソート項目から現在のインデックスを特定
          if (_sortColumn == SortableColumn.horseNumber && i == 0) return 0;
          if (_sortColumn == SortableColumn.odds && i == 1) return 1;
          if (_sortColumn == SortableColumn.trainer && i == 3) return 3;
          if (_sortColumn == SortableColumn.horseName && i == 4) return 4;
          if (_sortColumn == SortableColumn.bestTime && i == 5) return 5;
          if (_sortColumn == SortableColumn.fastestAgari && i == 6) return 6;
        }
      }
      return null;
    }

    double determineMinWidth() {
      if (columns.length == 7) {
        return 550;
      }
      return 2000;
    }

    return DataTable2(
      key: ValueKey(_predictionRaceData.hashCode),
      minWidth: determineMinWidth(),
      fixedTopRows: 1,
      sortColumnIndex: getSortColumnIndex(),
      sortAscending: _isAscending,
      columnSpacing: 6.0,
      horizontalMargin: 2,
      headingRowHeight: 50,
      dataRowHeight: 100,
      headingTextStyle: const TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      dataTextStyle: const TextStyle(
        fontSize: 12.0,
        color: Colors.black87,
      ),
      columns: columns,
      rows: horses.map((horse) => DataRow(cells: cellBuilder(horse))).toList(),
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
    final frameColor = gateNumber.gateBackgroundColor;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: frameColor,
        border: gateNumber == 1 ? Border.all(color: Colors.grey) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        horseNumber.toString(),
        style: TextStyle(
          color: gateNumber.gateTextColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}