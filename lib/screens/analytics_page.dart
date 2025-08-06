// lib/screens/analytics_page.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analytics_logic.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/yearly_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/category_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/dashboard_settings_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => AnalyticsPageState();
}

class AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  AnalyticsData _analysisData = AnalyticsData.empty();
  List<int> _availableYears = [];
  String _selectedPeriod = '総合'; // '総合' or 'YYYY'

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
    _setupTabController();
    await _loadAnalyticsData(isInitialLoad: true);
  }

  Future<void> _loadDashboardSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCards = prefs.getStringList('dashboard_visible_cards');

    final initialCards = availableCards.keys.toList();
    if (savedCards == null) {
      _visibleCards = initialCards;
    } else {
      final tempVisible = savedCards.toSet();
      if (savedCards.contains('top_payout')) {
        tempVisible.add('yearly_summary');
      }
      tempVisible.remove('top_payout');
      _visibleCards = initialCards.where((card) => tempVisible.contains(card)).toList();
    }
  }

  Future<void> _loadAnalyticsData({bool isInitialLoad = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final int? filterYear = (_selectedPeriod == '総合') ? null : int.tryParse(_selectedPeriod);
    // 安全なバックグラウンド処理を呼び出すように変更
    final data = await _logic.calculateAnalyticsDataInBackground(filterYear: filterYear);
    if (!mounted) return;

    // isInitialLoad時、または「総合」を選択した際に利用可能な年のリストを更新
    if (isInitialLoad || _selectedPeriod == '総合') {
      // 全期間のデータをバックグラウンドで取得して年リストを作成
      final allData = await _logic.calculateAnalyticsDataInBackground(filterYear: null);
      if (mounted) {
        _availableYears = allData.yearlySummaries.keys.toList()..sort((a, b) => b.compareTo(a));
      }
    }

    setState(() {
      _analysisData = data;
      _isLoading = false;
    });
  }

  void _onPeriodChanged(String newPeriod) {
    if (_selectedPeriod == newPeriod) return;
    setState(() {
      _selectedPeriod = newPeriod;
    });
    _loadAnalyticsData(isInitialLoad: false);
  }

  void showDashboardSettings() {
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
                _setupTabController();
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
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          Column(
            children: [
              if (_tabController != null)
                Container(
                  color: const Color(0xFF1A4314),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.blue.shade100,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: _visibleCards.map((key) {
                      final title = availableCards[key] ?? '不明';
                      return Tab(text: title);
                    }).toList(),
                  ),
                ),
              _buildPeriodFilter(),
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    List<String> periods = ['総合', ..._availableYears.map((y) => y.toString())];
    if (_availableYears.isEmpty && !_isLoading) {
      periods = ['総合', DateTime.now().year.toString()];
    } else if (_isLoading && _availableYears.isEmpty) {
      return const SizedBox(height: 48); // 読み込み中は高さを確保
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((period) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(period == '総合' ? '総合' : '$period年'),
                selected: _selectedPeriod == period,
                onSelected: (isSelected) {
                  if (isSelected) {
                    _onPeriodChanged(period);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tabController == null) {
      return const Center(child: Text('表示設定を読み込んでいます...'));
    }
    return _buildTabView();
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: _visibleCards.map<Widget>((key) {
        final pageContent = _buildPageContent(key);
        return RefreshIndicator(
          onRefresh: () => _loadAnalyticsData(isInitialLoad: false),
          child: ListView(
            key: PageStorageKey<String>(key),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8.0),
            children: [pageContent],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPageContent(String key) {
    switch (key) {
      case 'yearly_summary':
        final bool isOverallMode = _selectedPeriod == '総合';
        final yearlySummaries = _analysisData.yearlySummaries.values.toList()
          ..sort((a, b) => a.year.compareTo(b.year));

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              isOverallMode
                  ? _buildOverallContent(yearlySummaries)
                  : _buildYearlyContent(),

              if (_analysisData.topPayout != null)
                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),

              if (_analysisData.topPayout != null)
                _buildTopPayoutContent(),
            ],
          ),
        );
      case 'grade_summary':
        return CategorySummaryCard(
          title: 'グレード別 収支',
          summaries: _analysisData.gradeSummaries,
        );
      case 'venue_summary':
        return CategorySummaryCard(
          title: '競馬場別 収支',
          summaries: _analysisData.venueSummaries,
        );
      case 'distance_summary':
        return CategorySummaryCard(
          title: '距離別 収支',
          summaries: _analysisData.distanceSummaries,
        );
      case 'track_summary':
        return CategorySummaryCard(
          title: '馬場状態別 収支',
          summaries: _analysisData.trackSummaries,
        );
      case 'ticket_type_summary':
        return CategorySummaryCard(
          title: '式別 収支',
          summaries: _analysisData.ticketTypeSummaries,
        );
      case 'purchase_method_summary':
        return CategorySummaryCard(
          title: '方式別 収支',
          summaries: _analysisData.purchaseMethodSummaries,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverallContent(List<YearlySummary> summaries) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');
    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: Text('表示できるデータがありません。',
                style: TextStyle(color: Colors.grey[600]))),
      );
    }

    // 全期間の合計を計算
    final overallTotal = summaries.fold<Map<String, int>>(
      {'investment': 0, 'payout': 0, 'profit': 0},
          (prev, s) => {
        'investment': prev['investment']! + s.totalInvestment,
        'payout': prev['payout']! + s.totalPayout,
        'profit': prev['profit']! + s.totalProfit,
      },
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '年別収支比較',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildOverallBarChart(summaries, currencyFormatter),
          ),
          const SizedBox(height: 24),
          _buildOverallSummaryTable(summaries, currencyFormatter, overallTotal),
        ],
      ),
    );
  }

  Widget _buildOverallBarChart(List<YearlySummary> summaries, NumberFormat formatter) {
    final profits = summaries.map((s) => s.totalProfit.toDouble());
    final maxProfit = profits.fold(0.0, (max, p) => p > max ? p : max);
    final minProfit = profits.fold(0.0, (min, p) => p < min ? p : min);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxProfit > 0 ? maxProfit * 1.2 : 1000,
        minY: minProfit < 0 ? minProfit * 1.2 : 0,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 20,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final year = summaries[groupIndex].year;
              final profit = rod.toY.toInt();
              return BarTooltipItem(
                '$year年\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: formatter.format(profit),
                    style: TextStyle(
                      color: profit >= 0 ? Colors.lightBlueAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' 円', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              );
            },
          ),
        ),
        barGroups: List.generate(summaries.length, (index) {
          final summary = summaries[index];
          return BarChartGroupData(
            x: summary.year,
            barRods: [
              BarChartRodData(
                toY: summary.totalProfit.toDouble(),
                color: summary.totalProfit >= 0 ? Colors.blue : Colors.red,
                width: 16,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildOverallSummaryTable(List<YearlySummary> summaries, NumberFormat formatter, Map<String, int> overallTotal) {
    final rows = summaries.map((s) {
      final profitColor = s.totalProfit > 0 ? Colors.blue.shade700 : (s.totalProfit < 0 ? Colors.red.shade700 : Colors.black87);
      return DataRow(cells: [
        DataCell(Text('${s.year}年')),
        DataCell(Text(formatter.format(s.totalInvestment))),
        DataCell(Text(formatter.format(s.totalPayout))),
        DataCell(Text(formatter.format(s.totalProfit), style: TextStyle(color: profitColor))),
        DataCell(Text('${s.totalRecoveryRate.toStringAsFixed(1)}%')),
      ]);
    }).toList();

    // Add total row
    final totalProfit = overallTotal['profit']!;
    final totalRecoveryRate = overallTotal['investment']! == 0 ? 0.0 : (overallTotal['payout']! / overallTotal['investment']!) * 100;
    final totalProfitColor = totalProfit > 0 ? Colors.blue.shade700 : (totalProfit < 0 ? Colors.red.shade700 : Colors.black87);

    rows.add(DataRow(
        cells: [
          const DataCell(Text('累計', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(formatter.format(overallTotal['investment']), style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(formatter.format(overallTotal['payout']), style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(formatter.format(totalProfit), style: TextStyle(color: totalProfitColor, fontWeight: FontWeight.bold))),
          DataCell(Text('${totalRecoveryRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
        ]
    ));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('年度')),
          DataColumn(label: Text('投資額'), numeric: true),
          DataColumn(label: Text('払戻額'), numeric: true),
          DataColumn(label: Text('収支'), numeric: true),
          DataColumn(label: Text('回収率'), numeric: true),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildYearlyContent() {
    final selectedYear = int.tryParse(_selectedPeriod);
    if (selectedYear == null) return const SizedBox.shrink();

    final selectedYearSummary = _analysisData.yearlySummaries[selectedYear];
    if (selectedYearSummary == null) {
      return YearlySummaryCard(
        yearlySummary: YearlySummary(year: selectedYear),
      );
    }
    return YearlySummaryCard(
      yearlySummary: selectedYearSummary,
    );
  }

  Widget _buildTopPayoutContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '過去最高払戻',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  '${NumberFormat.decimalPattern('ja').format(_analysisData.topPayout!.payout)}円',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _analysisData.topPayout!.raceName,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _analysisData.topPayout!.raceDate,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}