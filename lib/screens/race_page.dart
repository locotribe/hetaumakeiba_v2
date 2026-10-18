// lib/screens/race_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/shutuba_table_cache_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/race_result_page.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/race_statistics_page.dart';
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';
// [削除] 好走条件・個別成績・相対評価の移動 Step5: 出走馬分析タブを削除したので import を外した（好走条件・個別成績は馬詳細、相対評価は展開シミュの「評価」へ移した） (v.2026.10.17+26101710)
// [削除] 結果分析タブの廃止 Step2: 騎手特性タブを削除したので import を外した（騎手の成績の集計 JockeyAnalysisService は相対評価・展開シミュが使うので残す） (v.2026.10.19+26101902)
import 'package:hetaumakeiba_v2/widgets/race_page_tabs/race_detail_tab.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_result_prediction_converter.dart';
import 'package:hetaumakeiba_v2/screens/odds_page.dart';
// [削除] 能力分析を馬詳細へ Step5: 能力分析タブを削除したので import を外した（中身は馬詳細の「能力・条件」・「全」ページの能力、レース情報タブのレースレベル診断へ移した） (v.2026.10.17+26101705)

enum RaceStatus { loading, beforeHolding, resultConfirmed, resultUnconfirmed }

class RacePage extends StatefulWidget {
  final String raceId;
  final String raceDate;
  final QrData? qrData;

  const RacePage({
    super.key,
    required this.raceId,
    required this.raceDate,
    this.qrData,
  });

  @override
  State<RacePage> createState() => _RacePageState();
}

