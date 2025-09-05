// lib/screens/race_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/screens/race_result_page.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_result_page.dart';

// レースの状態を管理するためのenum
enum RaceStatus { loading, beforeHolding, resultConfirmed, resultUnconfirmed }

class RacePage extends StatefulWidget {
  final String raceId;
  final String raceDate; // YYYY年MM月DD日の形式を想定

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _determineRaceStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _determineRaceStatus() async {
    // 1. DBキャッシュチェックを先に行う
    final dbResult = await _dbHelper.getRaceResult(widget.raceId);
    if (dbResult != null) {
      setState(() {
        _raceResult = dbResult;
        _status = RaceStatus.resultConfirmed;
        _tabController.animateTo(1); // DBに結果があれば、結果タブを初期表示
      });
      return;
    }

    // 2. レース結果がWebで確定しているかチェック
    final isConfirmed = await RaceResultScraperService.isRaceResultConfirmed(widget.raceId);

    if (isConfirmed) {
      // 3. 結果確定後（キャッシュなし）
      setState(() {
        _status = RaceStatus.resultUnconfirmed;
        _tabController.animateTo(0); // まずは出馬表タブを表示しつつ裏で結果取得
      });
      _fetchAndSaveRaceResult();
    } else {
      // 4. 結果未確定（開催前または当日未実施）
      setState(() {
        _status = RaceStatus.beforeHolding;
        _tabController.animateTo(0); // 出馬表タブを初期表示
      });
    }
  }


  Future<void> _fetchAndSaveRaceResult() async {
    try {
      final result = await RaceResultScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/${widget.raceId}');
      await _dbHelper.insertOrUpdateRaceResult(result);
      if (mounted) {
        setState(() {
          _raceResult = result;
          _status = RaceStatus.resultConfirmed;
          _tabController.animateTo(1); // データ取得後に結果タブへ移動
        });
      }
    } catch (e) {
      print('Failed to fetch race result in RacePage: $e');
      // エラーが発生した場合でも、UIは「開催前」のような状態で操作可能にしておく
      if (mounted) {
        setState(() {
          _status = RaceStatus.beforeHolding; // フォールバックとして開催前状態にする
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レース情報'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '出馬表'),
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
                // データ取得中も出馬表は表示
                ShutubaTablePage(raceId: widget.raceId),
                const Center(child: Text('レース結果を取得中です...')),
                const Center(child: Text('レース結果を取得中です...')),
              ],
            ),
            // ローディングインジケータをオーバーレイ表示
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
              raceResult: _raceResult, // 確定済みの場合はRaceResultを渡す
            ),
            RaceResultPage(raceId: widget.raceId, qrData: null), // qrDataはnullで渡す
            AiPredictionResultPage(raceId: widget.raceId),
          ],
        );
    }
  }
}