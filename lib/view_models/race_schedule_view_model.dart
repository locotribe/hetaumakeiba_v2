// lib/view_models/race_schedule_view_model.dart

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_schedule_repository.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/services/jyusyo_matching_service.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/race_schedule_scraper_service.dart';
import 'package:intl/intl.dart';

/// 開催スケジュール画面のUIロジックとビジネスロジックを分離するためのViewModel
class RaceScheduleViewModel extends ChangeNotifier {
  final RaceScheduleScraperService _scraperService = RaceScheduleScraperService();
  final RaceScheduleRepository _raceScheduleRepository = RaceScheduleRepository();
  final JyusyoMatchingService _jyusyoService = JyusyoMatchingService();

  bool _disposed = false;

  bool isLoading = false;
  bool isDataLoaded = false;
  String loadingMessage = '';
  DateTime currentDate = DateTime.now();
  List<DateTime> weekDates = [];

  final Map<String, RaceSchedule?> raceSchedules = {};
  List<String> availableDates = [];
  final Set<String> loadingTabs = {};
  final Map<String, bool> raceStatusMap = {};

  int initialTabIndex = 0;

  String? tabErrorMessage;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void clearTabError() {
    tabErrorMessage = null;
  }

  // 初期データ読み込み
  Future<void> loadInitialData() async {
    currentDate = DateTime.now();
    await loadDataForWeek(isInitial: true);
  }

