// lib/services/past_race_horse_fetch_service.dart

// [追加] 全出走馬の取得と読み込み Step1: 過去レースの全出走馬の戦績（競走馬の成績ページ1枚）と血統（血統ページ1枚）を、無い分だけ取る。
// アプリが開いている間は画面を閉じても続け、進み具合は progress で共有する。取得済みの馬は飛ばすので、止まっても次に押せば続きから取る (v.2026.10.16+26101608)

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_profile_scraper_service.dart';

/// 取得の進み具合。
class PastRaceHorseFetchProgress {
  /// 取得を始めたレース（予想するレース）のID。何も始めていないときは空。
  final String raceId;

  /// 取得中か。
  final bool isRunning;

  /// 処理し終えた馬の数。
  final int doneHorses;

  /// 取る物がある馬の数（取得を始めたときの数）。
  final int totalHorses;

  /// 戦績か血統の取得に失敗した馬の数。
  final int failedHorses;

  const PastRaceHorseFetchProgress({
    required this.raceId,
    required this.isRunning,
    required this.doneHorses,
    required this.totalHorses,
    required this.failedHorses,
  });

  static const idle = PastRaceHorseFetchProgress(
    raceId: '',
    isRunning: false,
    doneHorses: 0,
    totalHorses: 0,
    failedHorses: 0,
  );

  /// [raceId] のレースの取得中か。
  bool isRunningFor(String raceId) => isRunning && this.raceId == raceId;
}

typedef PastRaceHorsePlanLoader = Future<PastRaceHorseFetchPlan> Function(
    List<String> pastRaceIds);
typedef PastRaceHorsePerformanceFetcher = Future<bool> Function(
    String horseId);
typedef PastRaceHorsePedigreeFetcher = Future<bool> Function(
    String horseId, String horseName);

class PastRaceHorseFetchService {
  /// アプリ全体で1つだけ使う。
  static final PastRaceHorseFetchService instance = PastRaceHorseFetchService._(
    planLoader: _defaultLoadPlan,
    performanceFetcher: _defaultFetchPerformance,
    pedigreeFetcher: _defaultFetchPedigree,
    waitBetweenPages: const Duration(milliseconds: 1000),
  );

  PastRaceHorseFetchService._({
    required PastRaceHorsePlanLoader planLoader,
    required PastRaceHorsePerformanceFetcher performanceFetcher,
    required PastRaceHorsePedigreeFetcher pedigreeFetcher,
    required this.waitBetweenPages,
  })  : _planLoader = planLoader,
        _performanceFetcher = performanceFetcher,
        _pedigreeFetcher = pedigreeFetcher;

  /// テスト用。DBとネットの代わりに渡した関数を使う。
  @visibleForTesting
  PastRaceHorseFetchService.forTest({
    required PastRaceHorsePlanLoader planLoader,
    required PastRaceHorsePerformanceFetcher performanceFetcher,
    required PastRaceHorsePedigreeFetcher pedigreeFetcher,
    this.waitBetweenPages = Duration.zero,
  })  : _planLoader = planLoader,
        _performanceFetcher = performanceFetcher,
        _pedigreeFetcher = pedigreeFetcher;

  final PastRaceHorsePlanLoader _planLoader;
  final PastRaceHorsePerformanceFetcher _performanceFetcher;
  final PastRaceHorsePedigreeFetcher _pedigreeFetcher;

  /// 1ページ取るごとに待つ時間（サーバーの負荷を減らすため）。
  final Duration waitBetweenPages;

  /// 進み具合。画面はこれを見て表示を変える。
  final ValueNotifier<PastRaceHorseFetchProgress> progress =
      ValueNotifier<PastRaceHorseFetchProgress>(PastRaceHorseFetchProgress.idle);

  Future<void>? _running;

  /// 実行中の取得（テストで終わるのを待つ用）。
  @visibleForTesting
  Future<void>? get running => _running;

  /// 取る必要がある戦績・血統を数える（取得はしない）。
  Future<PastRaceHorseFetchPlan> loadPlan(List<String> pastRaceIds) =>
      _planLoader(pastRaceIds);

