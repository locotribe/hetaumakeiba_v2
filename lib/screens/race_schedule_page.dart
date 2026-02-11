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
  final RaceScheduleScraperService _scraperService =
  RaceScheduleScraperService();
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
      _raceStatusMap.clear(); // ステータスマップもクリア
    });

    _loadDataForWeek();
  }

  /// スケジュールデータから初期ステータス（確定済みかどうか）を読み込む
  void _initializeStatusMapFromSchedule(RaceSchedule schedule) {
    for (final venue in schedule.venues) {
      for (final race in venue.races) {
        // DBに保存されていた情報で「確定済み」ならマップに反映
        if (race.isConfirmed) {
          _raceStatusMap[race.raceId] = true;
        }
      }
    }
  }

  Future<void> _loadDataForWeek() async {
    if (!mounted) return;

    final representativeDate = _weekDates.last;
    final weekKey = DateFormat('yyyy-MM-dd').format(representativeDate);
    final cachedDateStrings = await _dbHelper.getWeekCache(weekKey);

    // Week Cacheが存在する場合の処理
    if (cachedDateStrings != null) {
      final scheduleDateKeys = cachedDateStrings
          .map((ds) {
        try {
          final year = int.parse(ds.substring(0, 4));
          final month = int.parse(ds.substring(4, 6));
          final day = int.parse(ds.substring(6, 8));
          return DateFormat('yyyy-MM-dd')
              .format(DateTime(year, month, day));
        } catch (e) {
          return null;
        }
      })
          .where((d) => d != null)
          .cast<String>()
          .toList();

      final schedulesFromDb =
      await _dbHelper.getMultipleRaceSchedules(scheduleDateKeys);

      if (schedulesFromDb.isNotEmpty) {
        // DBから読み込んだ時点で確定情報を反映させる
        schedulesFromDb.values.forEach(_initializeStatusMapFromSchedule);

        // その後、未確定のものだけチェックに行く
        schedulesFromDb.values.forEach((s) => _checkRaceStatusesForSchedule(s));
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

    // Week Cacheが存在しない場合の処理
    final weekDateStrings =
    _weekDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    final schedulesFromDb =
    await _dbHelper.getMultipleRaceSchedules(weekDateStrings);
    if (schedulesFromDb.isNotEmpty) {
      schedulesFromDb.values.forEach(_initializeStatusMapFromSchedule);
      schedulesFromDb.values.forEach((s) => _checkRaceStatusesForSchedule(s));
      if (mounted) {
        setState(() {
          _raceSchedules.addAll(schedulesFromDb);
        });
      }
    }

    try {
      final (liveDateStrings, initialSchedule) =
      await _scraperService.fetchInitialData(representativeDate);

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
          // 初期ロード時も確定情報を反映
          _initializeStatusMapFromSchedule(initialSchedule);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('データ取得エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupTabs(List<String> yyyymmddStrings) {
    if (yyyymmddStrings.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _availableDates = yyyymmddStrings
        .map((ds) {
      try {
        final year = int.parse(ds.substring(0, 4));
        final month = int.parse(ds.substring(4, 6));
        final day = int.parse(ds.substring(6, 8));
        return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
      } catch (e) {
        return null;
      }
    })
        .where((d) => d != null)
        .cast<String>()
        .toList();

    _availableDates.sort();

    int initialIndex = _availableDates
        .indexOf(DateFormat('yyyy-MM-dd').format(_weekDates.last));
    if (initialIndex == -1)
      initialIndex =
      _availableDates.isNotEmpty ? _availableDates.length - 1 : 0;

    _tabController = TabController(
      initialIndex: initialIndex,
      length: _availableDates.length,
      vsync: this,
    );
    _tabController?.addListener(_handleTabSelection);
    _handleTabSelection();
  }

  void _handleTabSelection() {
    if (!mounted || _tabController == null || _tabController!.indexIsChanging)
      return;

    final selectedDate = _availableDates[_tabController!.index];
    if (!_raceSchedules.containsKey(selectedDate) &&
        !_loadingTabs.contains(selectedDate)) {
      _fetchDataForDate(selectedDate);
    }
  }

  Future<void> _fetchDataForDate(String dateString,
      {bool forceRefresh = false}) async {
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
        if (date.isBefore(today)) {
          schedule = await _dbHelper.getRaceSchedule(dateString);
          schedule ??= await _scraperService.scrapeRaceSchedule(date);
        } else {
          schedule = await _scraperService.scrapeRaceSchedule(date);
        }
      }

      if (schedule != null) {
        // ロード時に確定情報を復元
        _initializeStatusMapFromSchedule(schedule);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('データ取得エラー: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTabs.remove(dateString);
        });
      }
    }
  }

  Future<void> _checkRaceStatusesForSchedule(RaceSchedule schedule) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final scheduleDateStr = schedule.date;

    if (scheduleDateStr.compareTo(todayStr) > 0) {
      return;
    }

    final scheduleDate = DateFormat('yyyy-MM-dd').parse(scheduleDateStr);
    final isPastDate = scheduleDate.isBefore(DateTime(now.year, now.month, now.day));
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');

    for (final venue in schedule.venues) {
      for (final race in venue.races) {
        if (!mounted) return;

        // 1. 既に確定している（DBまたはメモリ上で確認済み）場合はスキップ
        // これにより、再起動後もDBから読まれた isConfirmed=true があれば通信しません
        if (_raceStatusMap[race.raceId] == true) continue;

        // 2. 発走時刻チェック
        if (!isPastDate) {
          final match = timeRegex.firstMatch(race.details);
          if (match != null) {
            final hour = int.parse(match.group(1)!);
            final minute = int.parse(match.group(2)!);
            final raceTime = DateTime(now.year, now.month, now.day, hour, minute);

            if (now.isBefore(raceTime)) {
              continue;
            }
          }
        }

        // 3. アクセス制限回避のための遅延
        await Future.delayed(const Duration(milliseconds: 1000));

        if (!mounted) return;

        try {
          final isConfirmed =
          await RaceResultScraperService.isRaceResultConfirmed(race.raceId);

          if (mounted && isConfirmed) {
            setState(() {
              _raceStatusMap[race.raceId] = true;
            });

            // ★重要: 確定したらデータを更新してDBに保存する
            race.isConfirmed = true;
            await _dbHelper.insertOrUpdateRaceSchedule(schedule);
          }
        } catch (e) {
          print('Error checking status for ${race.raceId}: $e');
        }
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
        final bool isPastPageWithData =
            scheduleDate.isBefore(today) && schedule != null;

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

    final bool canShowTabs =
        _isDataLoaded && _availableDates.isNotEmpty && _tabController != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _isLoading || _loadingTabs.isNotEmpty
                ? null
                : () => _calculateWeek(
                _currentDate.subtract(const Duration(days: 7))),
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
                final date =
                DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
                final dayOfWeek = _raceSchedules[dateStr]?.dayOfWeek ??
                    DateFormat.E('ja').format(date);
                return Tab(
                    text:
                    '${DateFormat('M/d').format(date)}($dayOfWeek)');
              }).toList(),
            )
                : Center(
              child: Text(
                '${formatter.format(weekStart)} 〜 ${formatter.format(weekEnd)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _isLoading || _loadingTabs.isNotEmpty
                ? null
                : () =>
                _calculateWeek(_currentDate.add(const Duration(days: 7))),
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
      return SingleChildScrollView(
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            ...venue.races.map((race) {
                              bool isRaceSet = race.raceId.isNotEmpty;
                              final isConfirmed =
                                  _raceStatusMap[race.raceId] ?? false;
                              return InkWell(
                                onTap: isRaceSet
                                    ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RacePage(
                                        raceId: race.raceId,
                                        raceDate: schedule.date,
                                      ),
                                    ),
                                  );
                                }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade300))),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 40,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        decoration: BoxDecoration(
                                          color: isConfirmed
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                          borderRadius:
                                          BorderRadius.circular(4.0),
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
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    race.raceName,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: isRaceSet
                                                          ? Colors.black
                                                          : Colors.grey,
                                                    ),
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (isRaceSet &&
                                                    race.grade.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: getGradeColor(
                                                          race.grade),
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                    ),
                                                    child: Text(
                                                      race.grade,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight:
                                                          FontWeight.bold),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (isRaceSet &&
                                                race.details.isNotEmpty)
                                              Text(
                                                race.details,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87),
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