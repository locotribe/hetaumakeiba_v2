// lib/screens/race_schedule_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/services/race_schedule_scraper_service.dart';
import 'package:intl/intl.dart';

class RaceSchedulePage extends StatefulWidget {
  const RaceSchedulePage({super.key});

  @override
  RaceSchedulePageState createState() => RaceSchedulePageState();
}

class RaceSchedulePageState extends State<RaceSchedulePage>
    with TickerProviderStateMixin {
  final RaceScheduleScraperService _scraperService = RaceScheduleScraperService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = false;
  bool _isDataLoaded = false;
  String _loadingMessage = '';
  DateTime _currentDate = DateTime.now();
  List<DateTime> _weekDates = [];

  final Map<String, RaceSchedule?> _raceSchedules = {};
  List<String> _availableDates = [];
  final Set<String> _loadingTabs = {};

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _calculateWeek(_currentDate);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  void _calculateWeek(DateTime date) {
    if (!mounted) return;
    setState(() {
      _currentDate = date;
      final int daysToSubtract = date.weekday - 1;
      final DateTime monday = date.subtract(Duration(days: daysToSubtract));
      _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));

      _isDataLoaded = false;
      _isLoading = false;
      _availableDates.clear();
      _raceSchedules.clear();
      _tabController?.removeListener(_handleTabSelection);
      _tabController?.dispose();
      _tabController = null;
    });

    fetchInitialDataIfNeeded();
  }

  Future<void> fetchInitialDataIfNeeded() async {
    if (_isDataLoaded || _isLoading) return;
    await _fetchInitialWeekData();
  }

  Future<void> _fetchInitialWeekData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = '開催日をチェック中...';
    });

    try {
      final representativeDate = _weekDates.last;
      final (dateStrings, initialSchedule) = await _scraperService.fetchInitialData(representativeDate);

      _isDataLoaded = true;

      if (dateStrings.isEmpty && initialSchedule == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (initialSchedule != null) {
        await _dbHelper.insertOrUpdateRaceSchedule(initialSchedule);
        _raceSchedules[initialSchedule.date] = initialSchedule;
      }

      _setupTabs(dateStrings);

    } catch (e) {
      print("Error fetching initial data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データ取得エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupTabs(List<String> yyyymmddStrings) {
    final weekDateSet = _weekDates.map((d) => DateFormat('yyyyMMdd').format(d)).toSet();
    final filteredDates = yyyymmddStrings.where((ds) => weekDateSet.contains(ds)).toList();

    if (filteredDates.isEmpty) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }

    _availableDates = filteredDates.map((ds) {
      try {
        final year = int.parse(ds.substring(0, 4));
        final month = int.parse(ds.substring(4, 6));
        final day = int.parse(ds.substring(6, 8));
        return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
      } catch (e) {
        return null;
      }
    }).where((d) => d != null).cast<String>().toList();

    int initialIndex = _availableDates.indexOf(DateFormat('yyyy-MM-dd').format(_weekDates.last));
    if (initialIndex == -1) initialIndex = _availableDates.isNotEmpty ? _availableDates.length - 1 : 0;

    _tabController = TabController(
      initialIndex: initialIndex,
      length: _availableDates.length,
      vsync: this,
    );
    _tabController?.addListener(_handleTabSelection);
    _handleTabSelection();
  }

  void _handleTabSelection() {
    if (!mounted || _tabController == null || _tabController!.indexIsChanging) return;

    final selectedDate = _availableDates[_tabController!.index];
    if (!_raceSchedules.containsKey(selectedDate) && !_loadingTabs.contains(selectedDate)) {
      _fetchDataForDate(selectedDate);
    }
  }

  Future<void> _fetchDataForDate(String dateString) async {
    if (!mounted) return;
    setState(() {
      _loadingTabs.add(dateString);
    });

    try {
      final date = DateFormat('yyyy-MM-dd', 'en_US').parse(dateString);
      final schedule = await _scraperService.scrapeRaceSchedule(date);
      if (schedule != null) {
        await _dbHelper.insertOrUpdateRaceSchedule(schedule);
      }
      if (mounted) {
        setState(() {
          _raceSchedules[dateString] = schedule;
        });
      }
    } catch (e) {
      print("Error fetching data for $dateString: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loadingTabs.remove(dateString);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          _buildWeekNavigator(),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage),
          ],
        ),
      );
    }

    if (!_isDataLoaded) {
      return const Center(
        child: Text(
          '開催情報を読み込みます',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (_availableDates.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchInitialWeekData,
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Text(
                  'この週は開催予定がありません。\n（画面を下に引っ張って更新）',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          );
        }),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _availableDates.map((dateStr) {
        if (_loadingTabs.contains(dateStr)) {
          return const Center(child: CircularProgressIndicator());
        }
        final schedule = _raceSchedules[dateStr];
        if (schedule != null) {
          return RefreshIndicator(
            onRefresh: () => _fetchDataForDate(dateStr),
            child: _buildRaceScheduleView(schedule),
          );
        }
        return Center(
            child: Text(
              'データがありません。\n（画面を下に引っ張って更新）',
              textAlign: TextAlign.center,
            )
        );
      }).toList(),
    );
  }

  Widget _buildWeekNavigator() {
    final weekStart = _weekDates.first;
    final weekEnd = _weekDates.last;
    final formatter = DateFormat('M/d');

    // タブが利用可能かどうかを判定
    final bool canShowTabs = _isDataLoaded && _availableDates.isNotEmpty && _tabController != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _isLoading || _loadingTabs.isNotEmpty
                ? null
                : () => _calculateWeek(_currentDate.subtract(const Duration(days: 7))),
          ),
          Expanded( // 中央の要素が利用可能なスペースを全て使うように設定
            child: canShowTabs
                ? TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.blue.shade100,
              labelColor: Colors.blue, // Color for the selected tab's text
              unselectedLabelColor: Colors.black, // Color for unselected tabs' text
              tabs: _availableDates.map((dateStr) {
                final date = DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
                final dayOfWeek = _raceSchedules[dateStr]?.dayOfWeek ?? DateFormat.E('ja').format(date);
                return Tab(text: '${DateFormat('M/d').format(date)}($dayOfWeek)');
              }).toList(),
            )
                : Center( // データがない場合は週の範囲を表示
              child: Text(
                '${formatter.format(weekStart)} 〜 ${formatter.format(weekEnd)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _isLoading || _loadingTabs.isNotEmpty
                ? null
                : () => _calculateWeek(_currentDate.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceScheduleView(RaceSchedule schedule) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: schedule.venues.map((venue) {
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 8.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.grey[200],
                      child: Center(
                        child: Text(
                          venue.venueTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    ...venue.races.map((race) {
                      bool isRaceSet = race.raceId.isNotEmpty;
                      return InkWell(
                        onTap: isRaceSet
                            ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ShutubaTablePage(raceId: race.raceId),
                            ),
                          );
                        }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 4.0),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade300))),
                          child: Row(
                            children: [
                              Text(race.raceNumber,
                                  style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      race.raceName,
                                      style: TextStyle(
                                          color: isRaceSet
                                              ? Colors.black
                                              : Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isRaceSet && (race.grade.isNotEmpty || race.details.isNotEmpty))
                                      Text(
                                        '${race.grade} ${race.details}'.trim(),
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}