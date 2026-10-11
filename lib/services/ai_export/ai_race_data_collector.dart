// lib/services/ai_export/ai_race_data_collector.dart
// [追加] AI分析データエクスポート Step2: レースID・競走馬IDに紐づく実データを既存リポジトリから収集し AiRaceExportBundle へ束ねるサービス。新規スクレイピングはせずDB読み出しのみ。composeBundle は純粋関数でDB非依存(テスト対象) (v.2026.9.27+26092702)
// [修正] AI分析データ 天気・コース追加 Step3: コース（高低差）・コースプリセット・開催中の馬場推移・その競馬場の最新測定・天気（レース情報タブと同じ OpenMeteoService のキャッシュ優先の取得）を収集に加えた。追加の引数はすべて省略可 (v.2026.10.11+26101103)

import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_past_race_extra_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_speed_index_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_simulation_params_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_statistics_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_memo_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/course_preset_repository.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_course_profile.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_weather_snapshot.dart';
import 'package:hetaumakeiba_v2/logic/analysis/course_preset_id_resolver.dart';
import 'package:hetaumakeiba_v2/services/open_meteo_service.dart';
import 'package:hetaumakeiba_v2/models/ai_export/ai_race_export_bundle.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

/// ピンポイント天気を取る関数（テストで差し替える）。
/// 既定は [OpenMeteoService.fetchDetailedWeather]（キャッシュ優先。[isPastRace] が true ならキャッシュのみ）。
typedef AiPinpointWeatherFetcher = Future<Map<String, dynamic>?> Function({
  required String venue,
  required String raceDate,
  required String startTime,
  required String raceId,
  required bool isPastRace,
});

Future<Map<String, dynamic>?> _defaultPinpointWeatherFetcher({
  required String venue,
  required String raceDate,
  required String startTime,
  required String raceId,
  required bool isPastRace,
}) {
  return OpenMeteoService.fetchDetailedWeather(
    venue,
    raceDate,
    startTime,
    raceId,
    isPastRace: isPastRace,
  );
}

