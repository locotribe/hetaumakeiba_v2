// lib/screens/race_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/screens/race_result_page.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_result_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
import '../models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
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
    _tabController = TabController(length: 4, vsync: this);
    _determineRaceStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

// lib/screens/race_page.dart

  Future<void> _determineRaceStatus() async {
    // 1. DBから分析済みの出馬表キャッシュがあるか確認
    final shutubaCache = await _dbHelper.getShutubaTableCache(widget.raceId);
    // 2. DBからレース結果があるか確認
    final dbResult = await _dbHelper.getRaceResult(widget.raceId);

    if (shutubaCache != null) {
      // 3. キャッシュが存在する場合 (最優先)
      setState(() {
        _predictionRaceData = shutubaCache.predictionRaceData;
        _raceResult = dbResult; // レース結果があればセット
        _status = RaceStatus.resultConfirmed; // キャッシュがあれば常にこの状態でOK
        _tabController.animateTo(dbResult != null ? 2 : 0); // 結果があれば結果タブ、なければ出馬表タブ
      });
      return;
    }

    // 4. キャッシュがない場合
    if (dbResult != null) {
      // レース結果だけはある場合
      setState(() {
        _raceResult = dbResult;
        _predictionRaceData = _createPredictionDataFromRaceResult(dbResult); // ここで変換
        _status = RaceStatus.resultConfirmed;
        _tabController.animateTo(2);
      });
      return;
    }

    // 5. キャッシュもレース結果もない場合 (Web確認)
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
      // 1. Webからレース結果を取得
      final result = await RaceResultScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/${widget.raceId}');
      // 2. 取得したレース結果をDBに保存
      await _dbHelper.insertOrUpdateRaceResult(result);
      // 3. レース結果に含まれる各馬について、全競走成績がDBに存在するかチェック
      for (final horse in result.horseResults) {
        // DBにその馬のデータが1件もなければ、Webから全成績を取得する
        final existingRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
        if (existingRecords.isEmpty) {
          try {
            print('競走馬データ取得開始: ${horse.horseName} (ID: ${horse.horseId})');
            // 4. Webから馬の全成績を取得
            final horseRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horse.horseId);
            // 5. 取得した全成績をDBに保存
            for (final record in horseRecords) {
              await _dbHelper.insertOrUpdateHorsePerformance(record);
            }
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            print('ERROR: 競走馬ID ${horse.horseId} の成績スクレイピングまたは保存中にエラーが発生しました: $e');
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
      print('Failed to fetch race result in RacePage: $e');
      if (mounted) {
        setState(() {
          _status = RaceStatus.beforeHolding;
        });
      }
    }
  }

// lib/screens/race_page.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レース情報'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '出馬表'),
            Tab(text: 'AI予測'),
            Tab(text: 'レース結果'),
            Tab(text: 'AI予測結果'),
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
            ),
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