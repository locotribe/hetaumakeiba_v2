// lib/services/past_records_status_service.dart

// [追加] 過去走の取得状況ポップアップ: DB・SharedPreferences・レース準備の記録から、出走馬の過去走（戦績と戦績内レースの結果）が
// 揃っているか・何が欠けているか・取得に失敗したものは何かを調べる。通信は一切しない (v.2026.11.5+26110501)

import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/logic/past_record_status.dart';
import 'package:hetaumakeiba_v2/logic/provisional_race_result.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/services/horse_fetch_outcome_store.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';
import 'package:hetaumakeiba_v2/services/race_preparation_service.dart';

/// レース結果をまとめて読むときの1回の件数（SQLite の引数の上限に収めるため分けて読む）。
const int _kRaceResultChunkSize = 400;

class PastRecordsStatusService {
  final HorseRepository _horseRepository;
  final RaceRepository _raceRepository;
  final RacePreparationService _preparationService;

  PastRecordsStatusService({
    HorseRepository? horseRepository,
    RaceRepository? raceRepository,
    RacePreparationService? preparationService,
  })  : _horseRepository = horseRepository ?? HorseRepository(),
        _raceRepository = raceRepository ?? RaceRepository(),
        _preparationService = preparationService ?? RacePreparationService();

  /// レース [raceId] の出走馬 [horses] の過去走の取得状況を調べる。
  Future<PastRecordsReport> load({
    required String raceId,
    required List<PastRecordHorse> horses,
  }) async {
    final recordCountByHorse = <String, int>{};
    final pastRaceIds = <String>{};
    for (final horse in horses) {
      final records =
          await _horseRepository.getHorsePerformanceRecords(horse.horseId);
      recordCountByHorse[horse.horseId] = records.length;
      for (final record in records) {
        if (record.raceId.isNotEmpty) {
          pastRaceIds.add(record.raceId);
        }
      }
    }

    // 戦績内レースの結果の保存状況（取得処理の _defaultPastRaceResults と同じ見方）
    final savedRaceIds = <String>{};
    final provisionalRaceIds = <String>{};
    final idList = pastRaceIds.toList();
    for (var i = 0; i < idList.length; i += _kRaceResultChunkSize) {
      final end = i + _kRaceResultChunkSize < idList.length
          ? i + _kRaceResultChunkSize
          : idList.length;
      final results =
          await _raceRepository.getMultipleRaceResults(idList.sublist(i, end));
      for (final entry in results.entries) {
        savedRaceIds.add(entry.key);
        if (isProvisionalJraRaceResult(entry.value)) {
          provisionalRaceIds.add(entry.key);
        }
      }
    }

    final outcomeByHorse = await HorseFetchOutcomeStore.loadOutcomes(
        horses.map((h) => h.horseId));
    final failedRaceIds =
        await HorseFetchOutcomeStore.loadFailedPastRaceIds(raceId);
    final isLoggedIn = await NetkeibaSessionService.isLoggedIn();
    final status = await _preparationService.getStatus(raceId);
    final performance = status[PreparationStep.horsePerformance];
    final pastResults = status[PreparationStep.pastRaceResults];

    return buildPastRecordsReport(
      horses: horses,
      recordCountByHorse: recordCountByHorse,
      outcomeByHorse: outcomeByHorse,
      pastRaceIds: pastRaceIds,
      savedRaceIds: savedRaceIds,
      provisionalRaceIds: provisionalRaceIds,
      failedRaceIds: failedRaceIds,
      isLoggedIn: isLoggedIn,
      performanceState: performance?.state ?? PreparationState.pending,
      performanceUpdatedAt:
          performance?.state == PreparationState.pending ? null : performance?.updatedAt,
      pastResultsState: pastResults?.state ?? PreparationState.pending,
    );
  }
}
