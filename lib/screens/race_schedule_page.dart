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
    // 矢印操作の基準となる日付は保持しておく
    _currentDate = DateTime.now();

    // ★修正: 初期ロード時は特定のURL（日付なし）から開始することを明示する
    _loadDataForWeek(isInitial: true);
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
      // 1. 渡された日付（日曜基準）をそのままセットする（月曜への強制変換を廃止）
      _currentDate = date;

      // 2. カレンダー表示用（月〜日）の計算はローカル変数で行う
      //    (Dartのweekdayは 月=1 ... 日=7)
      final int daysToSubtract = date.weekday - 1;
      final DateTime monday = date.subtract(Duration(days: daysToSubtract));

      // 3. 表示用の日付リストを生成
      _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));

      _isDataLoaded = false;
      _isLoading = true;
      _loadingMessage = '開催日をチェック中...';
      _availableDates.clear();
      _raceSchedules.clear();

      // タブコントローラーの破棄
      if (_tabController != null) {
        _tabController!.removeListener(_handleTabSelection);
        _tabController!.dispose();
        _tabController = null;
      }
      _raceStatusMap.clear();
    });

    // 4. データ読み込み開始（日付指定あり）
    _loadDataForWeek(isInitial: false);
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

  Future<void> _loadDataForWeek({bool isInitial = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingMessage = '開催スケジュールを確認中...';
        _raceSchedules.clear();
      });
    }

    try {
      // ★修正: キャッシュ優先ロジック
      // 初期ロード以外で、既に週構成(_weekDates)が決まっている場合はキャッシュを確認
      if (!isInitial && _weekDates.isNotEmpty) {
        // 週を一意に識別するキー（週の月曜日の日付文字列）を使用
        final weekKey = DateFormat('yyyyMMdd').format(_weekDates.first);
        final cachedDates = await _dbHelper.getWeekCache(weekKey);

        if (cachedDates != null && cachedDates.isNotEmpty) {
          // キャッシュヒット：スクレイピングせずにUI構築へ
          _setupTabs(cachedDates);
          if (mounted) {
            setState(() {
              _isDataLoaded = true;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // ★修正: キャッシュがない、または初期ロードの場合はスクレイピング
      final (dates, schedule) = await _scraperService.fetchInitialData(
        isInitial ? null : _currentDate,
        onProgress: (msg) {
          if (mounted) setState(() => _loadingMessage = msg);
        },
      );

      // データなし（未来の週など）
      if (dates.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _availableDates = [];
            _isDataLoaded = true; // ロード完了とするがデータなし
          });
        }
        return;
      }

      _setupTabs(dates);

      // ★追加: 取得した週データをキャッシュに保存
      if (_weekDates.isNotEmpty) {
        final weekKey = DateFormat('yyyyMMdd').format(_weekDates.first);
        await _dbHelper.insertOrUpdateWeekCache(weekKey, dates);
      }

      if (schedule != null) {
        _raceSchedules[schedule.date] = schedule;
        await _dbHelper.insertOrUpdateRaceSchedule(schedule);
      }

      if (mounted) {
        setState(() {
          _isDataLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadDataForWeek: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'データの取得に失敗しました';
        });
      }
    }
  }

  void _setupTabs(List<String> yyyymmddStrings) {
    if (yyyymmddStrings.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    var parsedDates = yyyymmddStrings
        .map((ds) {
      try {
        final year = int.parse(ds.substring(0, 4));
        final month = int.parse(ds.substring(4, 6));
        final day = int.parse(ds.substring(6, 8));
        return DateTime(year, month, day);
      } catch (e) {
        return null;
      }
    })
        .where((d) => d != null)
        .cast<DateTime>()
        .toList();

    if (parsedDates.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    parsedDates.sort();

    _availableDates = parsedDates
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toList();

    // ★修正: 基準日(_currentDate)の正規化
    // 取得した日付リストの最後の日（日曜、あるいは変則開催の最終日）を基準に、
    // 強制的に「その週の日曜日」まで補正して_currentDateとする。
    if (parsedDates.isNotEmpty) {
      final lastDate = parsedDates.last;

      // 日曜日(7)までの差分を足す（火曜(2)なら+5日、日曜(7)なら+0日）
      final int daysToAdd = DateTime.sunday - lastDate.weekday;
      final DateTime targetSunday = lastDate.add(Duration(days: daysToAdd));

      _currentDate = targetSunday;

      // カレンダー表示用の月曜日（日曜から6日前）
      final DateTime monday = _currentDate.subtract(const Duration(days: 6));
      _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
    }

    int initialIndex = _availableDates
        .indexOf(DateFormat('yyyy-MM-dd').format(parsedDates.last));

    if (initialIndex == -1) {
      initialIndex = _availableDates.isNotEmpty ? _availableDates.length - 1 : 0;
    }

    if (_tabController != null) {
      _tabController!.dispose();
    }

    _tabController = TabController(
      initialIndex: initialIndex,
      length: _availableDates.length,
      vsync: this,
    );
    _tabController?.addListener(_handleTabSelection);
    _handleTabSelection();
  }

  void _handleTabSelection() {
    if (_tabController == null) return;

    // タブ切り替えアニメーション中は発火させない（完了時のみ処理）
    if (_tabController!.indexIsChanging) return;

    final index = _tabController!.index;
    if (index < 0 || index >= _availableDates.length) return;

    final dateStr = _availableDates[index];

    // まだデータを持っていない日付の場合のみ取得しに行く
    if (!_raceSchedules.containsKey(dateStr)) {
      _fetchDataForDate(dateStr);
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
      RaceSchedule? schedule;

      // ★修正: 未来・過去に関わらず、プルダウン更新でなければDBを優先する
      if (forceRefresh) {
        // プルダウン更新（forceRefresh = true）の時は、強制的にWebから取得
        schedule = await _scraperService.scrapeRaceSchedule(date);
      } else {
        // 通常アクセス時: まずDBを確認
        schedule = await _dbHelper.getRaceSchedule(dateString);

        // DBになければ（初アクセスなら）Webから取得
        schedule ??= await _scraperService.scrapeRaceSchedule(date);
      }

      if (schedule != null) {
        // データを取得できたら（DB/Web問わず）状態を初期化し、DBに保存（更新）する
        _initializeStatusMapFromSchedule(schedule);
        await _dbHelper.insertOrUpdateRaceSchedule(schedule);

        // 補足: 表示データの更新とは別に、レースの発走時刻や確定状況のチェックは行う
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