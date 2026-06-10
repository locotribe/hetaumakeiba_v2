// lib/screens/race_schedule_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
// [追加] 状態管理・ビジネスロジックをViewModelへ分離 (v.13.41.0)
import 'package:hetaumakeiba_v2/view_models/race_schedule_view_model.dart';

class RaceSchedulePage extends StatefulWidget {
  const RaceSchedulePage({super.key});

  @override
  RaceSchedulePageState createState() => RaceSchedulePageState();
}

class RaceSchedulePageState extends State<RaceSchedulePage>
    with TickerProviderStateMixin {
  // [修正] データ取得・加工ロジックをRaceScheduleViewModelへ移行 (v.13.41.0)
  late final RaceScheduleViewModel _viewModel;

  // TabControllerはvsync(TickerProviderStateMixin)が必要なためView側で保持・管理する
  TabController? _tabController;
  List<String> _syncedAvailableDates = [];

  @override
  void initState() {
    super.initState();
    // [追加] ViewModelを生成し、画面の状態管理を委譲する (v.13.41.0)
    _viewModel = RaceScheduleViewModel();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadInitialData();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    // [追加] ViewModelのリスナー解除と破棄を追加 (v.13.41.0)
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  // [追加] ViewModelのnotifyListeners()を受けて再描画し、必要であればTabControllerを再構築する (v.13.41.0)
  void _onViewModelUpdate() {
    final error = _viewModel.tabErrorMessage;
    if (error != null) {
      _viewModel.clearTabError();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }

    if (!mounted) return;

    final tabsChanged =
        !listEquals(_viewModel.availableDates, _syncedAvailableDates);

    setState(() {
      if (tabsChanged) {
        _syncTabController();
      }
    });

    if (tabsChanged) {
      _handleTabSelection();
    }
  }

  // [追加] availableDatesの変化に合わせてTabControllerを作り直す（旧_setupTabsのTabController生成部分） (v.13.41.0)
  void _syncTabController() {
    final dates = _viewModel.availableDates;
    _syncedAvailableDates = List.from(dates);

    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();

    if (dates.isEmpty) {
      _tabController = null;
      return;
    }

    _tabController = TabController(
      initialIndex: _viewModel.initialTabIndex,
      length: dates.length,
      vsync: this,
    );
    _tabController!.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    final tabController = _tabController;
    if (tabController == null) return;
    if (tabController.indexIsChanging) return;

    final dates = _viewModel.availableDates;
    final index = tabController.index;
    if (index < 0 || index >= dates.length) return;

    // [修正] データ未取得日の判定・取得トリガーをViewModelへ委譲 (v.13.41.0)
    _viewModel.ensureDataForDate(dates[index]);
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
    if (_viewModel.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_viewModel.loadingMessage),
          ],
        ),
      );
    }

    if (!_viewModel.isDataLoaded) {
      return const Center(
        child: Text(
          '開催情報を読み込みます',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (_viewModel.availableDates.isEmpty) {
      return RefreshIndicator(
        // [修正] ViewModel.loadDataForWeek()を呼び出すよう変更 (v.13.41.0)
        onRefresh: () => _viewModel.loadDataForWeek(),
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
      children: _viewModel.availableDates.map((dateStr) {
        if (_viewModel.loadingTabs.contains(dateStr)) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedule = _viewModel.raceSchedules[dateStr];

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

        // isPastPageWithData の分岐を廃止し、
        // 過去日付でも常に RefreshIndicator で包む
        // （当日中に結果確定が走るため必要）
        return RefreshIndicator(
          // [修正] ViewModel.fetchDataForDate()を呼び出すよう変更 (v.13.41.0)
          onRefresh: () => _viewModel.fetchDataForDate(dateStr, forceRefresh: true),
          child: content,
        );
      }).toList(),
    );
  }

  Widget _buildWeekNavigator() {
    final formatter = DateFormat('M/d');

    final bool canShowTabs = _viewModel.isDataLoaded &&
        _viewModel.availableDates.isNotEmpty &&
        _tabController != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            // [修正] ViewModel.calculateWeek()を呼び出すよう変更 (v.13.41.0)
            onPressed: _viewModel.isLoading || _viewModel.loadingTabs.isNotEmpty
                ? null
                : () => _viewModel.calculateWeek(
                _viewModel.currentDate.subtract(const Duration(days: 7))),
          ),
          Expanded(
            child: canShowTabs
                ? TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.blue.shade100,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.black,
              tabs: _viewModel.availableDates.map((dateStr) {
                final date =
                DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
                final dayOfWeek = DateFormat.E('ja').format(date);
                return Tab(
                    text: '${DateFormat('M/d').format(date)}($dayOfWeek)');
              }).toList(),
            )
                : Center(
              child: _viewModel.weekDates.isNotEmpty
                  ? Text(
                '${formatter.format(_viewModel.weekDates.first)} 〜 ${formatter.format(_viewModel.weekDates.last)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              )
                  : const Text(
                '読み込み中...',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            // [修正] ViewModel.calculateWeek()を呼び出すよう変更 (v.13.41.0)
            onPressed: _viewModel.isLoading || _viewModel.loadingTabs.isNotEmpty
                ? null
                : () => _viewModel.calculateWeek(
                _viewModel.currentDate.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceScheduleView(RaceSchedule schedule) {
    final scheduleDate =
    DateFormat('yyyy-MM-dd', 'en_US').parse(schedule.date);
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
                Container(
                  width: double.infinity,
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
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
                                // [修正] ViewModel.raceStatusMapを参照するよう変更 (v.13.41.0)
                                final isConfirmed =
                                    _viewModel.raceStatusMap[race.raceId] ?? false;
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
                                                color:
                                                Colors.grey.shade300))),
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
                                                        BorderRadius
                                                            .circular(8),
                                                      ),
                                                      child: Text(
                                                        race.grade,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.white,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold),
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
                                                  overflow:
                                                  TextOverflow.ellipsis,
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
                ),
                // 当日・未来のみ「引いて更新」のヒントを表示
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
