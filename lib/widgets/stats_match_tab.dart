// lib/widgets/stats_match_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/shutuba_table_cache_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/cross_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/historical_match_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';
import 'package:hetaumakeiba_v2/logic/relative_battle_calculator.dart';
// [追加] 前走と路線の部品 Step2: 前走は共通の部品で決め、日付は共通の関数で読む (v.2026.10.16+26101606)
import 'package:hetaumakeiba_v2/logic/previous_race.dart';
// [追加] 総合シンクロ率と血統クロス Step3: 類似馬のローテ比較で、前走を路線にまとめる部品 (v.2026.10.16+26101616)
import 'package:hetaumakeiba_v2/logic/race_route.dart';
// [追加] 全出走馬の取得と読み込み Step3: 過去レースの全出走馬の取り出しと、今回の馬の過去走をレース日より前に絞る部品 (v.2026.10.16+26101610)
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:intl/intl.dart';

// [追加] 枠色付き馬番バッジ (v.2026.9.5+26090506)
import 'package:hetaumakeiba_v2/widgets/horse_number_badge.dart';

// 類似度データを保持するクラス
class SimilarityData {
  final String horseName;
  final double similarity; // 0-100
  final String rank;
  final String popularity;
  final String raceName;
  final String raceDate;

  SimilarityData({
    required this.horseName,
    required this.similarity,
    required this.rank,
    required this.popularity,
    required this.raceName,
    required this.raceDate,
  });
}

class StatsMatchTab extends StatefulWidget {
  final String raceId;
  final String raceName;
  // [追加] クラス判定の共通化 Step2: 人気妙味の基準にする今回のクラス (v.2026.10.16+26101602)
  final RaceClassGrade currentRaceClass;
  final List<PredictionHorseDetail> horses;
  // 集計対象とするレースIDのリスト
  final List<String>? targetRaceIds;
  // 比較対象（予想時）のデータリスト。これがある場合は結果分析モードとして動作
  final List<PredictionHorseDetail>? comparisonTargets;

  const StatsMatchTab({
    super.key,
    required this.raceId,
    required this.raceName,
    required this.currentRaceClass,
    required this.horses,
    this.targetRaceIds,
    this.comparisonTargets,
  });

  @override
  State<StatsMatchTab> createState() => _StatsMatchTabState();
}

class _StatsMatchTabState extends State<StatsMatchTab> {
  final HistoricalMatchEngine _engine = HistoricalMatchEngine();
  final RaceRepository _raceRepo = RaceRepository();
  final ShutubaTableCacheRepository _shutubaTableCacheRepository = ShutubaTableCacheRepository();
  final HorseRepository _horseRepo = HorseRepository();

  bool _isLoading = true;
  String _statusMessage = 'データ準備中...';
  List<HistoricalMatchModel> _results = [];
  // 予想データの分析結果を保持するマップ (Key: horseId)
  Map<String, HistoricalMatchModel> _predictionResultMap = {};
  TrendSummary? _summary;
  String? _errorMessage;

  // 類似度分析の結果保持用
  Map<String, List<SimilarityData>> _similarityAllMatches = {};
  Map<String, SimilarityData?> _similarityBestFirstPlace = {};

  // シミュレーション条件の排他選択
  String _selectedPace = 'average'; // 'average', 'S', 'M', 'H'
  String _selectedTrackCondition = 'average'; // 'average', 'high', 'standard', 'low'
  bool _isDirt = false; // 芝かダートかの判定用

  // ペースシミュレーション結果保持用
  Map<String, RelativeEvaluationResult> _relativeBattleResults = {};

  // 馬場状態の過去傾向データ保持用 (動的ラベル生成に使用)
  TrackConditionTrendResult? _trackConditionTrendResult;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  // [追加] horseIdから今回の馬番を引く。見つからない場合は0を返す (v.2026.9.5+26090506)
  int _getHorseNumber(String horseId) {
    for (final horse in widget.horses) {
      if (horse.horseId == horseId) return horse.horseNumber;
    }
    return 0;
  }

