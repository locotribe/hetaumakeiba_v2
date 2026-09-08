// lib/logic/analysis/race_analysis_bundle_loader.dart

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/shutuba_table_cache_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/cross_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/historical_match_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/relative_battle_calculator.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_analysis_bundle.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:intl/intl.dart';

// [追加] 過去分析タブの子タブ群が共通で使う分析データを、1回だけまとめて読み込む (v.2026.9.5+26090506)
///
/// 読み込み手順は StatsMatchTab._startAnalysis() と同じものを踏襲している。
/// StatsMatchTab 側は結果分析タブ専用として従来どおり残すため、あちらのコードには手を入れていない。
/// 類似馬分析だけは結果分析タブ専用のためここには含めない。
class RaceAnalysisBundleLoader {
  final RaceRepository _raceRepo = RaceRepository();
  final ShutubaTableCacheRepository _shutubaTableCacheRepository = ShutubaTableCacheRepository();
  final HorseRepository _horseRepo = HorseRepository();
  final TrackConditionRepository _tcRepo = TrackConditionRepository();
  final HistoricalMatchEngine _engine = HistoricalMatchEngine();

  /// 分析データ一式を読み込む。
  ///
  /// 過去レースが1件も見つからない場合は null を返す。
  /// [onProgress] を渡すと、読み込み段階のメッセージを受け取れる。
  Future<RaceAnalysisBundle?> load({
    required String raceId,
    required String raceName,
    required List<PredictionHorseDetail> horses,
    List<String>? targetRaceIds,
    void Function(String message)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    int queryCount = 0;

    onProgress?.call('詳細データを収集中...');

    // 1. 今回の出走馬の履歴を取得
    final Map<String, List<HorseRaceRecord>> currentHorseHistory = {};
    for (final horse in horses) {
      final records = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
      currentHorseHistory[horse.horseId] = records;
      queryCount++;
    }

    // 2. 過去レース情報を取得（比較対象のレース群）
    List<RaceResult> pastRaces;
    if (targetRaceIds != null && targetRaceIds.isNotEmpty) {
      final resultsMap = await _raceRepo.getMultipleRaceResults(targetRaceIds);
      pastRaces = resultsMap.values.toList();
    } else {
      pastRaces = await _raceRepo.searchRaceResultsByName(raceName);
    }
    queryCount++;

    if (pastRaces.isEmpty) {
      debugPrint('[RaceAnalysisBundle] 過去レースが0件のため読み込みを中止しました。');
      return null;
    }

    // 3. 過去の上位馬（1〜3着）の履歴を取得
    onProgress?.call('過去の好走パターンを分析中...');
    final Map<String, List<HorseRaceRecord>> pastTopHorseRecords = {};
    for (final race in pastRaces) {
      for (final horse in race.horseResults) {
        final rank = int.tryParse(horse.rank);
        if (rank != null && rank <= 3 && horse.horseId.isNotEmpty) {
          if (!pastTopHorseRecords.containsKey(horse.horseId)) {
            final records =
                await _horseRepo.getHorsePerformanceRecords(horse.horseId);
            pastTopHorseRecords[horse.horseId] = records;
            queryCount++;
          }
        }
      }
    }

    // 4. 今回のレースの基本情報（芝ダ判定・開催日）
    bool isDirt = false;
    final targetCache = await _shutubaTableCacheRepository.getShutubaTableCache(raceId);
    queryCount++;
    if (targetCache != null) {
      isDirt = targetCache.predictionRaceData.trackType?.contains('ダ') ?? false;
    }

    String targetRaceDate;
    final targetResult = await _raceRepo.getRaceResult(raceId);
    queryCount++;
    if (targetResult != null) {
      targetRaceDate = targetResult.raceDate;
    } else if (targetCache != null) {
      targetRaceDate = targetCache.predictionRaceData.raceDate;
    } else {
      targetRaceDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    }

    // 5. 波乱度とラップ・ペースの算出（どちらもDBアクセスなしの純粋計算）
    onProgress?.call('馬場・血統データを集計中...');
    final volatilityResult = VolatilityAnalyzer().analyze(pastRaces);
    final lapTimeResult = LapTimeAnalyzer().analyze(pastRaces);

    // 6. 過去レース当日の馬場状態
    final Map<String, TrackConditionRecord> trackConditionMap = {};
    for (final race in pastRaces) {
      if (race.raceId.length >= 10) {
        final prefix10 = race.raceId.substring(0, 10);
        final tc = await _tcRepo.getLatestTrackConditionByPrefix(prefix10);
        queryCount++;
        if (tc != null) trackConditionMap[race.raceId] = tc;
      }
    }

    // 7. 血統プロフィール（今回の出走馬＋過去の1〜3着馬）
    final Map<String, HorseProfile> horseProfileMap = {};
    for (final horse in horses) {
      final profile = await _horseRepo.getHorseProfile(horse.horseId);
      queryCount++;
      if (profile != null) horseProfileMap[horse.horseId] = profile;
    }

    // 血統タブの取得ボタン用に、過去1〜3着馬の実頭数と未取得数も数える
    final Set<String> pedigreeTargetIds = {};
    for (final race in pastRaces) {
      for (final horse in race.horseResults) {
        final rank = int.tryParse(horse.rank) ?? 0;
        if (rank >= 1 && rank <= 3 && horse.horseId.isNotEmpty) {
          pedigreeTargetIds.add(horse.horseId);
          if (!horseProfileMap.containsKey(horse.horseId)) {
            final profile = await _horseRepo.getHorseProfile(horse.horseId);
            queryCount++;
            if (profile != null) horseProfileMap[horse.horseId] = profile;
          }
        }
      }
    }

    int missingPedigreeCount = 0;
    for (final horseId in pedigreeTargetIds) {
      final profile = horseProfileMap[horseId];
      if (profile == null || profile.fatherName.isEmpty) missingPedigreeCount++;
    }

    // 8. 馬場傾向と血統クロスの分析
    final trackConditionTrendResult =
        TrackConditionTrendAnalyzer().analyze(trackConditionMap);
    final pedigreeCrossResult = PedigreeCrossAnalyzer().analyze(
      pastRaces: pastRaces,
      trackConditionMap: trackConditionMap,
      horseProfileMap: horseProfileMap,
    );

    // 9. 今回の出走馬が過去に走ったレースの馬場状態
    final Map<String, TrackConditionRecord> horsePastTrackConditions = {};
    for (final records in currentHorseHistory.values) {
      for (final rec in records) {
        if (rec.raceId.length >= 10 &&
            !horsePastTrackConditions.containsKey(rec.raceId)) {
          final prefix10 = rec.raceId.substring(0, 10);
          final tc = await _tcRepo.getLatestTrackConditionByPrefix(prefix10);
          queryCount++;
          if (tc != null) horsePastTrackConditions[rec.raceId] = tc;
        }
      }
    }

    // 10. ペース別シミュレーション
    onProgress?.call('展開・ファクターを計算中...');
    final relResults = RelativeBattleCalculator().runSimulation(
      horses,
      horsePerformanceMap: currentHorseHistory,
    );
    final Map<String, RelativeEvaluationResult> relativeBattleResults = {
      for (final r in relResults) r.horseId: r
    };

    // 11. HistoricalMatchEngine によるファクター別スコアの算出
    final analysisResult = _engine.analyze(
      currentRaceName: raceName,
      pastRaceVolatility: volatilityResult.averagePopularity,
      currentHorses: horses,
      pastRaces: pastRaces,
      currentHorseHistory: currentHorseHistory,
      pastTopHorseRecords: pastTopHorseRecords,
      horseProfileMap: horseProfileMap,
      pedigreeCrossResult: pedigreeCrossResult,
      trackConditionTrendResult: trackConditionTrendResult,
      horsePastTrackConditions: horsePastTrackConditions,
      isDirt: isDirt,
    );

    final matchResults =
        (analysisResult['results'] as List<HistoricalMatchModel>?) ?? const [];
    final summary = analysisResult['summary'] as TrendSummary?;

    stopwatch.stop();
    debugPrint(
      '[RaceAnalysisBundle] 読み込み完了 raceId=$raceId '
      '対象レース=${pastRaces.length}件 出走馬=${horses.length}頭 '
      'DBクエリ=$queryCount回 所要=${stopwatch.elapsedMilliseconds}ms',
    );

    return RaceAnalysisBundle(
      pastRaces: pastRaces,
      currentHorseHistory: currentHorseHistory,
      pastTopHorseRecords: pastTopHorseRecords,
      trackConditionMap: trackConditionMap,
      horsePastTrackConditions: horsePastTrackConditions,
      horseProfileMap: horseProfileMap,
      trackConditionTrendResult: trackConditionTrendResult,
      pedigreeCrossResult: pedigreeCrossResult,
      volatilityResult: volatilityResult,
      lapTimeResult: lapTimeResult,
      totalTargetHorseCount: pedigreeTargetIds.length,
      missingPedigreeCount: missingPedigreeCount,
      relativeBattleResults: relativeBattleResults,
      matchResults: matchResults,
      summary: summary,
      isDirt: isDirt,
      targetRaceDate: targetRaceDate,
    );
  }
}