  /// [raceId] のレースについて、過去レース [pastRaceIds] の全出走馬の取得を始める。
  ///
  /// 取得は待たずに戻る。同じレースを取得中なら何もせず true、
  /// 別のレースを取得中なら何もせず false を返す。
  bool start({required String raceId, required List<String> pastRaceIds}) {
    final current = progress.value;
    if (current.isRunning) return current.raceId == raceId;
    progress.value = PastRaceHorseFetchProgress(
      raceId: raceId,
      isRunning: true,
      doneHorses: 0,
      totalHorses: 0,
      failedHorses: 0,
    );
    _running = _run(raceId, List<String>.of(pastRaceIds));
    return true;
  }

  Future<void> _run(String raceId, List<String> pastRaceIds) async {
    int done = 0;
    int total = 0;
    int failed = 0;
    try {
      final plan = await _planLoader(pastRaceIds);
      final targets = plan.horseIdsToFetch;
      total = targets.length;
      progress.value = PastRaceHorseFetchProgress(
        raceId: raceId,
        isRunning: true,
        doneHorses: 0,
        totalHorses: total,
        failedHorses: 0,
      );
      for (final horseId in targets) {
        bool ok = true;
        if (plan.performanceHorseIds.contains(horseId)) {
          final fetched = await _safely(() => _performanceFetcher(horseId));
          ok = ok && fetched;
          await _wait();
        }
        if (plan.pedigreeHorseIds.contains(horseId)) {
          final fetched = await _safely(
              () => _pedigreeFetcher(horseId, plan.horseNames[horseId] ?? ''));
          ok = ok && fetched;
          await _wait();
        }
        done++;
        if (!ok) failed++;
        progress.value = PastRaceHorseFetchProgress(
          raceId: raceId,
          isRunning: true,
          doneHorses: done,
          totalHorses: total,
          failedHorses: failed,
        );
      }
    } catch (e) {
      debugPrint('PastRaceHorseFetchService: 取得を途中で止めました: $e');
    } finally {
      progress.value = PastRaceHorseFetchProgress(
        raceId: raceId,
        isRunning: false,
        doneHorses: done,
        totalHorses: total,
        failedHorses: failed,
      );
    }
  }

  Future<bool> _safely(Future<bool> Function() fetch) async {
    try {
      return await fetch();
    } catch (e) {
      debugPrint('PastRaceHorseFetchService: 1頭の取得に失敗しました: $e');
      return false;
    }
  }

  Future<void> _wait() async {
    if (waitBetweenPages > Duration.zero) {
      await Future.delayed(waitBetweenPages);
    }
  }

  static Future<PastRaceHorseFetchPlan> _defaultLoadPlan(
      List<String> pastRaceIds) async {
    final raceRepo = RaceRepository();
    final horseRepo = HorseRepository();
    final resultsMap = await raceRepo.getMultipleRaceResults(pastRaceIds);
    final pastRaces = resultsMap.values.toList();
    final Map<String, List<HorseRaceRecord>> recordsByHorse = {};
    final Map<String, HorseProfile?> profileByHorse = {};
    for (final horseId in pastRaceHorseIds(pastRaces)) {
      recordsByHorse[horseId] =
          await horseRepo.getHorsePerformanceRecords(horseId);
      profileByHorse[horseId] = await horseRepo.getHorseProfile(horseId);
    }
    return buildPastRaceHorseFetchPlan(
      pastRaces: pastRaces,
      recordsByHorse: recordsByHorse,
      profileByHorse: profileByHorse,
    );
  }

  static Future<bool> _defaultFetchPerformance(String horseId) async {
    final records =
        await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);
    if (records.isEmpty) return false;
    await HorseRepository().insertHorseRaceRecords(records);
    return true;
  }

  static Future<bool> _defaultFetchPedigree(
      String horseId, String horseName) async {
    final profile = await HorseProfileScraperService.scrapeAndSavePedigreeOnly(
      horseId,
      horseName: horseName,
    );
    return profile != null;
  }
}
