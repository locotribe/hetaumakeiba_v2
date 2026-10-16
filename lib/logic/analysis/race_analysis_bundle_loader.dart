// lib/logic/analysis/race_analysis_bundle_loader.dart

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/shutuba_table_cache_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/cross_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/historical_match_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';
// [修正] 出走馬データ読み込み統一 Step3: 相対評価は読み込み係の結果を使う（出馬表のキャッシュが無いときだけ、ここで計算する） (v.2026.10.16+26101620)
import 'package:hetaumakeiba_v2/logic/race_entrant_data.dart';
import 'package:hetaumakeiba_v2/services/race_entrant_data_service.dart';
// [追加] 全出走馬の取得と読み込み Step3: 過去レースの全出走馬の取り出しと、今回の馬の過去走をレース日より前に絞る部品 (v.2026.10.16+26101610)
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
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
    // [追加] クラス判定の共通化 Step2: 人気妙味の基準にする今回のクラス (v.2026.10.16+26101602)
    required RaceClassGrade currentRaceClass,
    required List<PredictionHorseDetail> horses,
    List<String>? targetRaceIds,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('詳細データを収集中...');

    // 1. 今回の出走馬の履歴を取得
    final Map<String, List<HorseRaceRecord>> currentHorseHistory = {};
    for (final horse in horses) {
      final records = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
      currentHorseHistory[horse.horseId] = records;
    }

    // 2. 過去レース情報を取得（比較対象のレース群）
    List<RaceResult> pastRaces;
    if (targetRaceIds != null && targetRaceIds.isNotEmpty) {
      final resultsMap = await _raceRepo.getMultipleRaceResults(targetRaceIds);
      pastRaces = resultsMap.values.toList();
    } else {
      pastRaces = await _raceRepo.searchRaceResultsByName(raceName);
    }

    if (pastRaces.isEmpty) {
      debugPrint('[RaceAnalysisBundle] 過去レースが0件のため読み込みを中止しました。');
      return null;
    }

    // 3. 過去レースの全出走馬の履歴を取得
    // [修正] 全出走馬の取得と読み込み Step3: 1〜3着だけでなく全出走馬（取消・除外を除く）の履歴を読む（ローテタブのリフト化 A-4 で使う）。
    // 1〜3着の馬の履歴（pastTopHorseRecords）はそこから取り出して、今までどおり結果分析の計算に渡す (v.2026.10.16+26101610)
    onProgress?.call('過去の好走パターンを分析中...');
    final Map<String, List<HorseRaceRecord>> pastHorseRecords = {};
    for (final horseId in pastRaceHorseIds(pastRaces)) {
      pastHorseRecords[horseId] =
          await _horseRepo.getHorsePerformanceRecords(horseId);
    }
    final Map<String, List<HorseRaceRecord>> pastTopHorseRecords = {
      for (final horseId in pastTopFinisherHorseIds(pastRaces))
        horseId: pastHorseRecords[horseId] ?? const <HorseRaceRecord>[],
    };

    // 4. 今回のレースの基本情報（芝ダ判定・開催日）
    bool isDirt = false;
    final targetCache = await _shutubaTableCacheRepository.getShutubaTableCache(raceId);
    if (targetCache != null) {
      isDirt = targetCache.predictionRaceData.trackType?.contains('ダ') ?? false;
    }

    String targetRaceDate;
    final targetResult = await _raceRepo.getRaceResult(raceId);
    // [修正] 全出走馬の取得と読み込み Step3: レース結果の日付が空・読めないとき（実データで2件）は、出馬表の日付を使う (v.2026.10.16+26101610)
    if (targetResult != null &&
        parseRaceDateForSpeedIndex(targetResult.raceDate) != null) {
      targetRaceDate = targetResult.raceDate;
    } else if (targetCache != null) {
      targetRaceDate = targetCache.predictionRaceData.raceDate;
    } else {
      targetRaceDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    }

    // [追加] 全出走馬の取得と読み込み Step3: 今回の馬の過去走を、今回のレース日より前の走だけにする（そのレース自身の行も除く）。
    // 過去のレースを開くと、そのレース自身の結果や後の走が、人気妙味・馬場・相対評価（ペース）の計算に入っていた (v.2026.10.16+26101610)
    final targetRaceDay = parseRaceDateForSpeedIndex(targetRaceDate);
    if (targetRaceDay != null) {
      currentHorseHistory.updateAll((horseId, records) => filterRecordsBeforeAsOf(
            records,
            asOf: targetRaceDay,
            excludeRaceId: raceId,
          ));
    }

    // 5. 波乱度とラップ・ペースの算出（どちらもDBアクセスなしの純粋計算）
    onProgress?.call('馬場・血統データを集計中...');
    final volatilityResult = VolatilityAnalyzer().analyze(pastRaces);
    final lapTimeResult = LapTimeAnalyzer().analyze(pastRaces);

    // 6. 過去レース当日の馬場状態
    final Map<String, TrackConditionRecord> trackConditionMap = {};
    for (final race in pastRaces) {
      if (race.raceId.length >= 10) {
        // [修正] 先頭10桁一致ではなく競馬場コード＋開催日で照合 (v.2026.9.19+26091901)
        final tc = await _tcRepo.getTrackConditionForRace(
          raceId: race.raceId,
          raceDate: race.raceDate,
        );
        if (tc != null) trackConditionMap[race.raceId] = tc;
      }
    }

    // 7. 血統プロフィール（今回の出走馬＋過去の1〜3着馬）
    final Map<String, HorseProfile> horseProfileMap = {};
    for (final horse in horses) {
      final profile = await _horseRepo.getHorseProfile(horse.horseId);
      if (profile != null) horseProfileMap[horse.horseId] = profile;
    }

    // [追加] 全出走馬の取得と読み込み Step3: 過去レースの全出走馬の血統も読む（血統タブのリフト化 A-5 で使う）。
    // [削除] 総合シンクロ率と血統クロス Step4: 血統クロスカードの「不足」の数え上げ（過去1〜3着馬の頭数・血統が無い頭数）は使わなくなったので削除した。1〜3着の馬の血統もこの全出走馬の読み込みに入る (v.2026.10.16+26101617)
    for (final horseId in pastRaceHorseIds(pastRaces)) {
      if (horseProfileMap.containsKey(horseId)) continue;
      final profile = await _horseRepo.getHorseProfile(horseId);
      if (profile != null) horseProfileMap[horseId] = profile;
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
          // [修正] 先頭10桁一致ではなく競馬場コード＋開催日で照合 (v.2026.9.19+26091901)
          final tc = await _tcRepo.getTrackConditionForRace(
            raceId: rec.raceId,
            raceDate: rec.date,
          );
          if (tc != null) horsePastTrackConditions[rec.raceId] = tc;
        }
      }
    }

    // 10. ペース別シミュレーション
    onProgress?.call('展開・ファクターを計算中...');
    // [修正] 出走馬データ読み込み統一 Step3: 出馬表のキャッシュがあれば、読み込み係が1回だけ計算した相対評価を使う（出走馬分析の相対評価タブと同じ数字。
    // 騎手成績・調教を含み、取消の馬は入らない）。キャッシュが無い古いレースは今までどおりここで計算する（乱数はレースIDで固定・取消の馬は入れない） (v.2026.10.16+26101620)
    final Map<String, RelativeEvaluationResult> relativeBattleResults;
    if (targetCache != null) {
      final entrantData = await RaceEntrantDataService.instance
          .load(targetCache.predictionRaceData);
      relativeBattleResults = entrantData.relativeByHorse;
    } else {
      relativeBattleResults = {
        for (final r in computeRelativeBattle(
          raceId: raceId,
          horses: horses,
          recordsByHorse: currentHorseHistory,
        ))
          r.horseId: r
      };
    }

    // 11. HistoricalMatchEngine によるファクター別スコアの算出
    final analysisResult = _engine.analyze(
      currentRaceName: raceName,
      currentRaceClass: currentRaceClass,
      // [追加] 前走と路線の部品 Step2: 今回の馬の前走を決める基準日 (v.2026.10.16+26101606)
      currentRaceDate: targetRaceDate,
      pastRaceVolatility: volatilityResult.averagePopularity,
      currentHorses: horses,
      pastRaces: pastRaces,
      currentHorseHistory: currentHorseHistory,
      pastTopHorseRecords: pastTopHorseRecords,
      // [修正] 総合シンクロ率と血統クロス Step2: ローテ・血統の点数を倍率で出すため全出走馬の戦績を渡す。血統クロスの結果は渡さなくなった（血統クロスカードには今までどおり使う） (v.2026.10.16+26101615)
      pastHorseRecords: pastHorseRecords,
      horseProfileMap: horseProfileMap,
      trackConditionTrendResult: trackConditionTrendResult,
      horsePastTrackConditions: horsePastTrackConditions,
      isDirt: isDirt,
    );

    final matchResults =
        (analysisResult['results'] as List<HistoricalMatchModel>?) ?? const [];
    final summary = analysisResult['summary'] as TrendSummary?;

    return RaceAnalysisBundle(
      pastRaces: pastRaces,
      currentHorseHistory: currentHorseHistory,
      pastTopHorseRecords: pastTopHorseRecords,
      // [追加] 全出走馬の取得と読み込み Step3 (v.2026.10.16+26101610)
      pastHorseRecords: pastHorseRecords,
      trackConditionMap: trackConditionMap,
      horsePastTrackConditions: horsePastTrackConditions,
      horseProfileMap: horseProfileMap,
      trackConditionTrendResult: trackConditionTrendResult,
      pedigreeCrossResult: pedigreeCrossResult,
      volatilityResult: volatilityResult,
      lapTimeResult: lapTimeResult,
      relativeBattleResults: relativeBattleResults,
      matchResults: matchResults,
      summary: summary,
      isDirt: isDirt,
      targetRaceDate: targetRaceDate,
    );
  }
}
