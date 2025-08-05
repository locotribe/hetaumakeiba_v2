// lib/screens/analytics_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analytics_logic.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/screens/settings_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/yearly_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/category_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/dashboard_settings_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  AnalyticsData? _analysisData;
  int? _selectedYear;
  List<int> _availableYears = [];

  List<String> _visibleCards = [];
  TabController? _tabController;

  final AnalyticsLogic _logic = AnalyticsLogic();

  @override
  void initState() {
    super.initState();
    _loadInitialSettingsAndData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _setupTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: _visibleCards.length, vsync: this);
  }

  Future<void> _loadInitialSettingsAndData() async {
    await _loadDashboardSettings();
    await _loadAnalyticsData();
  }

  Future<void> _loadDashboardSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCards = prefs.getStringList('dashboard_visible_cards');

    // 表示設定に 'yearly_summary' がない場合、強制的に追加する
    // これにより、'top_payout' の設定が消えても表示が維持される
    final initialCards = availableCards.keys.toList();
    if (savedCards == null) {
      _visibleCards = initialCards;
    } else {
      // 'top_payout' が保存されていても、UI上は 'yearly_summary' に統合されているため、
      // 'yearly_summary' がリストに含まれていることを保証する
      final tempVisible = savedCards.toSet();
      if (savedCards.contains('top_payout')) {
        tempVisible.add('yearly_summary');
      }
      // 'top_payout' はタブとして表示しないので、リストからは除外する
      tempVisible.remove('top_payout');

      // 元の順序を維持しつつ、表示するカードを確定する
      _visibleCards = initialCards.where((card) => tempVisible.contains(card)).toList();
    }

    setState(() {});
  }

  Future<void> _loadAnalyticsData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final data = await _logic.calculateAnalyticsData();
    if (!mounted) return;

    setState(() {
      _analysisData = data;
      if (data.yearlySummaries.keys.isNotEmpty) {
        _availableYears = data.yearlySummaries.keys.toList()..sort((a, b) => b.compareTo(a));
        _selectedYear = _availableYears.first;
      }
      _isLoading = false;
      if (_visibleCards.isNotEmpty) {
        _setupTabController();
      }
    });
  }

  void _onYearChanged(int newYear) {
    setState(() {
      _selectedYear = newYear;
    });
  }

  void _showDashboardSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: DashboardSettingsSheet(
            visibleCards: _visibleCards,
            onSettingsChanged: (newSettings) {
              setState(() {
                _visibleCards = newSettings;
                if (_visibleCards.isNotEmpty) {
                  _setupTabController();
                }
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // データがない、またはロード中の場合はタブを表示しない
    final bool showTabs = !_isLoading && _analysisData != null && _analysisData!.yearlySummaries.isNotEmpty && _tabController != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('収支分析'),
        titleSpacing: 0,
        backgroundColor: const Color.fromRGBO(172, 234, 231, 1.0),
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '表示設定',
            onPressed: _showDashboardSettings,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'アプリ設定',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: showTabs
            ? TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _visibleCards.map((key) {
            final title = availableCards[key] ?? '不明';
            return Tab(text: title);
          }).toList(),
        )
            : null,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_analysisData == null || _selectedYear == null || _analysisData!.yearlySummaries.isEmpty)
          ? LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Text(
                  '表示できるデータがありません。\n馬券を登録してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
          );
        },
      )
          : _buildTabView(),
    );
  }

  Widget _buildTabView() {
    if (_tabController == null) {
      return const Center(child: Text('表示するカードがありません。'));
    }

    final selectedYearSummary = _analysisData!.yearlySummaries[_selectedYear!];

    return TabBarView(
      controller: _tabController,
      children: _visibleCards.map<Widget>((key) {
        final pageContent = _buildPageContent(key, selectedYearSummary);
        // 各ページをListViewでラップして、一貫したスクロール挙動とパディングを適用
        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: [pageContent],
        );
      }).toList(),
    );
  }

  Widget _buildPageContent(String key, YearlySummary? selectedYearSummary) {
    switch (key) {
      case 'yearly_summary':
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              // Part 1: Yearly Summary content
              if (selectedYearSummary != null)
                YearlySummaryCard(
                  yearlySummary: selectedYearSummary,
                  availableYears: _availableYears,
                  selectedYear: _selectedYear!,
                  onYearChanged: _onYearChanged,
                ),

              // Separator
              if (selectedYearSummary != null && _analysisData!.topPayout != null)
                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),

              // Part 2: Top Payout content
              if (_analysisData!.topPayout != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '過去最高払戻', // Title as requested
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '${NumberFormat.decimalPattern('ja').format(_analysisData!.topPayout!.payout)}円',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _analysisData!.topPayout!.raceName,
                              style: const TextStyle(fontSize: 14, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _analysisData!.topPayout!.raceDate,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'grade_summary':
        return CategorySummaryCard(
          title: 'グレード別 収支',
          summaries: _analysisData!.gradeSummaries,
        );
      case 'venue_summary':
        return CategorySummaryCard(
          title: '競馬場別 収支',
          summaries: _analysisData!.venueSummaries,
        );
      case 'distance_summary':
        return CategorySummaryCard(
          title: '距離別 収支',
          summaries: _analysisData!.distanceSummaries,
        );
      case 'track_summary':
        return CategorySummaryCard(
          title: '馬場状態別 収支',
          summaries: _analysisData!.trackSummaries,
        );
      case 'ticket_type_summary':
        return CategorySummaryCard(
          title: '式別 収支',
          summaries: _analysisData!.ticketTypeSummaries,
        );
      case 'purchase_method_summary':
        return CategorySummaryCard(
          title: '方式別 収支',
          summaries: _analysisData!.purchaseMethodSummaries,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}