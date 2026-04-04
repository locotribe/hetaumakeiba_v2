// lib/screens/odds_page.dart

import 'package:flutter/material.dart';
import '../models/race_data.dart';
import '../services/odds_cache_service.dart';
import '../services/odds_scraping_service.dart';
import '../widgets/odds_tabs/odds_list_tab.dart';
import '../widgets/odds_tabs/odds_win_place_widget.dart';
import '../widgets/odds_tabs/odds_matrix_widget.dart';
import '../widgets/odds_tabs/odds_analysis_tab.dart';

class OddsPage extends StatefulWidget {
  final PredictionRaceData raceData;

  const OddsPage({super.key, required this.raceData});

  @override
  State<OddsPage> createState() => _OddsPageState();
}

// [修正] 状態を保持するためにAutomaticKeepAliveClientMixinを追加 (v1.2)
class _OddsPageState extends State<OddsPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _subTabController;
  final OddsCacheService _cacheService = OddsCacheService();
  final OddsScrapingService _scrapingService = OddsScrapingService();

  bool _isLoading = false;
  Map<String, List<Map<String, String>>> _allOddsData = {
    'b1': [], // 単複
    'b4': [], // 馬連
    'b5': [], // ワイド
    'b6': [], // 馬単
  };

  // [追加] 状態保持を有効化 (v1.2)
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 5, vsync: this);
    _subTabController.addListener(_handleTabSelection);
    _loadInitialOdds();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_subTabController.indexIsChanging) return;
    final typeCode = _getCurrentTypeCode();

    if (typeCode.isNotEmpty) {
      _loadOddsForType(typeCode);
    } else {
      // [追加] 分析タブが選択された場合、不足している全データを一括取得 (v1.2)
      _loadAllOddsForAnalysis();
    }
  }

  String _getCurrentTypeCode() {
    switch (_subTabController.index) {
      case 0: return 'b1';
      case 1: return 'b4';
      case 2: return 'b5';
      case 3: return 'b6';
      case 4: return '';
      default: return 'b1';
    }
  }

  Future<void> _loadInitialOdds() async {
    _loadOddsForType('b1');
  }

  Future<void> _loadOddsForType(String type, {bool forceRefresh = false}) async {
    if (_isLoading) return;

    if (!forceRefresh && _allOddsData[type]!.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<Map<String, String>>? data;

      if (!forceRefresh) {
        data = await _cacheService.getValidCachedOdds(raceId: widget.raceData.raceId, type: type);
      }

      if (data == null) {
        data = await _scrapingService.fetchOddsViaWebView(raceId: widget.raceData.raceId, oddsType: type);
        if (data.isNotEmpty) {
          await _cacheService.saveOddsData(raceId: widget.raceData.raceId, type: type, oddsData: data);
        }
      }

      if (mounted) {
        setState(() {
          _allOddsData[type] = data!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [追加] 分析タブ用に全券種のデータを一括取得する処理 (v1.2)
  Future<void> _loadAllOddsForAnalysis() async {
    if (_isLoading) return;

    final types = ['b1', 'b4', 'b5', 'b6'];
    bool needsFetch = false;
    for (var type in types) {
      if (_allOddsData[type]!.isEmpty) {
        needsFetch = true;
        break;
      }
    }

    if (!needsFetch) return;

    setState(() => _isLoading = true);

    for (var type in types) {
      if (_allOddsData[type]!.isEmpty) {
        try {
          List<Map<String, String>>? data = await _cacheService.getValidCachedOdds(raceId: widget.raceData.raceId, type: type);
          if (data == null) {
            data = await _scrapingService.fetchOddsViaWebView(raceId: widget.raceData.raceId, oddsType: type);
            if (data.isNotEmpty) {
              await _cacheService.saveOddsData(raceId: widget.raceData.raceId, type: type, oddsData: data);
            }
          }
          if (mounted && data != null) {
            _allOddsData[type] = data;
          }
        } catch (e) {
          // エラー時は空リストのまま続行
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // [追加] AutomaticKeepAliveClientMixinのためsuper.buildを呼び出す (v1.2)
    super.build(context);

    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          child: TabBar(
            controller: _subTabController,
            labelColor: Colors.blue.shade900,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue.shade900,
            isScrollable: true,
            tabs: const [
              Tab(text: '単複'),
              Tab(text: '馬連'),
              Tab(text: 'ワイド'),
              Tab(text: '馬単'),
              Tab(text: '分析'),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              OddsWinPlaceWidget(oddsData: _allOddsData['b1']!, raceData: widget.raceData),
              OddsMatrixWidget(oddsData: _allOddsData['b4']!, raceData: widget.raceData, type: 'b4'),
              OddsMatrixWidget(oddsData: _allOddsData['b5']!, raceData: widget.raceData, type: 'b5'),
              OddsMatrixWidget(oddsData: _allOddsData['b6']!, raceData: widget.raceData, type: 'b6'),
              OddsAnalysisTab(allOddsData: _allOddsData, raceData: widget.raceData),
            ],
          ),
        ),
      ],
    );
  }
}