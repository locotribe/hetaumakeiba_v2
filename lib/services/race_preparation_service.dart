// lib/services/race_preparation_service.dart

// [追加] Phase 4-B: race_preparation_status（Phase 4-A）を使い、レース準備の各ステップを
// 依存順に・冪等に・状態を記録しながらScrapingManagerへ投入するサービス。
// この時点ではどこからも呼ばれない（サービス層のみの新設、UI配線はPhase 4-Cで行う） (v.2026.9.5+26090502)

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_preparation_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/training_data_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

/// 1ステップ分の実処理。戻り値は取得できた件数(itemCount)。
/// テストではネットワークを伴わない差し替え実装を注入する。
typedef PreparationStepExecutor = Future<int> Function({
  required String raceId,
  required String raceDate,
  required List<String> horseIds,
  required bool force,
});

/// レース準備パイプライン（出馬表〜過去10年統計）の取得状態を、
/// race_preparation_status（Phase 4-A）へ記録しながらScrapingManagerへ投入するサービス。
class RacePreparationService {
  final RacePreparationRepository _repository;
  final ScrapingManager _scrapingManager;
  final HorseRepository _horseRepository;
  final RaceRepository _raceRepository;
  final TrainingRepository _trainingRepository;
  late final Map<PreparationStep, PreparationStepExecutor> _executors;

  RacePreparationService({
    RacePreparationRepository? repository,
    ScrapingManager? scrapingManager,
    HorseRepository? horseRepository,
    RaceRepository? raceRepository,
    TrainingRepository? trainingRepository,
    Map<PreparationStep, PreparationStepExecutor>? stepExecutors,
  })  : _repository = repository ?? RacePreparationRepository(),
        _scrapingManager = scrapingManager ?? ScrapingManager(),
        _horseRepository = horseRepository ?? HorseRepository(),
        _raceRepository = raceRepository ?? RaceRepository(),
        _trainingRepository = trainingRepository ?? TrainingRepository() {
    _executors = {
      PreparationStep.shutuba: _defaultShutuba,
      PreparationStep.horseProfile: _defaultHorseProfile,
      PreparationStep.horsePerformance: _defaultHorsePerformance,
      PreparationStep.pastRaceResults: _defaultPastRaceResults,
      PreparationStep.training: _defaultTraining,
    };
    if (stepExecutors != null) {
      _executors.addAll(stepExecutors);
    }
  }

  /// ステップ間の依存関係。値は「そのステップの実行に完了していなければならない依存元」。
  static const Map<PreparationStep, List<PreparationStep>> stepDependencies = {
    // 出馬表ページで馬IDが確定するため依存なし。
    PreparationStep.shutuba: [],
    // 対象馬IDが出馬表取得時点で確定するため、出馬表の完了が前提。
    PreparationStep.horseProfile: [PreparationStep.shutuba],
    // 対象馬IDが出馬表取得時点で確定するため、出馬表の完了が前提。
    PreparationStep.horsePerformance: [PreparationStep.shutuba],
    // 過去成績に登場するraceIdを集めてから取得するため、過去成績の完了が前提。
    PreparationStep.pastRaceResults: [PreparationStep.horsePerformance],
    // 対象馬IDが出馬表取得時点で確定するため、出馬表の完了が前提。
    PreparationStep.training: [PreparationStep.shutuba],
    // 過去10年統計はレース名から独立して検索するため依存なし
    // （ただし自動実行はしない。enqueuePreparation内のコメント参照）。
    PreparationStep.raceStatistics: [],
  };

  /// 指定レースの準備ステップを依存順にScrapingManagerへ投入する。
  /// [force] が false のとき、既に done のステップと、依存元が done でないステップは投入しない。
  Future<void> enqueuePreparation({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
    required String raceName,
    bool force = false,
    Set<PreparationStep>? only,
  }) async {
    final current = await _repository.getForRace(raceId);

    for (final step in PreparationStep.values) {
      if (only != null && !only.contains(step)) continue;

      if (step == PreparationStep.raceStatistics) {
        // このステップは過去レースの選択がユーザー操作を伴うため自動実行しない。
        // 状態としてはskippedを記録するだけにとどめる。
        await _repository.markState(raceId, step, PreparationState.skipped);
        continue;
      }

      final existing = current[step];
      if (!force && existing?.state == PreparationState.done) {
        continue;
      }

      final deps = stepDependencies[step] ?? const [];
      final depsSatisfied =
          deps.every((dep) => current[dep]?.state == PreparationState.done);
      if (!depsSatisfied) {
        continue;
      }

      final executor = _executors[step];
      if (executor == null) continue;

      _scrapingManager.addRequest(
        _labelFor(step),
        () async {
          await _repository.markState(raceId, step, PreparationState.running);
          try {
            final itemCount = await executor(
              raceId: raceId,
              raceDate: raceDate,
              horseIds: horseIds,
              force: force,
            );
            await _repository.markState(
              raceId,
              step,
              PreparationState.done,
              itemCount: itemCount,
            );
          } catch (e) {
            debugPrint(
                'RacePreparationService: step ${step.name} failed for $raceId: $e');
            await _repository.markState(
              raceId,
              step,
              PreparationState.failed,
              error: e.toString(),
            );
          }
        },
        key: 'prep:$raceId:${step.name}',
      );
    }
  }

