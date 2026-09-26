// lib/services/ai_export/ai_race_data_collector.dart
// [追加] AI分析データエクスポート Step2: レースID・競走馬IDに紐づく実データを既存リポジトリから収集し AiRaceExportBundle へ束ねるサービス。新規スクレイピングはせずDB読み出しのみ。composeBundle は純粋関数でDB非依存(テスト対象) (v.2026.9.27+26092702)

import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_past_race_extra_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_speed_index_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_simulation_params_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_statistics_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_memo_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/ai_export/ai_race_export_bundle.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

/// 取得済みDBから、レース1本ぶんのAI分析用データを収集するサービス。
///
/// - 新規スクレイピングはしない（すでに保存済みのデータのみを読む）。
/// - 各リポジトリはコンストラクタで差し替え可能（テスト用）。既定は実リポジトリ。
/// - 実際のバンドル組み立ては純粋関数 [composeBundle] に切り出してある（DB非依存・テスト対象）。
class AiRaceDataCollector {
  final HorseRepository _horseRepository;
  final HorsePastRaceExtraRepository _extraRepository;
  final NetkeibaTrainingRepository _trainingRepository;
  final HorseSpeedIndexRepository _speedIndexRepository;
  final HorseSimulationParamsRepository _simParamsRepository;
  final TrainingRepository _trainingTimeRepository;
  final RaceStatisticsRepository _raceStatisticsRepository;
  final RaceMemoRepository _raceMemoRepository;
  final TrackConditionRepository _trackConditionRepository;

  AiRaceDataCollector({
    HorseRepository? horseRepository,
    HorsePastRaceExtraRepository? extraRepository,
    NetkeibaTrainingRepository? trainingRepository,
    HorseSpeedIndexRepository? speedIndexRepository,
    HorseSimulationParamsRepository? simParamsRepository,
    TrainingRepository? trainingTimeRepository,
    RaceStatisticsRepository? raceStatisticsRepository,
    RaceMemoRepository? raceMemoRepository,
    TrackConditionRepository? trackConditionRepository,
  })  : _horseRepository = horseRepository ?? HorseRepository(),
        _extraRepository = extraRepository ?? HorsePastRaceExtraRepository(),
        _trainingRepository =
            trainingRepository ?? NetkeibaTrainingRepository(),
        _speedIndexRepository =
            speedIndexRepository ?? HorseSpeedIndexRepository(),
        _simParamsRepository =
            simParamsRepository ?? HorseSimulationParamsRepository(),
        _trainingTimeRepository =
            trainingTimeRepository ?? TrainingRepository(),
        _raceStatisticsRepository =
            raceStatisticsRepository ?? RaceStatisticsRepository(),
        _raceMemoRepository = raceMemoRepository ?? RaceMemoRepository(),
        _trackConditionRepository =
            trackConditionRepository ?? TrackConditionRepository();

  /// 取得済みDBからレース1本ぶんのデータを収集して束ねる。新規スクレイピングはしない。
  Future<AiRaceExportBundle> collect({
    required String raceId,
    required String raceName,
    required String raceDate,
    required String userId,
    required List<String> horseIds,
  }) async {
    final performanceByHorse = <String, List<HorseRaceRecord>>{};
    final extrasByHorse = <String, Map<String, HorsePastRaceExtra>>{};
    final sessionsByHorse = <String, List<NetkeibaTrainingSession>>{};
    final profileByHorse = <String, HorseProfile>{};
    final trainingTimesByHorse = <String, List<TrainingTimeModel>>{};

    for (final horseId in horseIds) {
      final performance =
          await _horseRepository.getHorsePerformanceRecords(horseId);
      performanceByHorse[horseId] = performance;

      final raceIds = <String>{
        for (final r in performance)
          if (r.raceId.isNotEmpty) r.raceId,
      }.toList();
      extrasByHorse[horseId] =
          await _extraRepository.getForHorse(horseId, raceIds);

      sessionsByHorse[horseId] =
          await _trainingRepository.getSessionsForHorse(horseId);

      trainingTimesByHorse[horseId] =
          await _trainingTimeRepository.getTrainingTimesForHorse(horseId);

      final profile = await _horseRepository.getHorseProfile(horseId);
      if (profile != null) profileByHorse[horseId] = profile;
    }

    final reviewByHorse =
        await _trainingRepository.getReviewsForRace(raceId);
    final speedIndexByHorse =
        await _speedIndexRepository.getByHorseIds(horseIds);
    final simParamsByHorse =
        await _simParamsRepository.getByHorseIds(horseIds);

    final raceStatistics =
        await _raceStatisticsRepository.getRaceStatistics(raceId);
    final trackCondition = await _trackConditionRepository
        .getTrackConditionForRace(raceId: raceId, raceDate: raceDate);
    final raceMemo = await _raceMemoRepository.getRaceMemo(userId, raceId);

    return composeBundle(
      raceId: raceId,
      raceName: raceName,
      raceDate: raceDate,
      horseIds: horseIds,
      performanceByHorse: performanceByHorse,
      extrasByHorse: extrasByHorse,
      sessionsByHorse: sessionsByHorse,
      reviewByHorse: reviewByHorse,
      profileByHorse: profileByHorse,
      speedIndexByHorse: speedIndexByHorse,
      simParamsByHorse: simParamsByHorse,
      trainingTimesByHorse: trainingTimesByHorse,
      raceStatistics: raceStatistics,
      trackCondition: trackCondition,
      raceMemoText: raceMemo?.memo,
    );
  }

  /// 取得済みデータを [AiRaceExportBundle] へ組み立てる純粋関数（DB非依存・テスト対象）。
  ///
  /// 出走馬は [horseIds] の順に並べ、各マップに存在しない馬は
  /// 空リスト/空マップ/null で穴埋めする。[horseIds] に無い馬のデータは出力に含めない。
  static AiRaceExportBundle composeBundle({
    required String raceId,
    required String raceName,
    required String raceDate,
    required List<String> horseIds,
    required Map<String, List<HorseRaceRecord>> performanceByHorse,
    required Map<String, Map<String, HorsePastRaceExtra>> extrasByHorse,
    required Map<String, List<NetkeibaTrainingSession>> sessionsByHorse,
    required Map<String, NetkeibaTrainingReview> reviewByHorse,
    required Map<String, HorseProfile> profileByHorse,
    required Map<String, HorseSpeedIndex> speedIndexByHorse,
    required Map<String, HorseSimulationParams> simParamsByHorse,
    required Map<String, List<TrainingTimeModel>> trainingTimesByHorse,
    RaceStatistics? raceStatistics,
    TrackConditionRecord? trackCondition,
    String? raceMemoText,
  }) {
    final horses = <AiHorseData>[];
    for (final horseId in horseIds) {
      horses.add(AiHorseData(
        horseId: horseId,
        performance: performanceByHorse[horseId] ?? const [],
        extrasByRaceId: extrasByHorse[horseId] ?? const {},
        trainingSessions: sessionsByHorse[horseId] ?? const [],
        trainingReview: reviewByHorse[horseId],
        profile: profileByHorse[horseId],
        speedIndex: speedIndexByHorse[horseId],
        simulationParams: simParamsByHorse[horseId],
        trainingTimes: trainingTimesByHorse[horseId] ?? const [],
      ));
    }
    return AiRaceExportBundle(
      raceId: raceId,
      raceName: raceName,
      raceDate: raceDate,
      horses: horses,
      raceStatistics: raceStatistics,
      trackCondition: trackCondition,
      raceMemoText: raceMemoText,
    );
  }
}
