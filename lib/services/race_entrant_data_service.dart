// lib/services/race_entrant_data_service.dart

// [追加] 出走馬データ読み込み統一 Step2: 今回の出走馬のデータ（レース日より前に絞った戦績・血統・調教・騎手成績）を
// レースごとに1回だけ読み、相対評価も1回だけ計算して、出馬表・出走馬分析・過去分析・結果分析で使い回す読み込み係。
// - 同じレースで、相対評価・騎手成績に使う欄（raceEntrantInputKeyOf）が同じなら、前に読んだ結果をそのまま返す。
//   オッズの更新や取消で欄が変わったら読み直す。
// - レース準備の「出走馬の戦績」「調教」が終わったら、そのレースの結果を捨てて changes に知らせる（次に読むときに読み直す）。
// - 取り直しが終わるまで待つかどうかは使う側が決める（出走馬分析の待ち合わせはそのまま） (v.2026.10.16+26101619)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/logic/race_entrant_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/services/jockey_analysis_service.dart';
import 'package:hetaumakeiba_v2/services/race_preparation_service.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';

class RaceEntrantDataService {
  RaceEntrantDataService._() {
    // アプリが動いている間ずっと使うので、購読は解除しない
    RacePreparationService.stepCompletedStream.listen((event) {
      if (event.step == PreparationStep.horsePerformance ||
          event.step == PreparationStep.training) {
        invalidate(event.raceId);
      }
    });
  }

  /// アプリ全体で1つだけ使う。
  static final RaceEntrantDataService instance = RaceEntrantDataService._();

  final HorseRepository _horseRepository = HorseRepository();
  final TrainingRepository _trainingRepository = TrainingRepository();
  final NetkeibaTrainingRepository _netkeibaTrainingRepository =
      NetkeibaTrainingRepository();
  final JockeyAnalysisService _jockeyAnalysisService = JockeyAnalysisService();

  /// レースID → 読み込み中または読み込み済みの結果。
  final Map<String, Future<RaceEntrantData>> _futures = {};

  /// レースID → その結果を作ったときの入力の見分けの文字列。
  final Map<String, String> _inputKeys = {};

  final StreamController<String> _changedController =
      StreamController<String>.broadcast();

  /// 結果を捨てたレースのIDが流れる（使う側は自分のレースなら読み直す）。
  Stream<String> get changes => _changedController.stream;

  /// 今回の出走馬のデータを返す。同じレース・同じ入力なら、前に読んだ結果（読み込み中ならその完了）を返す。
  Future<RaceEntrantData> load(PredictionRaceData raceData) {
    final raceId = raceData.raceId;
    final inputKey = raceEntrantInputKeyOf(raceData);
    final existing = _futures[raceId];
    if (existing != null && _inputKeys[raceId] == inputKey) {
      return existing;
    }
    final future = _build(raceData);
    _futures[raceId] = future;
    _inputKeys[raceId] = inputKey;
    // 失敗した結果は残さない（次に読むときに読み直す）
    unawaited(future.then<void>((_) {}, onError: (Object e) {
      debugPrint('RaceEntrantDataService: 読み込みに失敗: $raceId $e');
      if (identical(_futures[raceId], future)) {
        _futures.remove(raceId);
        _inputKeys.remove(raceId);
      }
    }));
    return future;
  }

  /// そのレースの結果を捨て、changes に知らせる。
  /// 出走馬の戦績を取り直したときなどに呼ぶ。
  void invalidate(String raceId) {
    _futures.remove(raceId);
    _inputKeys.remove(raceId);
    _changedController.add(raceId);
  }

  Future<RaceEntrantData> _build(PredictionRaceData raceData) async {
    final raceId = raceData.raceId;
    final raceDay = parseRaceDateForSpeedIndex(raceData.raceDate);
    final raceYmd = toYyyymmdd(raceData.raceDate);

    final Map<String, List<HorseRaceRecord>> allRecords = {};
    final Map<String, HorseProfile> profiles = {};
    final Map<String, List<TrainingTimeModel>> pakaraTraining = {};
    final Map<String, List<NetkeibaTrainingSession>> netkeibaTraining = {};

    for (final horse in raceData.horses) {
      final horseId = horse.horseId;
      allRecords[horseId] =
          await _horseRepository.getHorsePerformanceRecords(horseId);
      final profile = await _horseRepository.getHorseProfile(horseId);
      if (profile != null) profiles[horseId] = profile;
      // レース当日以降の調教を除く（出走馬分析と同じ絞り方）
      pakaraTraining[horseId] = filterTrainingBeforeRace(
        await _trainingRepository.getTrainingTimesForHorse(horseId),
        raceData.raceDate,
      );
      var sessions =
          await _netkeibaTrainingRepository.getSessionsForHorse(horseId);
      if (raceYmd != null) {
        sessions =
            sessions.where((s) => s.trainingDate.compareTo(raceYmd) < 0).toList();
      }
      netkeibaTraining[horseId] = sessions;
    }

    final records =
        recordsBeforeRace(allRecords, raceDay: raceDay, raceId: raceId);
    final reviews =
        await _netkeibaTrainingRepository.getReviewsForRace(raceId);

    // 騎手成績は DB の全レース結果を数えるので重い。失敗しても騎手の点なしで続ける（展開シミュと同じ扱い）
    Map<String, JockeyStats> jockeyStats = const {};
    try {
      jockeyStats = await _jockeyAnalysisService.analyzeAllJockeys(
        jockeyIdsForStatsOf(raceData.horses, records).toList(),
        raceData: raceData,
      );
    } catch (e) {
      debugPrint('RaceEntrantDataService: 騎手成績の計算に失敗: $raceId $e');
      jockeyStats = const {};
    }

    final relativeResults = computeRelativeBattle(
      raceId: raceId,
      horses: raceData.horses,
      recordsByHorse: records,
      jockeyStats: jockeyStats,
      pakaraTrainingByHorse: pakaraTraining,
      netkeibaTrainingByHorse: netkeibaTraining,
      netkeibaReviews: reviews,
    );

    return RaceEntrantData(
      raceId: raceId,
      raceDay: raceDay,
      recordsByHorse: records,
      profilesByHorse: profiles,
      pakaraTrainingByHorse: pakaraTraining,
      netkeibaTrainingByHorse: netkeibaTraining,
      netkeibaReviews: reviews,
      jockeyStats: jockeyStats,
      relativeResults: relativeResults,
    );
  }
}