  /// 指定レースの全ステップの現在状態を返す（未記録のステップは pending 相当を補って返す）。
  Future<Map<PreparationStep, RacePreparationStatus>> getStatus(
    String raceId,
  ) async {
    final current = await _repository.getForRace(raceId);
    final now = DateTime.now();
    final result = <PreparationStep, RacePreparationStatus>{};
    for (final step in PreparationStep.values) {
      result[step] = current[step] ??
          RacePreparationStatus(
            raceId: raceId,
            step: step,
            state: PreparationState.pending,
            updatedAt: now,
          );
    }
    return result;
  }

  /// 指定レースの準備状況をすべて破棄する（再取得用）。
  Future<void> reset(String raceId) async {
    await _repository.deleteForRace(raceId);
  }

  String _labelFor(PreparationStep step) {
    switch (step) {
      case PreparationStep.shutuba:
        return '出馬表取得';
      case PreparationStep.horseProfile:
        return '馬プロフィール確認';
      case PreparationStep.horsePerformance:
        return '過去成績取得';
      case PreparationStep.pastRaceResults:
        return '過去レース結果取得';
      case PreparationStep.training:
        return '調教データ取得';
      case PreparationStep.raceStatistics:
        return '過去10年統計';
    }
  }

  Future<int> _defaultShutuba({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
    required bool force,
  }) async {
    final data = await ShutubaTableScraperService().scrapeAllData(raceId);
    return data.horses.length;
  }

  // horseProfileの取得自体はHorseProfileSyncServiceの既存フローに任せ、
  // このステップでは揃っている馬数を数えるだけにする (v.2026.9.5+26090502)
  Future<int> _defaultHorseProfile({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
    required bool force,
  }) async {
    int count = 0;
    for (final horseId in horseIds) {
      final profile = await _horseRepository.getHorseProfile(horseId);
      if (profile != null) count++;
    }
    return count;
  }

  // race_page.dartの_fetchAndSaveRaceResult()と同じ冪等パターン:
  // 既に成績がある馬はforce時以外スクレイプしない (v.2026.9.5+26090502)
  Future<int> _defaultHorsePerformance({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
    required bool force,
  }) async {
    int total = 0;
    for (final horseId in horseIds) {
      final existing = await _horseRepository.getHorsePerformanceRecords(horseId);
      if (force || existing.isEmpty) {
        try {
          final scraped =
              await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);
          for (final record in scraped) {
            await _horseRepository.insertOrUpdateHorsePerformance(record);
          }
        } catch (e) {
          debugPrint(
              'RacePreparationService: horsePerformance scrape failed for $horseId: $e');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        final updated = await _horseRepository.getHorsePerformanceRecords(horseId);
        total += updated.length;
      } else {
        total += existing.length;
      }
    }
    return total;
  }

  Future<int> _defaultPastRaceResults({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
    required bool force,
  }) async {
    final pastRaceIds = <String>{};
    for (final horseId in horseIds) {
      final records = await _horseRepository.getHorsePerformanceRecords(horseId);
      for (final record in records) {
        if (record.raceId.isNotEmpty) {
          pastRaceIds.add(record.raceId);
        }
      }
    }

    final existingResults =
        await _raceRepository.getMultipleRaceResults(pastRaceIds.toList());
    final toFetch =
        pastRaceIds.where((id) => !existingResults.containsKey(id)).toList();

    int fetchedCount = 0;
    for (final pastRaceId in toFetch) {
      try {
        await RaceResultScraperService.scrapeRaceDetails(
            generateRaceResultUrl(pastRaceId));
        fetchedCount++;
      } catch (e) {
        debugPrint(
            'RacePreparationService: pastRaceResults scrape failed for $pastRaceId: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return fetchedCount;
  }

  Future<int> _defaultTraining({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
    required bool force,
  }) async {
    final formattedDate = _formatDateForApi(raceDate);
    await TrainingDataService().fetchAndSaveTrainingData(
      raceId: raceId,
      raceDate: formattedDate,
      horseIds: horseIds,
    );

    int total = 0;
    for (final horseId in horseIds) {
      final records = await _trainingRepository.getTrainingTimesForHorse(horseId);
      total += records.length;
    }
    return total;
  }

  // training_tab.dartの_formatDateForApi()と同一ロジック。
  // training_tab.dart側は変更しないため、ここに複製する (v.2026.9.5+26090502)
  String _formatDateForApi(String rawDate) {
    final RegExp regExp =
        RegExp(r'(\d{4})[年/\-]\s*(\d{1,2})[月/\-]\s*(\d{1,2})');
    final match = regExp.firstMatch(rawDate);
    if (match != null) {
      final y = match.group(1)!;
      final m = match.group(2)!.padLeft(2, '0');
      final d = match.group(3)!.padLeft(2, '0');
      return '$y$m$d';
    }
    return rawDate.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