  // 週送り（前週/翌週）に伴うデータ再読み込み
  void calculateWeek(DateTime date) {
    currentDate = date;
    final int daysToSubtract = date.weekday - 1;
    final DateTime monday = date.subtract(Duration(days: daysToSubtract));
    weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));

    isDataLoaded = false;
    isLoading = true;
    loadingMessage = '開催日をチェック中...';
    availableDates = [];
    raceSchedules.clear();
    raceStatusMap.clear();
    notifyListeners();

    loadDataForWeek(isInitial: false);
  }

  void _initializeStatusMapFromSchedule(RaceSchedule schedule) {
    for (final venue in schedule.venues) {
      for (final race in venue.races) {
        if (race.isConfirmed) {
          raceStatusMap[race.raceId] = true;
        }
      }
    }
  }

  Future<void> loadDataForWeek({bool isInitial = false}) async {
    isLoading = true;
    loadingMessage = '開催スケジュールを確認中...';
    raceSchedules.clear();
    notifyListeners();

    // [修正] 週送り時に表示したい日付と週キャッシュのキーを、_setupTabsで上書きされる前に確保する (v.2026.9.22+26092209)
    final DateTime? focusDate = isInitial ? null : currentDate;
    final String? requestedWeekKey = (!isInitial && weekDates.isNotEmpty)
        ? DateFormat('yyyyMMdd').format(weekDates.first)
        : null;

    try {
      if (requestedWeekKey != null) {
        final cachedDates =
            await _raceScheduleRepository.getWeekCache(requestedWeekKey);

        if (cachedDates != null && cachedDates.isNotEmpty) {
          _setupTabs(cachedDates, focusDate: focusDate);
          isDataLoaded = true;
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      final (dates, schedule) = await _scraperService.fetchInitialData(
        isInitial ? null : currentDate,
        onProgress: (msg) {
          loadingMessage = msg;
          notifyListeners();
        },
      );

      if (dates.isEmpty) {
        isLoading = false;
        availableDates = [];
        isDataLoaded = true;
        notifyListeners();
        return;
      }

      _setupTabs(dates, focusDate: focusDate);

      // [修正] 週送り時は表示を要求した週のキーで保存する（初期表示時は従来どおり最新週のキー） (v.2026.9.22+26092209)
      final String? weekKey = requestedWeekKey ??
          (weekDates.isNotEmpty
              ? DateFormat('yyyyMMdd').format(weekDates.first)
              : null);
      if (weekKey != null) {
        await _raceScheduleRepository.insertOrUpdateWeekCache(weekKey, dates);
      }

      // 初期ロード時のスケジュール保存も mergeRaceSchedule を使い
      // 既存の isConfirmed を引き継ぐ
      if (schedule != null) {
        await _raceScheduleRepository.mergeRaceSchedule(schedule);
        final merged = await _raceScheduleRepository.getRaceSchedule(schedule.date);
        if (merged != null) {
          _initializeStatusMapFromSchedule(merged);
          raceSchedules[merged.date] = merged;
        } else {
          raceSchedules[schedule.date] = schedule;
        }
      }

      isDataLoaded = true;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      loadingMessage = 'データの取得に失敗しました';
      notifyListeners();
    }
  }

  // [修正] focusDateを受け取り、週送り時は表示中の週を最新週で上書きしないようにする (v.2026.9.22+26092209)
  void _setupTabs(List<String> yyyymmddStrings, {DateTime? focusDate}) {
    if (yyyymmddStrings.isEmpty) {
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
      return;
    }

    parsedDates.sort();

    availableDates =
        parsedDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

    if (focusDate == null && parsedDates.isNotEmpty) {
      final lastDate = parsedDates.last;
      final int daysToAdd = DateTime.sunday - lastDate.weekday;
      final DateTime targetSunday = lastDate.add(Duration(days: daysToAdd));

      currentDate = targetSunday;
      final DateTime monday = currentDate.subtract(const Duration(days: 6));
      weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
    }

    // 「今日」または「今日以降で最も近い日」を初期タブにする
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int initialIndex = -1;

    // [追加] 週送り時、表示中の週に今日が含まれなければ、その週の開催日（なければ最も近い日）を初期タブにする (v.2026.9.22+26092209)
    if (focusDate != null) {
      final focusDay = DateTime(focusDate.year, focusDate.month, focusDate.day);
      final weekStart =
          focusDay.subtract(Duration(days: focusDay.weekday - DateTime.monday));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final bool isTodayInWeek =
          !today.isBefore(weekStart) && !today.isAfter(weekEnd);

      if (!isTodayInWeek) {
        int bestIndex = -1;
        int bestDiff = 1 << 30;
        for (int i = 0; i < parsedDates.length; i++) {
          final date = parsedDates[i];
          if (!date.isBefore(weekStart) && !date.isAfter(weekEnd)) {
            bestIndex = i;
            break;
          }
          final diff = date.isBefore(weekStart)
              ? weekStart.difference(date).inDays
              : date.difference(weekEnd).inDays;
          if (diff < bestDiff) {
            bestDiff = diff;
            bestIndex = i;
          }
        }
        initialTabIndex = bestIndex < 0 ? 0 : bestIndex;
        return;
      }
    }

    for (int i = 0; i < availableDates.length; i++) {
      final date = DateFormat('yyyy-MM-dd').parse(availableDates[i]);
      if (date.isAtSameMomentAs(today) || date.isAfter(today)) {
        initialIndex = i;
        break;
      }
    }

    // 全て過去の日付だった場合は、一番新しい日（リストの最後）を選択
    if (initialIndex == -1) {
      initialIndex = availableDates.length - 1;
    }

    initialTabIndex = initialIndex;
  }

  void ensureDataForDate(String dateStr) {
    if (!raceSchedules.containsKey(dateStr)) {
      fetchDataForDate(dateStr);
    }
  }

  Future<void> fetchDataForDate(String dateString, {bool forceRefresh = false}) async {
    loadingTabs.add(dateString);
    notifyListeners();

    try {
      final date = DateFormat('yyyy-MM-dd', 'en_US').parse(dateString);
      RaceSchedule? schedule;

      if (forceRefresh) {
        // スクレイピング結果を mergeRaceSchedule で isConfirmed を
        // 引き継いでから保存し、DBから読み直して確定版を使う
        final scraped = await _scraperService.scrapeRaceSchedule(date);
        if (scraped != null) {
          await _raceScheduleRepository.mergeRaceSchedule(scraped);
          schedule = await _raceScheduleRepository.getRaceSchedule(dateString);
        }
      } else {
        schedule = await _raceScheduleRepository.getRaceSchedule(dateString);

        if (schedule != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (date.isBefore(today)) {
            bool isIncomplete = false;
            for (final venue in schedule.venues) {
              if (venue.races.length <= 5) {
                isIncomplete = true;
                break;
              }
            }
            if (isIncomplete) {
              // 不完全なキャッシュの補完時も mergeRaceSchedule を使う
              final scraped = await _scraperService.scrapeRaceSchedule(date);
              if (scraped != null) {
                await _raceScheduleRepository.mergeRaceSchedule(scraped);
                schedule = await _raceScheduleRepository.getRaceSchedule(dateString);
              }
            }
          }
        }

        if (schedule == null) {
          // 新規取得時も mergeRaceSchedule 経由で保存する
          final scraped = await _scraperService.scrapeRaceSchedule(date);
          if (scraped != null) {
            await _raceScheduleRepository.mergeRaceSchedule(scraped);
            schedule = await _raceScheduleRepository.getRaceSchedule(dateString);
          }
        }
      }

      if (schedule != null) {
        // DBから読み直したオブジェクトで isConfirmed を反映してから
        // 画面を先に更新し、その後ステータス確認を非同期で走らせる
        _initializeStatusMapFromSchedule(schedule);
        await _jyusyoService.reflectScheduleDataToJyusyoRaces(schedule);

        raceSchedules[dateString] = schedule;
        loadingTabs.remove(dateString);
        notifyListeners();

        // ステータス確認完了後にDBと画面を再同期する
        _checkRaceStatusesForSchedule(schedule).then((_) async {
          if (_disposed) return;
          final updated = await _raceScheduleRepository.getRaceSchedule(dateString);
          if (!_disposed && updated != null) {
            _initializeStatusMapFromSchedule(updated);
            raceSchedules[dateString] = updated;
            notifyListeners();
          }
        });
      } else {
        raceSchedules[dateString] = null;
        loadingTabs.remove(dateString);
        notifyListeners();
      }
    } catch (e) {
      tabErrorMessage = 'データ取得エラー: $e';
      loadingTabs.remove(dateString);
      notifyListeners();
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
    final isPastDate =
    scheduleDate.isBefore(DateTime(now.year, now.month, now.day));
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');

    bool needUpdateDb = false;

    for (final venue in schedule.venues) {
      for (final race in venue.races) {
        if (_disposed) return;

        // _raceStatusMap だけでなく race.isConfirmed も確認して
        // 確認済みレースの二重チェックを防ぐ
        if (raceStatusMap[race.raceId] == true || race.isConfirmed) continue;

        if (isPastDate) {
          raceStatusMap[race.raceId] = true;
          notifyListeners();
          race.isConfirmed = true;
          needUpdateDb = true;
          continue;
        }

        if (!isPastDate) {
          final match = timeRegex.firstMatch(race.details);
          if (match != null) {
            final hour = int.parse(match.group(1)!);
            final minute = int.parse(match.group(2)!);
            final raceTime =
            DateTime(now.year, now.month, now.day, hour, minute);
            if (now.isBefore(raceTime)) {
              continue;
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 1000));

        if (_disposed) return;

        try {
          final isConfirmed =
          await RaceResultScraperService.isRaceResultConfirmed(race.raceId);

          if (isConfirmed) {
            race.isConfirmed = true;
            needUpdateDb = true;
            raceStatusMap[race.raceId] = true;
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error checking status for ${race.raceId}: $e');
        }
      }
    }

    // isConfirmed 更新後は schedule オブジェクトが正しい状態なので
    // insertOrUpdateRaceSchedule でそのまま保存する
    if (needUpdateDb) {
      await _raceScheduleRepository.insertOrUpdateRaceSchedule(schedule);
    }
  }
}
