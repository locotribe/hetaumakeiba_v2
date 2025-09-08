// lib/screens/analytics_page.dart

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/yearly_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/category_summary_card.dart';
import 'package:hetaumakeiba_v2/widgets/dashboard_settings_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/services/analytics_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => AnalyticsPageState();
}

class AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isBusy = false;
  AnalyticsData _analysisData = AnalyticsData.empty();
  List<int> _availableYears = [];
  String _selectedPeriod = '総合';

  List<String> _visibleCards = [];
  TabController? _tabController;

  final DatabaseHelper _dbHelper = DatabaseHelper();

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
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {
        });
      }
    });
  }

  Future<void> _loadInitialSettingsAndData() async {
    await _loadDashboardSettings();
    _setupTabController();
    await _loadAnalyticsData();
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

  Future<void> _loadAnalyticsData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final userId = localUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _analysisData = AnalyticsData.empty();
        _availableYears = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報の取得に失敗しました。')),
      );
      return;
    }

    final int? filterYear = (_selectedPeriod == '総合') ? null : int.tryParse(_selectedPeriod);

    // 1. 利用可能な年のリストと、総合表示用の年別サマリーを取得
    final yearlySummariesMaps = await _dbHelper.getYearlySummaries(userId);
    final availableYears = yearlySummariesMaps
        .map((e) => int.parse(e['aggregate_key'].split('_').last))
        .toList()..sort((a, b) => b.compareTo(a));

    // 2. 各カテゴリのサマリーを取得
    final gradeSummaries = await _dbHelper.getCategorySummaries(userId, 'grade', year: filterYear);
    final venueSummaries = await _dbHelper.getCategorySummaries(userId, 'venue', year: filterYear);
    final distanceSummaries = await _dbHelper.getCategorySummaries(userId, 'distance', year: filterYear);
    final trackSummaries = await _dbHelper.getCategorySummaries(userId, 'track', year: filterYear);
    final ticketTypeSummaries = await _dbHelper.getCategorySummaries(userId, 'ticket_type', year: filterYear);
    final purchaseMethodSummaries = await _dbHelper.getCategorySummaries(userId, 'purchase_method', year: filterYear);

    final predictionStats = await _dbHelper.getPredictionStats(userId);

    // 3. 過去最高払戻は都度計算が必要なため、別途ロジックを呼び出す
    final topPayout = await _calculateTopPayoutOptimized(userId, filterYear: filterYear);

    final grandTotalSummary = await _dbHelper.getGrandTotalSummary(userId);

    // 4. DBから取得したデータをUIで使うためのAnalyticsDataモデルに変換
    final Map<int, YearlySummary> yearlySummaries = {};
    for (var map in yearlySummariesMaps) {
      final year = int.parse(map['aggregate_key'].split('_').last);
      final summary = YearlySummary(year: year)
        ..totalInvestment = map['total_investment']
        ..totalPayout = map['total_payout']
        ..totalHitCount = map['hit_count']
        ..totalBetCount = map['bet_count'];
      yearlySummaries[year] = summary;
    }

    if (filterYear != null) {
      final monthlyDataMaps = await _dbHelper.getMonthlyDataForYear(userId, filterYear);
      final yearSummary = yearlySummaries.putIfAbsent(filterYear, () => YearlySummary(year: filterYear));

      yearSummary.monthlyPurchaseDetails.clear();

      for (var map in monthlyDataMaps) {
        final month = int.parse(map['aggregate_key'].split('-').last);
        if (month >= 1 && month <= 12) {
          final dataPoint = yearSummary.monthlyData[month-1];
          dataPoint.investment = map['total_investment'];
          dataPoint.payout = map['total_payout'];
        }
      }
    }

    // 5. 最終的なデータを構築
    final data = AnalyticsData(
      yearlySummaries: yearlySummaries,
      gradeSummaries: gradeSummaries.map((m) => _mapToCategorySummary(m, 'grade_')).toList(),
      venueSummaries: venueSummaries.map((m) => _mapToCategorySummary(m, 'venue_')).toList(),
      distanceSummaries: distanceSummaries.map((m) => _mapToCategorySummary(m, 'distance_')).toList(),
      trackSummaries: trackSummaries.map((m) => _mapToCategorySummary(m, 'track_')).toList(),
      ticketTypeSummaries: ticketTypeSummaries.map((m) => _mapToCategorySummary(m, 'ticket_type_')).toList(),
      purchaseMethodSummaries: purchaseMethodSummaries.map((m) => _mapToCategorySummary(m, 'purchase_method_')).toList(),
      predictionStats: predictionStats,
      topPayout: topPayout,
      grandTotalSummary: grandTotalSummary,
    );

    if (!mounted) return;

    setState(() {
      _analysisData = data;
      _availableYears = availableYears;
      _isLoading = false;
    });
  }

  CategorySummary _mapToCategorySummary(Map<String, dynamic> map, String prefixToRemove) {
    String name = map['aggregate_key'].replaceFirst(prefixToRemove, '');
    if (name.contains('_')) {
      name = name.substring(0, name.lastIndexOf('_'));
    }

    return CategorySummary(
      name: name,
      investment: map['total_investment'],
      payout: map['total_payout'],
      hitCount: map['hit_count'],
      betCount: map['bet_count'],
    );
  }

  Future<TopPayoutInfo?> _calculateTopPayoutOptimized(String userId, {int? filterYear}) async {
    final allQrData = await _dbHelper.getAllQrData(userId);
    if (allQrData.isEmpty) {
      return null;
    }

    // 1. 全QRデータからユニークなraceIdを収集
    final raceIds = allQrData.map((qr) {
      try {
        final parsedTicket = json.decode(qr.parsedDataJson) as Map<String, dynamic>;
        final url = generateNetkeibaUrl(
          year: parsedTicket['年'].toString(),
          racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
          round: parsedTicket['回'].toString(),
          day: parsedTicket['日'].toString(),
          race: parsedTicket['レース'].toString(),
        );
        return RaceResultScraperService.getRaceIdFromUrl(url);
      } catch (e) {
        return null;
      }
    }).where((id) => id != null).toSet().toList();

    if (raceIds.isEmpty) {
      return null;
    }

    // 2. 必要なレース結果をDBから一括取得
    final raceResultsMap = await _dbHelper.getMultipleRaceResults(raceIds.cast<String>());

    TopPayoutInfo? topPayoutInfo;

    // 3. 再度QRデータをループし、今度はメモリ上のレース結果Mapを使って計算
    for (final qrData in allQrData) {
      Map<String, dynamic> parsedTicket;
      try {
        parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
      } catch (e) {
        continue;
      }

      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = RaceResultScraperService.getRaceIdFromUrl(url);
      if (raceId == null) continue;

      final raceResult = raceResultsMap[raceId];
      if (raceResult == null || raceResult.isIncomplete) continue;

      if (filterYear != null) {
        try {
          final raceDateYear = int.parse(raceResult.raceDate.split(RegExp(r'[年月日]')).first);
          if (raceDateYear != filterYear) continue;
        } catch (e) {
          continue;
        }
      }

      final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
      if (hitResult.isHit && (topPayoutInfo == null || hitResult.totalPayout > topPayoutInfo.payout)) {
        topPayoutInfo = TopPayoutInfo(
          payout: hitResult.totalPayout,
          raceName: raceResult.raceTitle,
          raceDate: raceResult.raceDate,
        );
      }
    }
    return topPayoutInfo;
  }

  void _onPeriodChanged(String newPeriod) {
    if (_selectedPeriod == newPeriod) return;
    setState(() {
      _selectedPeriod = newPeriod;
    });
    _loadAnalyticsData();
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
  /// 分析データを再構築する
  Future<void> _rebuildAnalyticsData() async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報が取得できませんでした。')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全収支データを再計算'),
        content: const Text('アプリのアップデートで新しい集計項目が追加された際や、データのズレが気になるときに実行してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('実行', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isBusy = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text("データを再構築中..."),
          ],
        ),
      ),
    );

    try {
      final db = await _dbHelper.database;
      await db.delete('analytics_aggregates', where: 'userId = ?', whereArgs: [userId]);

      final allQrData = await _dbHelper.getAllQrData(userId);
      final Set<String> raceIds = {};
      for (final qrData in allQrData) {
        try {
          final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
          final url = generateNetkeibaUrl(
            year: parsedTicket['年'].toString(),
            racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
            round: parsedTicket['回'].toString(),
            day: parsedTicket['日'].toString(),
            race: parsedTicket['レース'].toString(),
          );
          final raceId = RaceResultScraperService.getRaceIdFromUrl(url);
          if (raceId != null) {
            raceIds.add(raceId);
          }
        } catch (e) {
          print('Skipping a ticket due to parsing error during migration: $e');
        }
      }

      for (final raceId in raceIds) {
        await AnalyticsService().updateAggregatesOnResultConfirmed(raceId, userId);
      }

      await _loadAnalyticsData();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分析データの再構築が完了しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFilterVisible = true;
    if (_tabController != null && _visibleCards.isNotEmpty && _tabController!.index < _visibleCards.length) {
      final currentKey = _visibleCards[_tabController!.index];
      if (currentKey == 'grand_total_summary' || currentKey == 'prediction_summary') {
        isFilterVisible = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4314), // 背景色をテーマに合わせる
        title: TabBar(
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
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                showDashboardSettings();
              } else if (value == 'rebuild') {
                _rebuildAnalyticsData();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('表示項目の設定'),
              ),
              const PopupMenuItem<String>(
                value: 'rebuild',
                child: Text('収支データを再計算'),
              ),
            ],
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
          Column(
            children: [
              if (isFilterVisible) _buildPeriodFilter(),
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
                label: Text(period == '総合' ? '年別総合' : '$period年'),
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
          onRefresh: () => _loadAnalyticsData(),
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
      case 'grand_total_summary':
        return _buildGrandTotalContent();
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
      case 'prediction_summary':
        return _buildPredictionSummaryContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPredictionSummaryContent() {
    if (_analysisData.predictionStats.isEmpty) {
      return _buildPredictionEmptyState();
    }

    // データをソートする（例：試行回数が多い順）
    final sortedStats = List<PredictionStat>.from(_analysisData.predictionStats)
      ..sort((a, b) => b.totalCount.compareTo(a.totalCount));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '予想傾向分析',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('印')),
                  DataColumn(label: Text('勝率'), numeric: true),
                  DataColumn(label: Text('連対率'), numeric: true),
                  DataColumn(label: Text('複勝率'), numeric: true),
                  DataColumn(label: Text('試行'), numeric: true),
                ],
                rows: sortedStats.map((stat) {
                  return DataRow(cells: [
                    DataCell(Text(stat.mark, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    DataCell(Text('${stat.winRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${stat.placeRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${stat.showRate.toStringAsFixed(1)}%')),
                    DataCell(Text('${stat.totalCount} 回')),
                  ]);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '※勝率: 1着 / 連対率: 2着以内 / 複勝率: 3着以内',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'まだ予想が登録されていません',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const Text(
              '画面下の「開催一覧」や「重賞一覧」から\nレースを選び、あなたの予想印を登録してみましょう！\n分析結果がここに表示されます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey,
                  height: 1.5,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
              ),
            ),

          ],
        ),
      ),
    );
  }


  Widget _buildGrandTotalContent() {
    final summary = _analysisData.grandTotalSummary;
    if (summary == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: Text('表示できるデータがありません。',
                style: TextStyle(color: Colors.grey[600]))),
      );
    }

    final currencyFormatter = NumberFormat.decimalPattern('ja');
    final profit = summary.profit;
    Color profitColor = Colors.black87;
    if (profit > 0) profitColor = Colors.blue.shade700;
    if (profit < 0) profitColor = Colors.red.shade700;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                height: 300,
                child: _buildGrandTotalPieChart(summary),
              ),
            ),
            const Divider(height: 32),
            const Text(
              '総合計サマリー',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                _buildSummaryTableRow('総投資額', '${currencyFormatter.format(summary.investment)}円'),
                _buildSummaryTableRow('総払戻額', '${currencyFormatter.format(summary.payout)}円'),
                _buildSummaryTableRow('総収支', '${currencyFormatter.format(profit)}円', valueColor: profitColor),
                _buildSummaryTableRow('回収率', '${summary.recoveryRate.toStringAsFixed(1)}%'),
                _buildSummaryTableRow('的中率', '${summary.hitRate.toStringAsFixed(1)}%'),
              ],
            ),
            if (_analysisData.topPayout != null)
              const Divider(height: 32, thickness: 1),
            if (_analysisData.topPayout != null)
              _buildTopPayoutContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrandTotalPieChart(CategorySummary summary) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');
    final profit = summary.profit;
    final investment = summary.investment;
    final payout = summary.payout;

    List<PieChartSectionData> sections = [];
    if (investment == 0) {
      return const Center(child: Text('データがありません'));
    }

    if (profit >= 0) {
      sections = [
        PieChartSectionData(
          color: Colors.blue.shade700,
          value: profit.toDouble(),
          title: '${(profit / investment * 100).toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: investment.toDouble(),
          title: '',
          radius: 50,
        ),
      ];
    } else {
      sections = [
        PieChartSectionData(
          color: Colors.green.shade600,
          value: payout.toDouble(),
          title: '${(payout / investment * 100).toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        PieChartSectionData(
          color: Colors.red.shade700,
          value: (profit * -1).toDouble(),
          title: '',
          radius: 50,
        ),
      ];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: profit >= 0
              ? [
            _buildLegend(Colors.blue.shade700, '純利益', currencyFormatter.format(profit)),
            const SizedBox(width: 16),
            _buildLegend(Colors.grey.shade400, '払戻原資', currencyFormatter.format(investment)),
          ]
              : [
            _buildLegend(Colors.green.shade600, '払戻額', currencyFormatter.format(payout)),
            const SizedBox(width: 16),
            _buildLegend(Colors.red.shade700, '損失額', currencyFormatter.format(profit * -1)),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String text, String amount) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 14)),
            Text('$amount円', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }


  TableRow _buildSummaryTableRow(String label, String value, {Color? valueColor}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: valueColor ?? Colors.black87),
          ),
        ),
      ],
    );
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
    final overallTotal = summaries.fold<Map<String, num>>(
      {'investment': 0, 'payout': 0, 'profit': 0, 'hitCount': 0, 'betCount': 0},
          (prev, s) => {
        'investment': prev['investment']! + s.totalInvestment,
        'payout': prev['payout']! + s.totalPayout,
        'profit': prev['profit']! + s.totalProfit,
        'hitCount': prev['hitCount']! + s.totalHitCount,
        'betCount': prev['betCount']! + s.totalBetCount,
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
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
              reservedSize: 20,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
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

  Widget _buildOverallSummaryTable(List<YearlySummary> summaries, NumberFormat formatter, Map<String, num> overallTotal) {
    final rows = summaries.map((s) {
      final profitColor = s.totalProfit > 0 ? Colors.blue.shade700 : (s.totalProfit < 0 ? Colors.red.shade700 : Colors.black87);
      return DataRow(cells: [
        DataCell(Text('${s.year}年')),
        DataCell(Text(formatter.format(s.totalInvestment))),
        DataCell(Text(formatter.format(s.totalPayout))),
        DataCell(Text(formatter.format(s.totalProfit), style: TextStyle(color: profitColor))),
        DataCell(Text('${s.totalRecoveryRate.toStringAsFixed(1)}%')),
        DataCell(Text('${s.totalHitRate.toStringAsFixed(1)}%')),
      ]);
    }).toList();

    // Add total row
    final totalProfit = overallTotal['profit']!;
    final totalRecoveryRate = overallTotal['investment']! == 0 ? 0.0 : (overallTotal['payout']! / overallTotal['investment']!) * 100;
    final totalProfitColor = totalProfit > 0 ? Colors.blue.shade700 : (totalProfit < 0 ? Colors.red.shade700 : Colors.black87);
    final totalHitCount = overallTotal['hitCount']!;
    final totalBetCount = overallTotal['betCount']!;
    final totalHitRate = totalBetCount == 0 ? 0.0 : (totalHitCount / totalBetCount) * 100;

    rows.add(DataRow(
        cells: [
          const DataCell(Text('累計', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(formatter.format(overallTotal['investment']), style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(formatter.format(overallTotal['payout']), style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(formatter.format(totalProfit), style: TextStyle(color: totalProfitColor, fontWeight: FontWeight.bold))),
          DataCell(Text('${totalRecoveryRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${totalHitRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
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
          DataColumn(label: Text('的中率'), numeric: true),
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