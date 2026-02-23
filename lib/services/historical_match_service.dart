// lib/services/historical_match_service.dart

import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';

class HistoricalMatchService {
  final RaceRepository _raceRepo = RaceRepository();
  final HorseRepository _horseRepo = HorseRepository();

  /// 指定されたレース名に関連する過去データをDBから収集・補完します。
  Future<void> collectHistoricalData(String currentRaceName, {Function(String)? onProgress}) async {
    try {
      if (onProgress != null) onProgress('過去レースをDBから検索中...');

      final List<RaceResult> pastRaces = await _raceRepo.searchRaceResultsByName(currentRaceName);

      if (pastRaces.isEmpty) {
        if (onProgress != null) onProgress('該当する過去レースがDBに見つかりませんでした。');
        return;
      }

      final Set<String> targetHorseIds = {};

      for (final race in pastRaces) {
        final topHorses = race.horseResults.where((h) {
          final rankStr = h.rank;
          final rank = int.tryParse(rankStr);
          return rank != null && rank >= 1 && rank <= 3;
        });

        for (final horse in topHorses) {
          if (horse.horseId.isNotEmpty) {
            targetHorseIds.add(horse.horseId);
          }
        }
      }

      int processedCount = 0;
      final total = targetHorseIds.length;
      if (onProgress != null) onProgress('対象馬: $total頭');

      for (final horseId in targetHorseIds) {
        processedCount++;

        final List<HorseRaceRecord> existingRecords = await _horseRepo.getHorseRaceRecords(horseId);

        if (existingRecords.isEmpty) {
          if (onProgress != null) {
            onProgress('データ取得中 ($processedCount/$total): ID $horseId');
          }

          await _fetchAndSaveHorseData(horseId);
        } else {
          if (onProgress != null) {
            onProgress('データ確認済 ($processedCount/$total): ID $horseId');
          }
        }
      }

      if (onProgress != null) onProgress('データ収集完了');

    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchAndSaveHorseData(String horseId) async {
    final List<HorseRaceRecord> records =
    await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);

    if (records.isNotEmpty) {
      await _horseRepo.insertHorseRaceRecords(records);
    }

    await Future.delayed(const Duration(milliseconds: 1000));
  }
}