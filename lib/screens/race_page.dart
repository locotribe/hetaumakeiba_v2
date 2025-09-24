// lib/screens/race_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/screens/race_result_page.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_result_page.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/race_statistics_page.dart';
import 'package:hetaumakeiba_v2/screens/horse_stats_page.dart';
import 'package:hetaumakeiba_v2/screens/jockey_stats_page.dart';
import 'package:hetaumakeiba_v2/screens/ai_comprehensive_prediction_page.dart';

enum RaceStatus { loading, beforeHolding, resultConfirmed, resultUnconfirmed }

class RacePage extends StatefulWidget {
  final String raceId;
  final String raceDate;

  const RacePage({
    super.key,
    required this.raceId,
    required this.raceDate,
  });

  @override
  State<RacePage> createState() => _RacePageState();
}

class _RacePageState extends State<RacePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  RaceStatus _status = RaceStatus.loading;
  RaceResult? _raceResult;
  PredictionRaceData? _predictionRaceData;

  void _onShutubaDataRefreshed(PredictionRaceData newData) {
    setState(() {
      _predictionRaceData = newData;
    });
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _determineRaceStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _determineRaceStatus() async {
    final shutubaCache = await _dbHelper.getShutubaTableCache(widget.raceId);
    final dbResult = await _dbHelper.getRaceResult(widget.raceId);

    if (shutubaCache != null) {
      setState(() {
        _predictionRaceData = shutubaCache.predictionRaceData;
        _raceResult = dbResult;
        _status = RaceStatus.resultConfirmed;
        _tabController.animateTo(dbResult != null ? 2 : 0);
      });
      return;
    }

    if (dbResult != null) {
      setState(() {
        _raceResult = dbResult;
        _predictionRaceData = _createPredictionDataFromRaceResult(dbResult);
        _status = RaceStatus.resultConfirmed;
        _tabController.animateTo(2);
      });
      return;
    }

    final isConfirmed = await RaceResultScraperService.isRaceResultConfirmed(widget.raceId);

    if (isConfirmed) {
      setState(() {
        _status = RaceStatus.resultUnconfirmed;
        _tabController.animateTo(0);
      });
      _fetchAndSaveRaceResult();
    } else {
      setState(() {
        _status = RaceStatus.beforeHolding;
        _tabController.animateTo(0);
      });
    }
  }


  Future<void> _fetchAndSaveRaceResult() async {
    try {
      final result = await RaceResultScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/${widget.raceId}');
      await _dbHelper.insertOrUpdateRaceResult(result);
      for (final horse in result.horseResults) {
        final existingRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
        if (existingRecords.isEmpty) {
          try {
            final horseRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horse.horseId);
            for (final record in horseRecords) {
              await _dbHelper.insertOrUpdateHorsePerformance(record);
            }
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
          }
        }
      }

      if (mounted) {
        setState(() {
          _raceResult = result;
          _status = RaceStatus.resultConfirmed;
          _tabController.animateTo(1);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = RaceStatus.beforeHolding;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _predictionRaceData?.raceName ?? 'レース情報';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '出馬表'),
            Tab(text: '過去分析'),
            Tab(text: '出走馬分析'),
            Tab(text: '騎手特性'),
            Tab(text: 'AI分析'),
            Tab(text: 'レース結果'),
            Tab(text: 'AI分析結果'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case RaceStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RaceStatus.resultUnconfirmed:
        return Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                ShutubaTablePage(raceId: widget.raceId),
                const Center(child: CircularProgressIndicator()),
                const Center(child: Text('レース結果を取得中です...')),
                const Center(child: Text('レース結果を取得中です...')),
                const Center(child: Text('レース結果を取得中です...')),
                const Center(child: Text('レース結果を取得中です...')),
              ],
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        );
      case RaceStatus.beforeHolding:
      case RaceStatus.resultConfirmed:
        return TabBarView(
          controller: _tabController,
          children: [
            ShutubaTablePage(
              raceId: widget.raceId,
              predictionRaceData: _predictionRaceData,
              raceResult: _raceResult,
              onDataRefreshed: _onShutubaDataRefreshed,
            ),
            if (_predictionRaceData != null)
              RaceStatisticsPage(
                raceId: widget.raceId,
                raceName: _predictionRaceData!.raceName,
              )
            else
              const Center(child: Text('出馬表データを読み込んでいます...')),
            if (_predictionRaceData != null)
              HorseStatsPage(
                raceId: widget.raceId,
                raceName: _predictionRaceData!.raceName,
                horses: _predictionRaceData!.horses,
              )
            else
              const Center(child: Text('出馬表データを読み込んでいます...')),
            if (_predictionRaceData != null)
              JockeyStatsPage(
                raceData: _predictionRaceData!,
              )
            else
              const Center(child: Text('出馬表データを読み込んでいます...')),

            if (_predictionRaceData != null)
              ComprehensivePredictionPage(
                raceId: widget.raceId,
                raceData: _predictionRaceData!,
              )
            else
              const Center(child: Text('出馬表データを読み込んでいます...')),
            RaceResultPage(raceId: widget.raceId, qrData: null),
            AiPredictionResultPage(raceId: widget.raceId),
          ],
        );
    }
  }
}