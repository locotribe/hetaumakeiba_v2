// lib/screens/odds_page.dart

import 'package:flutter/material.dart';
import '../models/race_data.dart';
import '../services/odds_cache_service.dart';
import '../services/odds_scraping_service.dart';
import '../widgets/odds_tabs/odds_list_tab.dart';
import '../widgets/odds_tabs/odds_win_place_widget.dart';
import '../widgets/odds_tabs/odds_matrix_widget.dart';

class OddsPage extends StatefulWidget {
  final PredictionRaceData raceData;

  const OddsPage({super.key, required this.raceData});

  @override
  State<OddsPage> createState() => _OddsPageState();
}

class _OddsPageState extends State<OddsPage> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 4, vsync: this);
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
    _loadOddsForType(_getCurrentTypeCode());
  }

  String _getCurrentTypeCode() {
    switch (_subTabController.index) {
      case 0: return 'b1';
      case 1: return 'b4';
      case 2: return 'b5';
      case 3: return 'b6';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          child: TabBar(
            controller: _subTabController,
            labelColor: Colors.blue.shade900,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue.shade900,
            tabs: const [
              Tab(text: '単複'),
              Tab(text: '馬連'),
              Tab(text: 'ワイド'),
              Tab(text: '馬単'),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              // 単複はリスト形式
              OddsWinPlaceWidget(oddsData: _allOddsData['b1']!, raceData: widget.raceData),
              // それ以外はマトリクス形式
              OddsMatrixWidget(oddsData: _allOddsData['b4']!, raceData: widget.raceData, type: 'b4'),
              OddsMatrixWidget(oddsData: _allOddsData['b5']!, raceData: widget.raceData, type: 'b5'),
              OddsMatrixWidget(oddsData: _allOddsData['b6']!, raceData: widget.raceData, type: 'b6'),
            ],
          ),
        ),
      ],
    );
  }
}