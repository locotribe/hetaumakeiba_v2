// lib/screens/race_schedule_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/services/race_schedule_scraper_service.dart';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';

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
  final Map<String, bool> _raceStatusMap = {};

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
      _isLoading = true;
      _loadingMessage = '開催日をチェック中...';
      _availableDates.clear();
      _raceSchedules.clear();
      _tabController?.removeListener(_handleTabSelection);
      _tabController?.dispose();
      _tabController = null;
    });

    _loadDataForWeek();
  }

  Future<void> _loadDataForWeek() async {
    if (!mounted) return;

    final representativeDate = _weekDates.last;
    final weekKey = DateFormat('yyyy-MM-dd').format(representativeDate);
    final cachedDateStrings = await _dbHelper.getWeekCache(weekKey);

    // Week Cacheが存在する場合の処理
    if (cachedDateStrings != null) {
      // cachedDateStrings（yyyyMMdd形式）をyyyy-MM-dd形式に変換
      final scheduleDateKeys = cachedDateStrings.map((ds) {
        try {
          final year = int.parse(ds.substring(0, 4));
          final month = int.parse(ds.substring(4, 6));
          final day = int.parse(ds.substring(6, 8));
          return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
        } catch (e) {
          return null;
        }
      }).where((d) => d != null).cast<String>().toList();

      // Week Cacheの日付リストを使ってDBからスケジュールを取得
      final schedulesFromDb = await _dbHelper.getMultipleRaceSchedules(scheduleDateKeys);

      if (schedulesFromDb.isNotEmpty) {
        schedulesFromDb.values.forEach(_checkRaceStatusesForSchedule);
      }

      if (mounted) {
        setState(() {
          _raceSchedules.addAll(schedulesFromDb);
          _isDataLoaded = true;
          _isLoading = false;
        });
        _setupTabs(cachedDateStrings);
      }
      return;
    }

    // Week Cacheが存在しない場合の処理 (これ以降は既存のロジックとほぼ同じ)
    final weekDateStrings = _weekDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    final schedulesFromDb = await _dbHelper.getMultipleRaceSchedules(weekDateStrings);
    if (schedulesFromDb.isNotEmpty) {
      schedulesFromDb.values.forEach(_checkRaceStatusesForSchedule);
      if(mounted) {
        setState(() {
          _raceSchedules.addAll(schedulesFromDb);
        });
      }
    }

    try {
      final (liveDateStrings, initialSchedule) = await _scraperService.fetchInitialData(representativeDate);

      if (liveDateStrings.isNotEmpty) {
        await _dbHelper.insertOrUpdateWeekCache(weekKey, liveDateStrings);
      }

      if (mounted) {
        _isDataLoaded = true;
        if (liveDateStrings.isEmpty && initialSchedule == null) {
          setState(() => _isLoading = false);
          return;
        }

        if (initialSchedule != null) {
          await _dbHelper.insertOrUpdateRaceSchedule(initialSchedule);
          setState(() {
            _raceSchedules[initialSchedule.date] = initialSchedule;
          });
          _checkRaceStatusesForSchedule(initialSchedule);
        }

        _setupTabs(liveDateStrings);
      }
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
    // 週の範囲でのフィルタリングを削除し、取得した日付をそのまま使用する
    if (yyyymmddStrings.isEmpty) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }

    _availableDates = yyyymmddStrings.map((ds) {
      try {
        final year = int.parse(ds.substring(0, 4));
        final month = int.parse(ds.substring(4, 6));
        final day = int.parse(ds.substring(6, 8));
        return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
      } catch (e) {
        return null;
      }
    }).where((d) => d != null).cast<String>().toList();

    // 日付順にソートする
    _availableDates.sort();

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

  Future<void> _fetchDataForDate(String dateString, {bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loadingTabs.add(dateString);
    });

    try {
      final date = DateFormat('yyyy-MM-dd', 'en_US').parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      RaceSchedule? schedule;

      if (forceRefresh) {
        schedule = await _scraperService.scrapeRaceSchedule(date);
      } else {
        // 通常の読み込みロジック
        if (date.isBefore(today)) {
          // 過去データはまずDBから試みる
          schedule = await _dbHelper.getRaceSchedule(dateString);
          // DBになければネットワークから取得する
          schedule ??= await _scraperService.scrapeRaceSchedule(date);
        } else {
          // 未来または今日の日付はネットワークから取得
          schedule = await _scraperService.scrapeRaceSchedule(date);
        }
      }

      // 取得に成功したデータはDBに保存・更新する
      if (schedule != null) {
        await _dbHelper.insertOrUpdateRaceSchedule(schedule);
        _checkRaceStatusesForSchedule(schedule);
      }

      if (mounted) {
        setState(() {
          _raceSchedules[dateString] = schedule;
        });
      }
    } catch (e) {
      print("Error fetching data for $dateString: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データ取得エラー: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTabs.remove(dateString);
        });
      }
    }
  }

  void _checkRaceStatusesForSchedule(RaceSchedule schedule) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final scheduleDate = DateFormat('yyyy-MM-dd', 'en_US').parse(schedule.date);

    if (scheduleDate.isAfter(startOfToday)) {
      return;
    }

    for (final venue in schedule.venues) {
      for (final race in venue.races) {
        if (_raceStatusMap.containsKey(race.raceId)) continue;

        RaceResultScraperService.isRaceResultConfirmed(race.raceId)
            .then((isConfirmed) {
          if (mounted) {
            setState(() {
              _raceStatusMap[race.raceId] = isConfirmed;
            });
          }
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
        onRefresh: _loadDataForWeek,
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

        final scheduleDate = DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final bool isPastPageWithData = scheduleDate.isBefore(today) && schedule != null;

        Widget content;
        if (schedule != null) {
          content = _buildRaceScheduleView(schedule);
        } else {
          content = LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const Center(
                  child: Text(
                    'データがありません。\n（画面を下に引っ張って更新）',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          });
        }

        if (isPastPageWithData) {
          return content;
        } else {
          return RefreshIndicator(
            onRefresh: () => _fetchDataForDate(dateStr, forceRefresh: true),
            child: content,
          );
        }
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
          Expanded(
            child: canShowTabs
                ? TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.blue.shade100,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.black,
              tabs: _availableDates.map((dateStr) {
                final date = DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
                final dayOfWeek = _raceSchedules[dateStr]?.dayOfWeek ?? DateFormat.E('ja').format(date);
                return Tab(text: '${DateFormat('M/d').format(date)}($dayOfWeek)');
              }).toList(),
            )
                : Center(
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
    final scheduleDate = DateFormat('yyyy-MM-dd', 'en_US').parse(schedule.date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bool isFutureOrToday = !scheduleDate.isBefore(today);
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView( // 垂直スクロールを管理
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: schedule.venues.map((venue) {
                      return Container(
                        width: 200,
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
                              final isConfirmed = _raceStatusMap[race.raceId] ?? false;
                              return InkWell(
                                onTap: isRaceSet
                                    ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RacePage(
                                            raceId: race.raceId,
                                            raceDate: schedule.date, // VenueScheduleから日付を渡す
                                          ),
                                    ),
                                  );
                                }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                                  decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(color: Colors.grey.shade300))),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 50,
                                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                                        decoration: BoxDecoration(
                                          color: isConfirmed ? Colors.redAccent : Colors.blueAccent,
                                          borderRadius: BorderRadius.circular(4.0),
                                        ),
                                        child: Center(
                                          child: Text(
                                            race.raceNumber,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    race.raceName,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: isRaceSet ? Colors.black : Colors.grey,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (isRaceSet && race.grade.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: getGradeColor(race.grade),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      race.grade,
                                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (isRaceSet && race.details.isNotEmpty)
                                              Text(
                                                race.details,
                                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (isFutureOrToday)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Text(
                      '画面を下に引いて最新情報に更新',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}