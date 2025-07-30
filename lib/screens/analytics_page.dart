// lib/screens/analytics_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analytics_logic.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/screens/settings_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/yearly_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/category_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/dashboard_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  AnalyticsData? _analysisData;
  int? _selectedYear;
  List<int> _availableYears = [];

  List<String> _visibleCards = [];

  final AnalyticsLogic _logic = AnalyticsLogic();

  @override
  void initState() {
    super.initState();
    _loadInitialSettingsAndData();
  }

  Future<void> _loadInitialSettingsAndData() async {
    await _loadDashboardSettings();
    await _loadAnalyticsData();
  }

  Future<void> _loadDashboardSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCards = prefs.getStringList('dashboard_visible_cards');
    if (savedCards == null) {
      setState(() {
        _visibleCards = availableCards.keys.toList();
      });
    } else {
      setState(() {
        _visibleCards = savedCards;
      });
    }
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
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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

  // --- ▼▼▼ ここからが修正箇所 ▼▼▼ ---
  Widget _buildBody() {
    // RefreshIndicatorを最上位に配置し、常にスワイプ可能にする
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_analysisData == null || _selectedYear == null || _analysisData!.yearlySummaries.isEmpty)
      // データがない場合もスクロール可能にするためのウィジェット構成
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
      // データがある場合は、これまで通りListViewを表示
          : _buildDataView(),
    );
  }

  // データがある場合の表示部分を別ウィジェットに分離
  Widget _buildDataView() {
    final selectedYearSummary = _analysisData!.yearlySummaries[_selectedYear!];

    final Map<String, Widget> allWidgets = {
      'yearly_summary': selectedYearSummary != null
          ? YearlySummaryCard(
        yearlySummary: selectedYearSummary,
        availableYears: _availableYears,
        selectedYear: _selectedYear!,
        onYearChanged: _onYearChanged,
      )
          : const SizedBox.shrink(),
      'grade_summary': CategorySummaryCard(
        title: 'グレード別 収支',
        summaries: _analysisData!.gradeSummaries,
      ),
      'venue_summary': CategorySummaryCard(
        title: '競馬場別 収支',
        summaries: _analysisData!.venueSummaries,
      ),
      'distance_summary': CategorySummaryCard(
        title: '距離別 収支',
        summaries: _analysisData!.distanceSummaries,
      ),
      'track_summary': CategorySummaryCard(
        title: '馬場状態別 収支',
        summaries: _analysisData!.trackSummaries,
      ),
      'ticket_type_summary': CategorySummaryCard(
        title: '式別 収支',
        summaries: _analysisData!.ticketTypeSummaries,
      ),
      'purchase_method_summary': CategorySummaryCard(
        title: '方式別 収支',
        summaries: _analysisData!.purchaseMethodSummaries,
      ),
    };

    final List<Widget> cardsToShow = _visibleCards
        .where((key) => allWidgets.containsKey(key))
        .map((key) => allWidgets[key]!)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: cardsToShow,
    );
  }
// --- ▲▲▲ ここまでが修正箇所 ▲▲▲ ---
}