/// 取得済みDBから、レース1本ぶんのAI分析用データを収集するサービス。
///
/// - 新規スクレイピングはしない（すでに保存済みのデータのみを読む）。
/// - 天気だけは、レース情報タブと同じくキャッシュが無く発走前なら取得する。
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
  // [追加] 過去レースの印・メモ Step1: 過去レースの印（user_marks）を読む (v.2026.10.12+26101203)
  final UserRepository _userRepository;
  final TrackConditionRepository _trackConditionRepository;
  final CoursePresetRepository _coursePresetRepository;
  final AiPinpointWeatherFetcher _weatherFetcher;
  final DateTime Function() _now;

  AiRaceDataCollector({
    HorseRepository? horseRepository,
    HorsePastRaceExtraRepository? extraRepository,
    NetkeibaTrainingRepository? trainingRepository,
    HorseSpeedIndexRepository? speedIndexRepository,
    HorseSimulationParamsRepository? simParamsRepository,
    TrainingRepository? trainingTimeRepository,
    RaceStatisticsRepository? raceStatisticsRepository,
    RaceMemoRepository? raceMemoRepository,
    UserRepository? userRepository,
    TrackConditionRepository? trackConditionRepository,
    CoursePresetRepository? coursePresetRepository,
    AiPinpointWeatherFetcher? weatherFetcher,
    DateTime Function()? now,
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
        _userRepository = userRepository ?? UserRepository(),
        _trackConditionRepository =
            trackConditionRepository ?? TrackConditionRepository(),
        _coursePresetRepository =
            coursePresetRepository ?? CoursePresetRepository(),
        _weatherFetcher = weatherFetcher ?? _defaultPinpointWeatherFetcher,
        _now = now ?? (() => DateTime.now());

  /// 取得済みDBからレース1本ぶんのデータを収集して束ねる。新規スクレイピングはしない。
  /// [venue]〜[courseInOut] は出馬表（PredictionRaceData）の値。省略するとコース・天気は出さない。
  Future<AiRaceExportBundle> collect({
    required String raceId,
    required String raceName,
    required String raceDate,
    required String userId,
    required List<String> horseIds,
    String? venue,
    String? startTime,
    String? trackType,
    int? distanceValue,
    String? direction,
    String? courseInOut,
  }) async {
    final performanceByHorse = <String, List<HorseRaceRecord>>{};
    final extrasByHorse = <String, Map<String, HorsePastRaceExtra>>{};
    final sessionsByHorse = <String, List<NetkeibaTrainingSession>>{};
    final profileByHorse = <String, HorseProfile>{};
    final trainingTimesByHorse = <String, List<TrainingTimeModel>>{};
    // [追加] T4a: 過去走ごとの馬場を prefix10 で収集（キャッシュで重複クエリ回避）
    final trackByPrefix10 = <String, TrackConditionRecord?>{};
    final pastTrackByHorse = <String, Map<String, TrackConditionRecord>>{};
    // [追加] 過去レースの印・メモ Step1: 過去走ごとの印・メモと、レースごとのAIの予想・レース総評（同じレースは1回だけ読む） (v.2026.10.12+26101203)
    final pastNotesByHorse = <String, Map<String, AiPastRaceNote>>{};
    final pastRaceMemos = <String, AiPastRaceMemo>{};
    final marksByRaceId = <String, Map<String, String>>{};
    final checkedRaceMemoIds = <String>{};

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

      // [追加] T4a: 各過去走の raceId 先頭10桁で馬場を照合（既取得はキャッシュ流用）
      final pastTrack = <String, TrackConditionRecord>{};
      for (final rid in raceIds) {
        if (rid.length < 10) continue;
        final prefix10 = rid.substring(0, 10);
        if (!trackByPrefix10.containsKey(prefix10)) {
          trackByPrefix10[prefix10] = await _trackConditionRepository
              .getLatestTrackConditionByPrefix(prefix10);
        }
        final tc = trackByPrefix10[prefix10];
        if (tc != null) pastTrack[rid] = tc;
      }
      pastTrackByHorse[horseId] = pastTrack;

      // [追加] 過去レースの印・メモ Step1: 今回のレースを除いた過去走について、印・予想メモ・回顧メモと、レースのAIの予想・レース総評を集める (v.2026.10.12+26101203)
      final pastRaceIds = raceIds.where((rid) => rid != raceId).toList();
      final horseMemos = await _horseRepository.getMemosForHorseByRaceIds(
          userId, horseId, pastRaceIds);
      final horseMemoByRaceId = {for (final m in horseMemos) m.raceId: m};
      final notes = <String, AiPastRaceNote>{};
      for (final rid in pastRaceIds) {
        if (!marksByRaceId.containsKey(rid)) {
          final raceMarks =
              await _userRepository.getAllUserMarksForRace(userId, rid);
          marksByRaceId[rid] = {for (final mk in raceMarks) mk.horseId: mk.mark};
        }
        if (checkedRaceMemoIds.add(rid)) {
          final pastRaceMemo = await _raceMemoRepository.getRaceMemo(userId, rid);
          if (pastRaceMemo != null) {
            pastRaceMemos[rid] = AiPastRaceMemo(
              aiPrediction: pastRaceMemo.aiPredictionMemo,
              review: pastRaceMemo.memo,
            );
          }
        }
        final horseMemo = horseMemoByRaceId[rid];
        notes[rid] = AiPastRaceNote(
          mark: marksByRaceId[rid]![horseId],
          predictionMemo: horseMemo?.predictionMemo,
          reviewMemo: horseMemo?.reviewMemo,
        );
      }
      pastNotesByHorse[horseId] = notes;

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

    // [追加] AI分析データ 天気・コース追加 Step3: コース（高低差）とコースプリセット (v.2026.10.11+26101103)
    final courseData = findAiRaceCourse(
      raceId: raceId,
      distance: distanceValue,
      trackType: trackType,
      direction: direction,
      courseInOut: courseInOut,
    );
    final courseProfile =
        courseData == null ? null : buildAiCourseProfile(courseData);
    final coursePreset = await _findCoursePreset(
      raceId: raceId,
      trackType: trackType,
      distanceValue: distanceValue,
      direction: direction,
      courseInOut: courseInOut,
    );

    // [追加] AI分析データ 天気・コース追加 Step3: 同じ開催の馬場の測定と、その競馬場の最新の測定 (v.2026.10.11+26101103)
    final meetingTrackHistory = raceId.length >= 8
        ? await _trackConditionRepository
            .getTrackConditionsByMeeting(raceId.substring(0, 8))
        : <TrackConditionRecord>[];
    final latestVenueTrackCondition =
        await _findLatestVenueTrackCondition(raceId);

    // [追加] AI分析データ 天気・コース追加 Step3: 天気（レース情報タブと同じ取得・同じ起点で馬場予測） (v.2026.10.11+26101103)
    AiWeatherSnapshot? weatherSnapshot;
    String? weatherUnavailableReason;
    if (venue == null || venue.isEmpty || raceId.length < 6) {
      weatherUnavailableReason = '未取得（開催場が不明）';
    } else {
      final locked = isAiWeatherLocked(
        raceDate: raceDate,
        startTime: startTime,
        now: _now(),
      );
      Map<String, dynamic>? pinpoint;
      try {
        pinpoint = await _weatherFetcher(
          venue: venue,
          raceDate: raceDate,
          startTime: startTime ?? '15:00',
          raceId: raceId,
          isPastRace: locked,
        );
      } catch (_) {
        pinpoint = null;
      }
      weatherSnapshot = buildAiWeatherSnapshot(
        pinpoint: pinpoint,
        baseline: latestVenueTrackCondition,
        venueCode: raceId.substring(4, 6),
        trackType: trackType,
        raceDate: raceDate,
      );
      if (weatherSnapshot == null) {
        weatherUnavailableReason = locked
            ? '未取得（発走後で保存データなし）'
            : '未取得（レース情報タブの🔄で取得）';
      }
    }

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
      // [修正] レースメモ用途分離: エクスポートはAI予想・買い目(aiPredictionMemo)を読む (v.2026.9.28+26092802)
      raceMemoText: raceMemo?.aiPredictionMemo,
      pastTrackByHorse: pastTrackByHorse,
      // [追加] 過去レースの印・メモ Step1 (v.2026.10.12+26101203)
      pastNotesByHorse: pastNotesByHorse,
      pastRaceMemos: pastRaceMemos,
      courseProfile: courseProfile,
      coursePreset: coursePreset,
      meetingTrackHistory: meetingTrackHistory,
      latestVenueTrackCondition: latestVenueTrackCondition,
      weatherSnapshot: weatherSnapshot,
      weatherUnavailableReason: weatherUnavailableReason,
    );
  }

  /// コースプリセットを探す。ID候補は展開シミュ（race_analyzer.dart）と同じ CoursePresetIdResolver の順。
  Future<CoursePreset?> _findCoursePreset({
    required String raceId,
    required String? trackType,
    required int? distanceValue,
    required String? direction,
    required String? courseInOut,
  }) async {
    if (raceId.length < 6 || distanceValue == null) return null;
    final tt = trackType ?? '';
    final presetTrackType =
        tt.contains('障') ? 'obstacle' : (tt.contains('ダ') ? 'dirt' : 'shiba');
    for (final candidateId in CoursePresetIdResolver.candidates(
      venueCode: raceId.substring(4, 6),
      trackType: presetTrackType,
      distance: distanceValue.toString(),
      direction: direction,
      courseInOut: courseInOut,
    )) {
      final preset = await _coursePresetRepository.getCoursePreset(candidateId);
      if (preset != null) return preset;
    }
    return null;
  }

  /// その競馬場の最新の測定。レース情報タブ（shutuba_table_page.dart の _loadTrackCondition）と同じ選び方。
  Future<TrackConditionRecord?> _findLatestVenueTrackCondition(
      String raceId) async {
    if (raceId.length < 6) return null;
    final venueCode = raceId.substring(4, 6);
    final records =
        await _trackConditionRepository.getLatestTrackConditionsForEachCourse();
    for (final record in records) {
      final idStr = record.trackConditionId.toString();
      if (idStr.length >= 6 && idStr.substring(4, 6) == venueCode) {
        return record;
      }
    }
    return null;
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
    Map<String, Map<String, TrackConditionRecord>> pastTrackByHorse = const {},
    AiCourseProfile? courseProfile,
    CoursePreset? coursePreset,
    List<TrackConditionRecord> meetingTrackHistory = const [],
    TrackConditionRecord? latestVenueTrackCondition,
    AiWeatherSnapshot? weatherSnapshot,
    String? weatherUnavailableReason,
    // [追加] 過去レースの印・メモ Step1: 今回のレース（[raceId]）のものと中身の無いものは、ここで取り除く (v.2026.10.12+26101203)
    Map<String, Map<String, AiPastRaceNote>> pastNotesByHorse = const {},
    Map<String, AiPastRaceMemo> pastRaceMemos = const {},
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
        pastTrackByRaceId: pastTrackByHorse[horseId] ?? const {},
        pastNotesByRaceId: {
          for (final entry
              in (pastNotesByHorse[horseId] ?? const <String, AiPastRaceNote>{})
                  .entries)
            if (entry.key != raceId && !entry.value.isEmpty)
              entry.key: entry.value,
        },
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
      courseProfile: courseProfile,
      coursePreset: coursePreset,
      meetingTrackHistory: meetingTrackHistory,
      latestVenueTrackCondition: latestVenueTrackCondition,
      weatherSnapshot: weatherSnapshot,
      weatherUnavailableReason: weatherUnavailableReason,
      pastRaceMemos: {
        for (final entry in pastRaceMemos.entries)
          if (entry.key != raceId && !entry.value.isEmpty)
            entry.key: entry.value,
      },
    );
  }
}