class _RacePageState extends State<RacePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RaceRepository _raceRepo = RaceRepository();
  final ShutubaTableCacheRepository _shutubaTableCacheRepository = ShutubaTableCacheRepository();
  final HorseRepository _horseRepo = HorseRepository();
  // ▼ [追加] 過去レースの出馬表を裏でスクレイプし直すためのサービス (v.2026.7.28+26072802)
  final ShutubaTableScraperService _scraperService = ShutubaTableScraperService();
  // ▲ [追加]
  RaceStatus _status = RaceStatus.loading;
  RaceResult? _raceResult;
  PredictionRaceData? _predictionRaceData;
  // ▼ [追加] 裏スクレイプ成功時にtab0(出馬表=ShutubaTablePage)を再マウントさせるための世代カウンタ (v.2026.7.28+26072802)
  int _shutubaRefreshGen = 0;
  // ▲ [追加]

  void _onShutubaDataRefreshed(PredictionRaceData newData) {
    setState(() {
      _predictionRaceData = newData;
    });
  }

  // ▼ [追加] 分岐1(キャッシュあり)の補完処理をヘルパー化し、分岐2(裏スクレイプ後)からも再利用する (v.2026.7.28+26072802)
  // オーナー画像パスの実在チェック・付け替え、およびレース結果からの馬体重マージを行う。
  Future<PredictionRaceData> _applyOwnerImageAndWeightMerge(
      PredictionRaceData data, RaceResult? dbResult) async {
    final dir = await getApplicationDocumentsDirectory();
    final currentOwnerImagesDir = '${dir.path}/owner_images';

    for (var shutubaHorse in data.horses) {
      final profile = await _horseRepo.getHorseProfile(shutubaHorse.horseId);
      if (profile != null && profile.ownerImageLocalPath.isNotEmpty) {
        final savedPath = profile.ownerImageLocalPath;
        final fileName = savedPath.split('/').last;
        final currentFilePath = '$currentOwnerImagesDir/$fileName';

        if (await File(currentFilePath).exists()) {
          shutubaHorse.ownerImageLocalPath = currentFilePath;
        } else if (await File(savedPath).exists()) {
          shutubaHorse.ownerImageLocalPath = savedPath;
        }
      }
    }
    if (dbResult != null) {
      for (var shutubaHorse in data.horses) {
        try {
          final resultHorse = dbResult.horseResults.firstWhere(
                (hr) => hr.horseId == shutubaHorse.horseId,
          );
          if (resultHorse.horseWeight.isNotEmpty && resultHorse.horseWeight != '--') {
            final weightMatch = RegExp(r'(\d+)\((.*?)\)').firstMatch(resultHorse.horseWeight);
            if (weightMatch != null) {
              shutubaHorse.horseWeight = weightMatch.group(1);
            } else if (RegExp(r'^\d+$').hasMatch(resultHorse.horseWeight)) {
              shutubaHorse.horseWeight = resultHorse.horseWeight;
            }
          }
        } catch (_) {
        }
      }
    }
    return data;
  }
  // ▲ [追加]

  // [修正] 共有ユーティリティRaceResultPredictionConverterへ処理を委譲（挙動は不変）。
  // スピード指数バックテストハーネスからも同一ロジックを再利用するため (v.2026.9.4)
  Future<PredictionRaceData> _createPredictionDataFromRaceResult(RaceResult raceResult) async {
    return RaceResultPredictionConverter.convert(raceResult, _horseRepo);
  }

  @override
  void initState() {
    super.initState();
    // [修正] 結果分析タブの廃止 Step2: 能力分析・出走馬分析に続いて騎手特性タブも削除したので 8 → 7 → 6 → 5 (v.2026.10.19+26101902)
    _tabController = TabController(length: 5, vsync: this);
    _determineRaceStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _determineRaceStatus() async {
    final shutubaCache = await _shutubaTableCacheRepository.getShutubaTableCache(widget.raceId);
    final dbResult = await _raceRepo.getRaceResult(widget.raceId);

    if (shutubaCache != null) {
      // ▼ [修正] オーナー画像・馬体重マージ処理をヘルパー化した _applyOwnerImageAndWeightMerge に統合 (v.2026.7.28+26072802)
      final enrichedData = await _applyOwnerImageAndWeightMerge(
          shutubaCache.predictionRaceData, dbResult);
      // ▲ [修正]
      setState(() {
        _predictionRaceData = enrichedData;
        _raceResult = dbResult;
        _status = RaceStatus.resultConfirmed;
        // [修正] 結果分析タブの廃止 Step2: 能力分析・出走馬分析・騎手特性のタブを削除したので、レース結果タブの位置は 6 → 5 → 4 → 3 (v.2026.10.19+26101902)
        _tabController.animateTo(dbResult != null ? 3 : 0);
      });

      try {
        final dateStr = shutubaCache.predictionRaceData.raceDate;
        final details = shutubaCache.predictionRaceData.raceDetails1 ?? '';

        final dateMatch = RegExp(r'(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})').firstMatch(dateStr);
        final timeMatch = RegExp(r'(\d{1,2}):(\d{2})発走').firstMatch(details);

        if (dateMatch != null && timeMatch != null) {
          final year = int.parse(dateMatch.group(1)!);
          final month = int.parse(dateMatch.group(2)!);
          final day = int.parse(dateMatch.group(3)!);
          final hour = int.parse(timeMatch.group(1)!);
          final minute = int.parse(timeMatch.group(2)!);

          final raceTime = DateTime(year, month, day, hour, minute);
          final now = DateTime.now();

          bool shouldFetch = false;

          if (dbResult == null) {
            if (now.isAfter(raceTime)) {
              shouldFetch = true;
            }
          } else {
            if (dbResult.lapTimes.isEmpty && now.difference(raceTime).inHours >= 24) {
              shouldFetch = true;
            }
          }

          if (shouldFetch) {
            final isConfirmed = await RaceResultScraperService.isRaceResultConfirmed(widget.raceId);
            if (isConfirmed && mounted) {
              await _fetchAndSaveRaceResult();
            }
          }
        }
      } catch (e) {
        debugPrint('Auto-check result error: $e');
      }

      return;
    }

    if (dbResult != null) {
      final generatedPredictionData = await _createPredictionDataFromRaceResult(dbResult);

      setState(() {
        _raceResult = dbResult;
        _predictionRaceData = generatedPredictionData;
        _status = RaceStatus.resultConfirmed;
        // [修正] 結果分析タブの廃止 Step2: レース結果タブの位置は 6 → 5 → 4 → 3 (v.2026.10.19+26101902)
        _tabController.animateTo(3);
      });

      // ▼ [追加] フェーズ1a-2: 裏で本物の出馬表(shutuba+newspaper)をスクレイプし、成功時のみ差し替える (v.2026.7.28+26072802)
      // 結果は既に即時表示済みのため、ここはUIをブロックしないベストエフォート処理。失敗時は結果構築データのまま維持する。
      try {
        await _scraperService.scrapeAllData(widget.raceId);
        final refreshedCache = await _shutubaTableCacheRepository.getShutubaTableCache(widget.raceId);
        if (refreshedCache != null && mounted) {
          final enrichedData = await _applyOwnerImageAndWeightMerge(
              refreshedCache.predictionRaceData, dbResult);
          if (mounted) {
            setState(() {
              _predictionRaceData = enrichedData;
              _shutubaRefreshGen++;
            });
          }
        }
      } catch (_) {
        // 過去ページが取得できないレースのフォールバック。結果構築データのまま表示を継続する。
      }
      // ▲ [追加]

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
      for (final horse in result.horseResults) {
        final existingRecords = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
        if (existingRecords.isEmpty) {
          try {
            final horseRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horse.horseId);
            for (final record in horseRecords) {
              await _horseRepo.insertOrUpdateHorsePerformance(record);
            }
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
          }
        }
      }

      if (mounted) {
        if (_predictionRaceData != null) {
          for (var shutubaHorse in _predictionRaceData!.horses) {
            try {
              final resultHorse = result.horseResults.firstWhere(
                    (hr) => hr.horseId == shutubaHorse.horseId,
              );
              if (resultHorse.horseWeight.isNotEmpty && resultHorse.horseWeight != '--') {
                final weightMatch = RegExp(r'(\d+)\((.*?)\)').firstMatch(resultHorse.horseWeight);
                if (weightMatch != null) {
                  shutubaHorse.horseWeight = weightMatch.group(1);
                } else if (RegExp(r'^\d+$').hasMatch(resultHorse.horseWeight)) {
                  shutubaHorse.horseWeight = resultHorse.horseWeight;
                }
              }
            } catch (_) {
            }
          }
        }
        setState(() {
          _raceResult = result;
          _status = RaceStatus.resultConfirmed;
          // [修正] 結果分析タブの廃止 Step2: レース結果タブの位置は 6 → 5 → 4 → 3 (v.2026.10.19+26101902)
          _tabController.animateTo(3);
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
    return Scaffold(
      // SafeAreaでステータスバー（時計や電池アイコン）との被りを防ぐ
      body: SafeArea(
        child: Column(
          children: [
            // AppBarの代わりとなるカスタムヘッダー領域
            Container(
              color: Theme.of(context).primaryColor, // 既存の緑色の背景
              child: Row(
                children: [
                  // 左端にスマートな戻るボタンを配置
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // 残りのスペースにタブを配置
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: const [
                        // [修正] 親タブの並び順を変更（出馬表/出走馬分析/能力分析/過去分析/オッズ分析/騎手特性/レース結果/レース詳細） (v.2026.9.5+26090506)
                        Tab(text: '出馬表'),
                        // [削除] 好走条件・個別成績・相対評価の移動 Step5: 「出走馬分析」のタブを外した（下の2か所と同じ順番で外す） (v.2026.10.17+26101710)
                        // [削除] 能力分析を馬詳細へ Step5: 「能力分析(Rt)」のタブを外した（下の2か所と同じ順番で外す） (v.2026.10.17+26101705)
                        Tab(text: '過去分析'),
                        Tab(text: 'オッズ分析'),
                        // [削除] 結果分析タブの廃止 Step2: 「騎手特性」のタブを外した（下の TabBarView の2か所と同じ順番で外す） (v.2026.10.19+26101902)
                        Tab(text: 'レース結果'),
                        Tab(text: 'レース詳細'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 下のコンテンツ部分（出馬表など）
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
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
              // [追加] 馬詳細タブStep3: 結果取得中もタブの移動はタップのみ（ほかの状態と同じ） (v.2026.9.23+26092308)
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // [修正] 親タブの並び替えに合わせてプレースホルダの順序も変更 (v.2026.9.5+26090506)
                ShutubaTablePage(raceId: widget.raceId),
                // [削除] 好走条件・個別成績・相対評価の移動 Step5: 出走馬分析の仮表示を外した (v.2026.10.17+26101710)
                // [削除] 能力分析を馬詳細へ Step5: 能力分析(Rt)の仮表示を外した (v.2026.10.17+26101705)
                const Center(child: CircularProgressIndicator()), // 過去分析
                const Center(child: Text('オッズを取得中...')), // オッズ分析
                // [削除] 結果分析タブの廃止 Step2: 騎手特性の仮表示を外した (v.2026.10.19+26101902)
                const Center(child: Text('レース結果を取得中です...')), // レース結果
                const Center(child: Text('レース結果を取得中です...')), // レース詳細
              ],
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        );
      case RaceStatus.beforeHolding:
      case RaceStatus.resultConfirmed:
        return TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // [修正] 親タブの並び替えに合わせて children の順序も変更（tabs と必ず同順） (v.2026.9.5+26090506)
            ShutubaTablePage(
              // ▼ [追加] 裏スクレイプ成功時(_shutubaRefreshGen加算)にこのタブを再マウントし、
              // ShutubaTablePage内部の初回ロード済みキャッシュではなく最新の本物の出馬表を読み直させる (v.2026.7.28+26072802)
              key: ValueKey('${widget.raceId}_$_shutubaRefreshGen'),
              // ▲ [追加]
              raceId: widget.raceId,
              predictionRaceData: _predictionRaceData,
              raceResult: _raceResult,
              onDataRefreshed: _onShutubaDataRefreshed,
            ),

            // [削除] 好走条件・個別成績・相対評価の移動 Step5: 出走馬分析タブを外した。過去走の取り直しまで計算を待つ仕組み（waitForPreparation）は、
            // 移した先が読み込み係の知らせ（戦績・調教の取り直しの完了）で読み直すので要らなくなった (v.2026.10.17+26101710)
            // [削除] 能力分析を馬詳細へ Step5: 能力分析タブを外した (v.2026.10.17+26101705)

            if (_predictionRaceData != null)
              RaceStatisticsPage(
                raceId: widget.raceId,
                raceName: _predictionRaceData!.raceName,
                // [追加] クラス判定の共通化 Step2: 出馬表のグレード欄（結果から作ったデータはレース名）から今回のクラスを作って渡す (v.2026.10.16+26101602)
                currentRaceClass: raceClassGradeOfCurrentRace(_predictionRaceData!),
              )
            else
              const Center(child: Text('出馬表データを読み込んでいます...')),
            if (_predictionRaceData != null)
              OddsPage(raceData: _predictionRaceData!)
            else
              const Center(child: Text('出馬表データを読み込んでいます...')),

            // [削除] 結果分析タブの廃止 Step2: 騎手特性タブ（JockeyStatsPage）を外した。その騎手との成績は出馬表の馬詳細タブで見られる (v.2026.10.19+26101902)
            RaceResultPage(raceId: widget.raceId, qrData: widget.qrData),
            RaceDetailTab(
              raceId: widget.raceId,
              raceResult: _raceResult,
              predictionHorses: _predictionRaceData?.horses,
            ),
          ],
        );
    }
  }
}