  Future<void> _startAnalysis() async {
    try {
      if (mounted) setState(() => _statusMessage = '詳細データを収集中...');

      // 1. 今回の出走馬の履歴を取得
      final Map<String, List<HorseRaceRecord>> currentHorseHistory = {};
      for (final horse in widget.horses) {
        final records = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
        currentHorseHistory[horse.horseId] = records;
      }

      // 2. 過去レース情報を取得（比較対象のレース群）
      List<RaceResult> pastRaces;
      if (widget.targetRaceIds != null && widget.targetRaceIds!.isNotEmpty) {
        final resultsMap = await _raceRepo.getMultipleRaceResults(widget.targetRaceIds!);
        pastRaces = resultsMap.values.toList();
      } else {
        pastRaces = await _raceRepo.searchRaceResultsByName(widget.raceName);
      }

      // データがない場合の早期リターン
      if (pastRaces.isEmpty) {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 3. 過去レースの全出走馬の履歴を取得
      // [修正] 全出走馬の取得と読み込み Step3: 1〜3着だけでなく全出走馬（取消・除外を除く）の履歴を読む（類似馬のローテ比較を路線に揃える A-6 で使う）。
      // [修正] 総合シンクロ率と血統クロス Step3: 類似馬のローテ比較は全出走馬の前走を路線で比べる。1〜3着の馬の履歴（pastTopHorseRecords）は結果分析の前走の平均人気に使う (v.2026.10.16+26101616)
      setState(() => _statusMessage = '過去の好走パターンを分析中...');
      final Map<String, List<HorseRaceRecord>> pastHorseRecords = {};
      for (final horseId in pastRaceHorseIds(pastRaces)) {
        pastHorseRecords[horseId] = await _horseRepo.getHorsePerformanceRecords(horseId);
      }
      final Map<String, List<HorseRaceRecord>> pastTopHorseRecords = {
        for (final horseId in pastTopFinisherHorseIds(pastRaces))
          horseId: pastHorseRecords[horseId] ?? const <HorseRaceRecord>[],
      };

      // 4. 類似度分析ロジックの実行
      final Map<String, List<SimilarityData>> tempSimilarityAllMatches = {};
      final Map<String, SimilarityData?> tempSimilarityBestFirstPlace = {};

      // 基準日を「対象レースの開催日」にする
      String targetRaceDateStr;

      // まず出馬表キャッシュ(ShutubaTableCache)から芝・ダート判定を取得する
      final targetCache = await _shutubaTableCacheRepository.getShutubaTableCache(widget.raceId);
      if (targetCache != null) {
        _isDirt = targetCache.predictionRaceData.trackType?.contains('ダ') ?? false;
      }

      // 日付の取得: まず結果データ(RaceResult)から探し、無ければキャッシュから探す
      final targetResult = await _raceRepo.getRaceResult(widget.raceId);
      // [修正] 全出走馬の取得と読み込み Step3: レース結果の日付が空・読めないとき（実データで2件）は、出馬表の日付を使う (v.2026.10.16+26101610)
      if (targetResult != null &&
          parseRaceDateForSpeedIndex(targetResult.raceDate) != null) {
        targetRaceDateStr = targetResult.raceDate;
      } else if (targetCache != null) {
        targetRaceDateStr = targetCache.predictionRaceData.raceDate;
      } else {
        // それでもなければ（稀なケース）、今日の日付をフォールバックとして使う
        targetRaceDateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());
      }

      // [追加] 全出走馬の取得と読み込み Step3: 今回の馬の過去走を、今回のレース日より前の走だけにする（そのレース自身の行も除く）。
      // 結果のあるレースでは、そのレース自身の結果が人気妙味・馬場・相対評価（ペース）の計算に入っていた。類似馬の前走は前から日付で決めているので変わらない (v.2026.10.16+26101610)
      final targetRaceDay = parseRaceDateForSpeedIndex(targetRaceDateStr);
      if (targetRaceDay != null) {
        currentHorseHistory.updateAll((horseId, records) => filterRecordsBeforeAsOf(
              records,
              asOf: targetRaceDay,
              excludeRaceId: widget.raceId,
            ));
      }

      // [追加] 総合シンクロ率と血統クロス Step3: 類似馬のローテ比較のため、今回の馬（今回のレース日が基準）と過去の全出走馬（その過去レースの日付が基準）の前走を先に1回だけ決め、
      // まとめて路線（RaceRouteIndex。過去分析のローテの表と同じまとめ方）に分ける。過去の馬のキーは「レースID|馬ID」（同じ馬が別の年に出ていれば年ごとに前走が違う） (v.2026.10.16+26101616)
      final Map<String, HorseRaceRecord?> curPrevRecords = {
        for (final horse in widget.horses)
          horse.horseId: _getPreviousRecord(currentHorseHistory[horse.horseId], targetRaceDateStr),
      };
      final Map<String, HorseRaceRecord?> pastPrevRecords = {};
      for (final race in pastRaces) {
        for (final pastHorse in race.horseResults) {
          pastPrevRecords['${race.raceId}|${pastHorse.horseId}'] =
              _getPreviousRecord(pastHorseRecords[pastHorse.horseId], race.raceDate);
        }
      }
      final routeIndex = RaceRouteIndex.build([
        for (final record in pastPrevRecords.values)
          if (record != null) record,
        for (final record in curPrevRecords.values)
          if (record != null) record,
      ]);
      String? routeIdOf(HorseRaceRecord? record) =>
          record == null ? null : routeIndex.routeOf(record)?.id;

      for (final currentHorse in widget.horses) {
        List<SimilarityData> matches = [];
        SimilarityData? bestFirstPlaceMatch;
        double bestFirstPlaceScore = -1.0;

        // 今回の馬の前走の路線（対象レースの日付を基準にする）
        // [修正] 総合シンクロ率と血統クロス Step3: 前走のレース名ではなく、前走の路線のIDで比べる (v.2026.10.16+26101616)
        final curRouteId = routeIdOf(curPrevRecords[currentHorse.horseId]);

        for (final race in pastRaces) {
          for (final pastHorse in race.horseResults) {
            // 過去馬の前走の路線（その過去レースの日付を基準にする）
            // [修正] 総合シンクロ率と血統クロス Step3: 1〜3着の馬だけでなく全出走馬の前走を使う（取消・除外の馬は戦績を読んでいないので前走なし） (v.2026.10.16+26101616)
            final pastRouteId = routeIdOf(pastPrevRecords['${race.raceId}|${pastHorse.horseId}']);

            // 類似度計算
            final score = _calculateSimilarity(
              currentHorse,
              pastHorse,
              curRouteId,
              pastRouteId,
            );

            // 1着馬の中でベストスコアを探す
            if (pastHorse.rank == '1') {
              if (score > bestFirstPlaceScore) {
                bestFirstPlaceScore = score;
                bestFirstPlaceMatch = SimilarityData(
                  horseName: pastHorse.horseName,
                  similarity: score,
                  rank: pastHorse.rank,
                  popularity: pastHorse.popularity,
                  raceName: race.raceTitle,
                  raceDate: race.raceDate,
                );
              }
            }

            // 50%以上ならリストに追加
            if (score >= 50.0) {
              matches.add(SimilarityData(
                horseName: pastHorse.horseName,
                similarity: score,
                rank: pastHorse.rank,
                popularity: pastHorse.popularity,
                raceName: race.raceTitle,
                raceDate: race.raceDate,
              ));
            }
          }
        }

        // 類似度順にソート
        matches.sort((a, b) => b.similarity.compareTo(a.similarity));

        tempSimilarityAllMatches[currentHorse.horseId] = matches;

        if (bestFirstPlaceScore < 50.0) {
          tempSimilarityBestFirstPlace[currentHorse.horseId] = null;
        } else {
          tempSimilarityBestFirstPlace[currentHorse.horseId] = bestFirstPlaceMatch;
        }
      }

      final volatilityAnalyzer = VolatilityAnalyzer();
      final volResult = volatilityAnalyzer.analyze(pastRaces);

      // --- 血統と馬場データの取得・集計 ---
      final tcRepo = TrackConditionRepository();
      final Map<String, TrackConditionRecord> trackConditionMap = {};
      for (final race in pastRaces) {
        if (race.raceId.length >= 10) {
          // [修正] 先頭10桁一致ではなく競馬場コード＋開催日で照合 (v.2026.9.19+26091901)
          final tc = await tcRepo.getTrackConditionForRace(
            raceId: race.raceId,
            raceDate: race.raceDate,
          );
          if (tc != null) trackConditionMap[race.raceId] = tc;
        }
      }

      final Map<String, HorseProfile> horseProfileMap = {};
      // 今回の出走馬のプロフィール
      for (final horse in widget.horses) {
        final profile = await _horseRepo.getHorseProfile(horse.horseId);
        if (profile != null) horseProfileMap[horse.horseId] = profile;
      }
      // 比較用ターゲットがあればそれも
      if (widget.comparisonTargets != null) {
        for (final horse in widget.comparisonTargets!) {
          final profile = await _horseRepo.getHorseProfile(horse.horseId);
          if (profile != null) horseProfileMap[horse.horseId] = profile;
        }
      }
      // 過去上位馬のプロフィール
      // [修正] 総合シンクロ率と血統クロス Step2: 1〜3着の馬だけでなく、過去レースの全出走馬（取消・除外を除く）の血統を読む（血統の点数を父・母父ごとの倍率で出すため） (v.2026.10.16+26101615)
      for (final horseId in pastRaceHorseIds(pastRaces)) {
        if (horseProfileMap.containsKey(horseId)) continue;
        final profile = await _horseRepo.getHorseProfile(horseId);
        if (profile != null) horseProfileMap[horseId] = profile;
      }

      // 新しいアナライザーの実行
      final trackConditionTrendResult = TrackConditionTrendAnalyzer().analyze(trackConditionMap);
      _trackConditionTrendResult = trackConditionTrendResult; // ★状態変数に保持
      // [削除] 総合シンクロ率と血統クロス Step2: 血統クロスの集計（PedigreeCrossAnalyzer）は結果分析の点数に使わなくなったので削除した (v.2026.10.16+26101615)

      // 出走馬の過去レースの馬場データを一括取得
      final Map<String, TrackConditionRecord> horsePastTrackConditions = {};
      for (final records in currentHorseHistory.values) {
        for (final rec in records) {
          if (rec.raceId.length >= 10 && !horsePastTrackConditions.containsKey(rec.raceId)) {
            // [修正] 先頭10桁一致ではなく競馬場コード＋開催日で照合 (v.2026.9.19+26091901)
            final tc = await tcRepo.getTrackConditionForRace(
              raceId: rec.raceId,
              raceDate: rec.date,
            );
            if (tc != null) {
              horsePastTrackConditions[rec.raceId] = tc;
            }
          }
        }
      }

      // ペース別シミュレーションの実行 (RelativeBattleCalculator)
      final relativeCalculator = RelativeBattleCalculator();
      final relResults = relativeCalculator.runSimulation(
        widget.horses,
        horsePerformanceMap: currentHorseHistory,
      );
      _relativeBattleResults = {for (var r in relResults) r.horseId: r};

      // 5. HistoricalMatchEngineによる分析 (引数に上記データを追加)
      final analysisResult = _engine.analyze(
        currentRaceName: widget.raceName,
        currentRaceClass: widget.currentRaceClass,
        // [追加] 前走と路線の部品 Step2: 今回の馬の前走を決める基準日 (v.2026.10.16+26101606)
        currentRaceDate: targetRaceDateStr,
        pastRaceVolatility: volResult.averagePopularity,
        currentHorses: widget.horses,
        pastRaces: pastRaces,
        currentHorseHistory: currentHorseHistory,
        pastTopHorseRecords: pastTopHorseRecords,
        // [修正] 総合シンクロ率と血統クロス Step2: ローテ・血統の点数を倍率で出すため全出走馬の戦績を渡す。血統クロスの結果は渡さなくなった (v.2026.10.16+26101615)
        pastHorseRecords: pastHorseRecords,
        horseProfileMap: horseProfileMap,
        trackConditionTrendResult: _trackConditionTrendResult!,
        horsePastTrackConditions: horsePastTrackConditions,
        isDirt: _isDirt,
      );

      // 比較対象(予想データ)の分析 (こちらにも引数を追加)
      if (widget.comparisonTargets != null && widget.comparisonTargets!.isNotEmpty) {
        final predictionAnalysis = _engine.analyze(
          currentRaceName: widget.raceName,
          currentRaceClass: widget.currentRaceClass,
          // [追加] 前走と路線の部品 Step2: 今回の馬の前走を決める基準日 (v.2026.10.16+26101606)
          currentRaceDate: targetRaceDateStr,
          pastRaceVolatility: volResult.averagePopularity,
          currentHorses: widget.comparisonTargets!,
          pastRaces: pastRaces,
          currentHorseHistory: currentHorseHistory,
          pastTopHorseRecords: pastTopHorseRecords,
          // [修正] 総合シンクロ率と血統クロス Step2: 1つ目の呼び出しと同じく全出走馬の戦績を渡す (v.2026.10.16+26101615)
          pastHorseRecords: pastHorseRecords,
          horseProfileMap: horseProfileMap,
          trackConditionTrendResult: _trackConditionTrendResult!,
          horsePastTrackConditions: horsePastTrackConditions,
          isDirt: _isDirt,
        );
        final predList = predictionAnalysis['results'] as List<HistoricalMatchModel>;
        _predictionResultMap = {for (var e in predList) e.horseId: e};
      } else {
        _predictionResultMap.clear();
      }

      if (mounted) {
        setState(() {
          _results = analysisResult['results'] as List<HistoricalMatchModel>;
          _summary = analysisResult['summary'] as TrendSummary?;
          _similarityAllMatches = tempSimilarityAllMatches;
          _similarityBestFirstPlace = tempSimilarityBestFirstPlace;
          _isLoading = false;
          _sortResults(); // 分析完了後に動的スコアでソート
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '分析中にエラーが発生しました:\n$e';
        });
      }
    }
  }

  /// 類似度計算メソッド
  /// 要素: 性齢, 馬体重, 斤量, ローテーション(レース名一致)
  // [修正] 総合シンクロ率と血統クロス Step3: ローテーションは前走の路線のIDが同じかどうか（前走名の部分一致はやめた）。どちらかの前走が分からなければ比べない (v.2026.10.16+26101616)
  double _calculateSimilarity(
      PredictionHorseDetail current,
      HorseResult past,
      String? curRouteId,
      String? pastRouteId,
      ) {
    double totalScore = 0;
    int count = 0;

    // 1. 性齢
    final curSex = current.sexAndAge.isNotEmpty ? current.sexAndAge.substring(0, 1) : '';
    final pastSex = past.sexAndAge.isNotEmpty ? past.sexAndAge.substring(0, 1) : '';
    if (curSex.isNotEmpty && pastSex.isNotEmpty) {
      if (curSex == pastSex) totalScore += 100;
      count++;
    }

    final curAge = int.tryParse(current.sexAndAge.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final pastAge = int.tryParse(past.sexAndAge.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (curAge > 0 && pastAge > 0) {
      final diff = (curAge - pastAge).abs();
      double score = 0;
      if (diff == 0) score = 100;
      else if (diff == 1) score = 80;
      else if (diff == 2) score = 50;
      totalScore += score;
      count++;
    }

    // 2. 馬体重
    final curWeightStr = current.horseWeight?.split('(').first ?? '';
    final pastWeightStr = past.horseWeight.split('(').first;
    final curWeight = int.tryParse(curWeightStr) ?? 0;
    final pastWeight = int.tryParse(pastWeightStr) ?? 0;
    if (curWeight > 0 && pastWeight > 0) {
      final diff = (curWeight - pastWeight).abs();
      double score = 100 - (diff * 2.5);
      totalScore += score < 0 ? 0 : score;
      count++;
    }

    // 3. 斤量
    final pastCarried = double.tryParse(past.weightCarried) ?? 0.0;
    if (current.carriedWeight > 0 && pastCarried > 0) {
      final diff = (current.carriedWeight - pastCarried).abs();
      double score = 100 - (diff * 15);
      totalScore += score < 0 ? 0 : score;
      count++;
    }

    // 4. ローテーション (前走の路線)
    if (curRouteId != null && pastRouteId != null) {
      // 同じ路線か
      if (curRouteId == pastRouteId) {
        totalScore += 100;
      } else {
        totalScore += 0;
      }
      count++;
    }

    if (count == 0) return 0.0;
    return totalScore / count;
  }

  // --- 動的スコアの計算とソート ---
  double _calculateDynamicScore(HistoricalMatchModel item) {
    // 1. ペーススコアの取得 (RelativeBattleCalculatorのシミュレーション勝率を100点満点に変換)
    double paceScore = 0.0;
    if (_selectedPace != 'average') {
      final relResult = _relativeBattleResults[item.horseId];
      if (relResult != null) {
        RacePace targetPace;
        if (_selectedPace == 'S') targetPace = RacePace.slow;
        else if (_selectedPace == 'H') targetPace = RacePace.high;
        else targetPace = RacePace.middle;

        // 指定ペースの勝率(0.0~1.0)を100倍してスコア化
        final winRate = relResult.scenarioWinRates[targetPace] ?? 0.0;
        paceScore = winRate * 100.0;
      }
    }

    // 2. 馬場シナリオスコアの取得
    double trackScore = 0.0;
    if (_selectedTrackCondition != 'average') {
      trackScore = item.trackConditionScores[_selectedTrackCondition] ?? 0.0;
    }

    // 3. 総合スコアの算出
    if (_selectedTrackCondition == 'average' && _selectedPace == 'average') {
      return item.totalScore;
    } else {
      // ベーススコアの比重調整（条件が追加されるごとにベースの比重を減らす）
      double baseWeight = 1.0;
      double trackWeight = 0.0;
      double paceWeight = 0.0;

      if (_selectedTrackCondition != 'average') {
        baseWeight -= 0.2;
        trackWeight = 0.2;
      }
      if (_selectedPace != 'average') {
        baseWeight -= 0.2;
        paceWeight = 0.2;
      }

      // ベーススコア + 馬場スコア + ペーススコア
      return (item.totalScore * baseWeight) + (trackScore * trackWeight) + (paceScore * paceWeight);
    }
  }

  void _sortResults() {
    _results.sort((a, b) => _calculateDynamicScore(b).compareTo(_calculateDynamicScore(a)));
  }

  String _getTrackConditionLabel(String condition) {
    if (condition == 'average') return '過去平均';
    if (!_isDirt) {
      final avg = _trackConditionTrendResult?.avgCushion ?? 9.5;
      if (condition == 'high') return '(${(avg + 0.3).toStringAsFixed(1)}以上)';
      if (condition == 'standard') return '(標:${avg.toStringAsFixed(1)})';
      if (condition == 'low') return '(${(avg - 0.3).toStringAsFixed(1)}以下)';
    } else {
      final avg = _trackConditionTrendResult?.avgDirtMoisture ?? 8.0;
      if (condition == 'low') return '含水率(${(avg >= 2.0 ? avg - 2.0 : 0).toStringAsFixed(1)}%以下)';
      if (condition == 'standard') return '含水率(標:${avg.toStringAsFixed(1)}%)';
      if (condition == 'high') return '含水率(${(avg + 2.0).toStringAsFixed(1)}%以上)';
    }
    return '';
  }

  String _getShortTrackConditionLabel(String condition) {
    if (condition == 'average') return '過去平均';
    if (!_isDirt) {
      if (condition == 'high') return '硬(高速)';
      if (condition == 'standard') return '標準';
      if (condition == 'low') return '軟(時計掛)';
    } else {
      if (condition == 'low') return '乾燥(良)';
      if (condition == 'standard') return '標準';
      if (condition == 'high') return '湿潤(重/不)';
    }
    return '';
  }

  Widget _buildSimulationOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("ペース: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4.0,
                  children: [
                    _buildChoiceChip('過去平均', 'average', _selectedPace, (val) => setState(() { _selectedPace = val; _sortResults(); })),
                    _buildChoiceChip('S', 'S', _selectedPace, (val) => setState(() { _selectedPace = val; _sortResults(); })),
                    _buildChoiceChip('M', 'M', _selectedPace, (val) => setState(() { _selectedPace = val; _sortResults(); })),
                    _buildChoiceChip('H', 'H', _selectedPace, (val) => setState(() { _selectedPace = val; _sortResults(); })),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text("クッション値: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4.0,
                  children: [
                    _buildChoiceChip('過去平均', 'average', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                    if (!_isDirt) ...[
                      _buildChoiceChip(_getTrackConditionLabel('high'), 'high', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                      _buildChoiceChip(_getTrackConditionLabel('standard'), 'standard', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                      _buildChoiceChip(_getTrackConditionLabel('low'), 'low', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                    ] else ...[
                      _buildChoiceChip(_getTrackConditionLabel('low'), 'low', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                      _buildChoiceChip(_getTrackConditionLabel('standard'), 'standard', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                      _buildChoiceChip(_getTrackConditionLabel('high'), 'high', _selectedTrackCondition, (val) => setState(() { _selectedTrackCondition = val; _sortResults(); })),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String groupValue, Function(String) onSelected) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: groupValue == value,
      onSelected: (selected) {
        if (selected) onSelected(value);
      },
      visualDensity: VisualDensity.compact,
    );
  }
  // ---------------------------------------------

  /// 指定された基準日より「前」の最新のレース名を取得
  // [修正] 前走と路線の部品 Step2: 共通の部品 previousStartOf で決める（取消・除外・着順が空欄の行を飛ばす）。日付は共通の parseRaceDateForSpeedIndex で読み、読めなければ従来どおり null。自前の日付の読み取りは削除 (v.2026.10.16+26101606)
  // [修正] 総合シンクロ率と血統クロス Step3: 路線にまとめるため、レース名ではなく前走の走そのものを返す (v.2026.10.16+26101616)
  HorseRaceRecord? _getPreviousRecord(List<HorseRaceRecord>? history, String referenceDateStr) {
    final referenceDate = parseRaceDateForSpeedIndex(referenceDateStr);
    if (referenceDate == null) return null;
    return previousStartOf(history, referenceDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
      ]));
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('該当する過去レースデータがありませんでした。'));
    }

    return Column(
      children: [
        if (_summary != null) _buildTrendHeader(_summary!),

        // シミュレーション条件の排他選択UI
        _buildSimulationOptions(),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildResultTable(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendHeader(TrendSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('【過去の傾向分析】', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _headerItem(Icons.monitor_weight_outlined, '基準:${summary.medianWeight.toStringAsFixed(0)}kg'),
              _headerItem(Icons.view_column_outlined, '有利:${summary.bestZone}'),
              _headerItem(Icons.loop, 'ローテ:${summary.bestRotation}'),
              _headerItem(Icons.trending_up, '前走人気:${summary.bestPrevPop}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultTable() {
    double maxScore = 0.0;
    if (_results.isNotEmpty) {
      maxScore = _results.map((e) => _calculateDynamicScore(e)).reduce((a, b) => a > b ? a : b);
    }

    final isComparisonMode = widget.comparisonTargets != null;

    return DataTable(
      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
      columnSpacing: 16,
      columns: [
        if (isComparisonMode) const DataColumn(label: Text('着順/印')),
        const DataColumn(label: Text('馬番/馬名')),
        const DataColumn(label: Text('類似馬(1着)')),
        const DataColumn(label: Text('総合ｼﾝｸﾛ')),

        // 選択されたペースシナリオの個別スコア列
        if (_selectedPace != 'average')
          DataColumn(label: Text('$_selectedPaceペース', style: const TextStyle(color: Colors.red))),

        // 選択された馬場シナリオの個別スコア列
        if (_selectedTrackCondition != 'average')
          DataColumn(label: Text(_getShortTrackConditionLabel(_selectedTrackCondition), style: const TextStyle(color: Colors.indigo))),
        const DataColumn(label: Text('血統')),
        const DataColumn(label: Text('人気妙味')),
        // [修正] 総合シンクロ率と血統クロス Step2: 中身（前走の路線の倍率）に合わせて列名を「信頼度(格)」から「ローテ」にした (v.2026.10.16+26101615)
        const DataColumn(label: Text('ローテ')),
        const DataColumn(label: Text('馬体重')),
        const DataColumn(label: Text('枠順')),
      ],
      rows: _results.map((item) {
        final predictionItem = _predictionResultMap[item.horseId];
        final dynamicScore = _calculateDynamicScore(item);
        final predictionDynamicScore = predictionItem != null ? _calculateDynamicScore(predictionItem) : null;

        // 行ごとのペーススコア計算
        double paceScore = 0.0;
        if (_selectedPace != 'average') {
          final relResult = _relativeBattleResults[item.horseId];
          if (relResult != null) {
            RacePace targetPace = _selectedPace == 'S' ? RacePace.slow : (_selectedPace == 'H' ? RacePace.high : RacePace.middle);
            paceScore = (relResult.scenarioWinRates[targetPace] ?? 0.0) * 100.0;
          }
        }

        String? userMark;
        if (isComparisonMode && widget.comparisonTargets != null) {
          final target = widget.comparisonTargets!.firstWhere(
                  (h) => h.horseId == item.horseId,
              orElse: () => widget.comparisonTargets![0]
          );
          if (target.horseId == item.horseId) {
            userMark = target.userMark?.mark;
          }
        }

        String? rankStr;
        if (isComparisonMode) {
          final currentHorse = widget.horses.firstWhere((h) => h.horseId == item.horseId, orElse: () => widget.horses[0]);
          if (currentHorse.horseId == item.horseId) {
            rankStr = currentHorse.popularity != null ? '${currentHorse.popularity}着' : '-';
          }
        }

        return DataRow(cells: [
          if (isComparisonMode)
            DataCell(Row(
              children: [
                if (rankStr != null) Text(rankStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                if (userMark != null)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _getMarkColor(userMark)),
                    child: Text(userMark, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            )),
          // [追加] 馬名の前に枠色付きの馬番を表示 (v.2026.9.5+26090506)
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HorseNumberBadge(
                horseNumber: _getHorseNumber(item.horseId),
                gateNumber: item.gateNumber,
                size: 22.0,
              ),
              const SizedBox(width: 6),
              Text(item.horseName, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          )),
          DataCell(_buildSimilarityCell(item.horseId, item.horseName)),
          DataCell(_buildTotalScoreCell(dynamicScore, maxScore, predictionDynamicScore)),

          // 選択されたペースシナリオの個別スコアセル
          if (_selectedPace != 'average')
            DataCell(_buildScenarioScoreCell(paceScore)),

          // 選択された馬場シナリオの個別スコアセル
          if (_selectedTrackCondition != 'average')
            DataCell(_buildScenarioScoreCell(item.trackConditionScores[_selectedTrackCondition] ?? 0.0)),

          DataCell(_buildPedigreeCell(item)),

          DataCell(InkWell(
            onTap: () => _showPopularityDetailDialog(context, item),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), child: _buildPopularityCell(item)),
          )),
          DataCell(_buildRotationCell(item)),
          DataCell(_buildWeightDetailCell(item, predictionItem)),
          DataCell(_buildFrameDetailCell(item)),
        ]);
      }).toList(),
    );
  }

  // シナリオ別スコアの描画
  Widget _buildScenarioScoreCell(double score) {
    Color color;
    String rank;
    if (score >= 90) { rank = 'S'; color = Colors.red; }
    else if (score >= 80) { rank = 'A'; color = Colors.deepOrange; }
    else if (score >= 70) { rank = 'B'; color = Colors.orange; }
    else if (score >= 60) { rank = 'C'; color = Colors.amber.shade700; }
    else if (score >= 50) { rank = 'D'; color = Colors.blue; }
    else { rank = 'E'; color = Colors.grey; }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${score.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        const SizedBox(width: 4),
        Container(width: 16, height: 16, alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
      ],
    );
  }

  // 血統スコアの描画
  Widget _buildPedigreeCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.pedigreeScore >= 80) color = Colors.red;
    else if (item.pedigreeScore >= 60) color = Colors.orange[800]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${item.pedigreeScore.toStringAsFixed(0)}点', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(item.pedigreeDiag, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // 類似馬セル構築
  Widget _buildSimilarityCell(String horseId, String horseName) {
    final bestMatch = _similarityBestFirstPlace[horseId];

    // 50%以上の1着馬がいない場合
    if (bestMatch == null) {
      return InkWell(
        onTap: () => _showSimilarityDetailDialog(context, horseName, horseId),
        child: const Text('該当なし', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return InkWell(
      onTap: () => _showSimilarityDetailDialog(context, horseName, horseId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(bestMatch.horseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
          Text('類似度:${bestMatch.similarity.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  // 類似度詳細ダイアログ
  void _showSimilarityDetailDialog(BuildContext context, String horseName, String horseId) {
    final matches = _similarityAllMatches[horseId] ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$horseName の類似馬分析\n(類似度50%以上)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: matches.isEmpty
                ? const Center(child: Text('条件を満たす類似馬はいませんでした。'))
                : ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final data = matches[index];
                final isFirst = data.rank == '1';

                return Card(
                  color: isFirst ? Colors.yellow.shade50 : null,
                  child: ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Text(data.horseName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${data.similarity.toStringAsFixed(0)}%', style: TextStyle(
                            color: data.similarity >= 80 ? Colors.red : Colors.blue,
                            fontWeight: FontWeight.bold
                        )),
                      ],
                    ),
                    subtitle: Text(
                      '${data.raceName} (${data.raceDate.split('年').first})\n'
                          '${data.popularity}番人気 → ${data.rank}着',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isFirst ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          ],
        );
      },
    );
  }

  // 印の色ヘルパー
  Color _getMarkColor(String mark) {
    switch (mark) {
      case '◎': return Colors.red;
      case '○': return Colors.blue;
      case '▲': return Colors.green;
      case '△': return Colors.orange;
      case '☆': return Colors.yellow[700]!;
      default: return Colors.grey;
    }
  }

  // --- 既存のセル構築メソッド ---
  Widget _buildRotationCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.rotationScore >= 90) color = Colors.red;
    else if (item.rotationScore >= 80) color = Colors.orange[800]!;
    // [修正] 総合シンクロ率と血統クロス Step2: 下の行は前走名ではなく前走の路線名（過去分析のローテの表と同じ表示名）。上の行は倍率の文字（rotDiagnosis） (v.2026.10.16+26101615)
    String raceName = item.rotationRouteLabel;
    if (raceName.length > 8) raceName = '${raceName.substring(0, 7)}...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(item.rotDiagnosis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(raceName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTotalScoreCell(double score, double maxScore, [double? prevScore]) {
    Color color;
    String rank;
    if (score >= maxScore && score > 0) { rank = 'S'; color = Colors.red; }
    else if (score >= 90) { rank = 'A'; color = Colors.deepOrange; }
    else if (score >= 80) { rank = 'B'; color = Colors.orange; }
    else if (score >= 70) { rank = 'C'; color = Colors.amber.shade700; }
    else if (score >= 60) { rank = 'D'; color = Colors.blue; }
    else if (score >= 50) { rank = 'E'; color = Colors.indigo; }
    else { rank = 'F'; color = Colors.grey; }

    // 差分計算
    String? diffStr;
    Color diffColor = Colors.grey;
    if (prevScore != null) {
      final diff = score - prevScore;
      if (diff != 0) {
        diffStr = diff > 0 ? '(+${diff.toStringAsFixed(0)})' : '(${diff.toStringAsFixed(0)})';
        diffColor = diff > 0 ? Colors.red : Colors.blue;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${score.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            if (diffStr != null)
              Text(diffStr, style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(width: 8),
        Container(width: 24, height: 20, alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildWeightDetailCell(HistoricalMatchModel item, [HistoricalMatchModel? prevItem]) {
    final diff = item.weightDiff;
    Color color = Colors.black;
    if (item.weightScore >= 90) color = Colors.red;
    else if (item.weightScore >= 80) color = Colors.orange[800]!;

    // スコア差分
    String? scoreDiffStr;
    if (prevItem != null) {
      final sd = item.weightScore - prevItem.weightScore;
      if (sd != 0) {
        scoreDiffStr = sd > 0 ? '+${sd.toStringAsFixed(0)}' : '${sd.toStringAsFixed(0)}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            SizedBox(width: 40, child: Text('${item.weightScore.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
            if (scoreDiffStr != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text('($scoreDiffStr)', style: TextStyle(fontSize: 10, color: (double.tryParse(scoreDiffStr) ?? 0) > 0 ? Colors.red : Colors.blue)),
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.weightStr.split(' ')[0], style: TextStyle(color: item.isWeightCurrent ? Colors.black87 : Colors.grey, fontSize: 12)),
            if (!item.isWeightCurrent) const Text('(前)', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(' 差:${diff.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildFrameDetailCell(HistoricalMatchModel item) {
    if (item.gateNumber == 0) return const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 40, child: Text('--', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))), Text('未発表', style: TextStyle(fontSize: 11, color: Colors.grey))]);
    Color color = Colors.black;
    if (item.frameScore >= 90) color = Colors.red;
    else if (item.frameScore >= 70) color = Colors.orange[800]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 40, child: Text('${item.frameScore.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
        // [修正] 結果分析の枠順: 括弧内は枠番ではなく馬番を出す（ゾーンの判定を馬番にしたため） (v.2026.10.15+26101513)
        Row(mainAxisSize: MainAxisSize.min, children: [Text('${item.positionZone}目', style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), Text('(${_getHorseNumber(item.horseId)}番)', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
      ],
    );
  }

  // 人気妙味セルのロジック
  Widget _buildPopularityCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.popularityScore >= 90) color = Colors.red;
    else if (item.popularityScore <= 40) color = Colors.blue;

    return Row(
      children: [
        Text(item.popDiagnosis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 4),
        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
      ],
    );
  }

  // 人気詳細ダイアログ
  void _showPopularityDetailDialog(BuildContext context, HistoricalMatchModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // [追加] ダイアログタイトルにも馬番を表示 (v.2026.9.5+26090506)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HorseNumberBadge(
                    horseNumber: _getHorseNumber(item.horseId),
                    gateNumber: item.gateNumber,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(item.horseName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '累積指数: ${item.valueIndex >= 0 ? "+" : ""}${item.valueIndex.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.psychology, size: 16, color: Colors.blue), SizedBox(width: 4), Text('AI診断', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                      const SizedBox(height: 4),
                      Text(item.valueReasoning, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('▼ 過去レース分析 (人気 vs 着順)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const Divider(),
                Expanded(
                  child: item.recentHistory.isEmpty
                      ? const Center(child: Text('過去データがありません'))
                      : ListView.builder(
                    itemCount: item.recentHistory.length,
                    itemBuilder: (context, index) {
                      final rec = item.recentHistory[index];
                      final pop = int.tryParse(rec.popularity) ?? 0;
                      final rank = int.tryParse(rec.rank) ?? 0;
                      if (pop == 0 || rank == 0) return const SizedBox.shrink();

                      final diff = pop - rank;
                      IconData icon;
                      Color color;

                      if (diff >= 5) { icon = Icons.arrow_upward; color = Colors.red; }
                      else if (diff >= 1) { icon = Icons.north_east; color = Colors.orange; }
                      else if (diff == 0) { icon = Icons.arrow_forward; color = Colors.grey; }
                      else if (diff >= -3) { icon = Icons.south_east; color = Colors.blue; }
                      else { icon = Icons.arrow_downward; color = Colors.blue[900]!; }

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text(rec.date.split('/').sublist(1).join('/'), style: const TextStyle(fontSize: 10))],
                        ),
                        title: Text(rec.raceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${rec.popularity}人 → ${rec.rank}着', style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(diff > 0 ? '+${diff}Gap' : '${diff}Gap', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Icon(icon, color: color),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          ],
        );
      },
    );
  }
}