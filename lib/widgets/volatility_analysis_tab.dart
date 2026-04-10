// lib/widgets/volatility_analysis_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/cross_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/pedigree_cross_analysis_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/track_condition_trend_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/volatility_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/past_top_horses_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/payout_comparison_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/popularity_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/frame_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/leg_style_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/horse_weight_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/lap_time_chart_card.dart';
import 'package:hetaumakeiba_v2/services/horse_profile_scraper_service.dart';

class VolatilityAnalysisTab extends StatefulWidget {
  final List<String> targetRaceIds;

  const VolatilityAnalysisTab({Key? key, required this.targetRaceIds})
      : super(key: key);

  @override
  State<VolatilityAnalysisTab> createState() => _VolatilityAnalysisTabState();
}

class _VolatilityAnalysisTabState extends State<VolatilityAnalysisTab> {
  final RaceRepository _raceRepo = RaceRepository();
  final HorseRepository _horseRepo = HorseRepository();
  final VolatilityAnalyzer _analyzer = VolatilityAnalyzer();
  bool _isLoading = true;

  VolatilityResult? _volatilityResult;
  PayoutAnalysisResult? _payoutResult;
  PopularityAnalysisResult? _popularityResult;
  FrameAnalysisResult? _frameResult;
  LegStyleAnalysisResult? _legStyleResult;
  HorseWeightAnalysisResult? _horseWeightResult;
  LapTimeAnalysisResult? _lapTimeResult;

  // 新機能の解析結果を保持する変数
  TrackConditionTrendResult? _trackConditionTrendResult;
  CrossAnalysisResult? _pedigreeCrossResult;

  // 過去の上位3頭と馬場状態を保持する変数
  List<PastRaceTop3Result>? _pastTop3Result;
  final Map<String, TrackConditionRecord> _trackConditionMap = {};

  // 血統情報取得のローディング状態と進捗を管理
  bool _isFetchingPedigree = false;
  int _currentPedigreeFetchCount = 0;
  int _totalPedigreeToFetch = 0;

  int _totalTargetHorseCount = 0;
  int _missingPedigreeCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyze();
  }

  Future<void> _fetchAndAnalyze() async {
    List<RaceResult> pastRaces = [];
    final tcRepo = TrackConditionRepository();

    for (String id in widget.targetRaceIds) {
      final race = await _raceRepo.getRaceResult(id);
      if (race != null) pastRaces.add(race);

      // レースIDから先頭10桁(プレフィックス)を切り出して当日の馬場状態を検索
      if (id.length >= 10) {
        String prefix10 = id.substring(0, 10);
        final tc = await tcRepo.getLatestTrackConditionByPrefix(prefix10);
        if (tc != null) {
          // UI側から呼び出しやすいように、キーは元のレースIDのままMapに保存する
          _trackConditionMap[id] = tc;
        }
      }
    }
    // 過去レースの1〜3着馬のプロフィール（血統）をDBから取得する
    Map<String, HorseProfile> horseProfileMap = {};
    Set<String> targetHorseIds = {};
    int missingCount = 0;

    for (final race in pastRaces) {
      for (final horse in race.horseResults) {
        int rank = int.tryParse(horse.rank ?? '') ?? 0;
        if (rank >= 1 && rank <= 3 && horse.horseId.isNotEmpty) {
          targetHorseIds.add(horse.horseId);
          if (!horseProfileMap.containsKey(horse.horseId)) {
            final profile = await _horseRepo.getHorseProfile(horse.horseId);
            if (profile != null) {
              horseProfileMap[horse.horseId] = profile;
            }
          }
        }
      }
    }

    for (final horseId in targetHorseIds) {
      final profile = horseProfileMap[horseId];
      if (profile == null || profile.fatherName.isEmpty) {
        missingCount++;
      }
    }

    if (mounted) {
      setState(() {
        // 既存の解析
        _volatilityResult = _analyzer.analyze(pastRaces);
        _payoutResult = PayoutAnalyzer().analyze(pastRaces);
        _popularityResult = PopularityAnalyzer().analyze(pastRaces);
        _frameResult = FrameAnalyzer().analyze(pastRaces);
        _legStyleResult = LegStyleAnalyzer().analyze(pastRaces);
        _horseWeightResult = HorseWeightAnalyzer().analyze(pastRaces);
        _pastTop3Result = PastTopHorsesAnalyzer().analyze(pastRaces);
        _lapTimeResult = LapTimeAnalyzer().analyze(pastRaces);

        // 新しいアナライザーの実行
        _trackConditionTrendResult = TrackConditionTrendAnalyzer().analyze(_trackConditionMap);
        _pedigreeCrossResult = PedigreeCrossAnalyzer().analyze(
          pastRaces: pastRaces,
          trackConditionMap: _trackConditionMap,
          horseProfileMap: horseProfileMap,
        );

        _totalTargetHorseCount = targetHorseIds.length;
        _missingPedigreeCount = missingCount;

        _isLoading = false;
      });
    }
  }

  // 不足している血統情報を取得するメソッド
  Future<void> _fetchMissingPedigreeData() async {
    setState(() {
      _isFetchingPedigree = true;
    });

    try {
      // 1. 対象レース群を再取得
      List<RaceResult> pastRaces = [];
      for (String id in widget.targetRaceIds) {
        final race = await _raceRepo.getRaceResult(id);
        if (race != null) pastRaces.add(race);
      }

      // 2. 過去レースの1〜3着馬のIDを収集
      Set<String> targetHorseIds = {};
      for (final race in pastRaces) {
        for (final horse in race.horseResults) {
          int rank = int.tryParse(horse.rank ?? '') ?? 0;
          if (rank >= 1 && rank <= 3 && horse.horseId.isNotEmpty) {
            targetHorseIds.add(horse.horseId);
          }
        }
      }

      // 3. プロフィールが存在しない、または血統(父名)が空の馬をリストアップ
      List<String> horsesToFetch = [];
      for (final horseId in targetHorseIds) {
        final profile = await _horseRepo.getHorseProfile(horseId);
        if (profile == null || profile.fatherName.isEmpty) {
          horsesToFetch.add(horseId);
        }
      }

      if (mounted) {
        setState(() {
          _totalPedigreeToFetch = horsesToFetch.length;
          _currentPedigreeFetchCount = 0;
        });
      }

      // 4. リストアップした馬の情報を1頭ずつ取得し、進捗を更新
      for (final horseId in horsesToFetch) {
        await HorseProfileScraperService.scrapeAndSaveProfile(horseId);
        if (mounted) {
          setState(() {
            _currentPedigreeFetchCount++;
          });
        }
        // サーバー負荷軽減のため、1頭取得するごとに1秒待機
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // 5. データ取得が全て完了したら、再度分析処理を走らせて画面を更新
      await _fetchAndAnalyze();

    } catch (e) {
      print('血統情報の取得中にエラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingPedigree = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_volatilityResult == null) {
      return const Center(child: Text('データの分析に失敗しました。'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 波乱度
          VolatilityCard(res: _volatilityResult!),
          const SizedBox(height: 16),
          // 2. 過去レース上位3頭と馬場状態
          PastTopHorsesCard(pastTop3Result: _pastTop3Result, trackConditionMap: _trackConditionMap),
          const SizedBox(height: 16),
          // 3. 過去の馬場状態の傾向
          if (_trackConditionTrendResult != null) ...[
            TrackConditionTrendCard(result: _trackConditionTrendResult!),
            const SizedBox(height: 16),
          ],
          // 4. 好走血統 × 馬場状態クロス分析
          if (_pedigreeCrossResult != null) ...[
            PedigreeCrossAnalysisCard(
              result: _pedigreeCrossResult!,
              isFetching: _isFetchingPedigree,
              currentFetchCount: _currentPedigreeFetchCount,
              totalFetchCount: _totalPedigreeToFetch,
              missingPedigreeCount: _missingPedigreeCount,
              totalTargetHorseCount: _totalTargetHorseCount,
              onFetchPedigree: _fetchMissingPedigreeData,
            ),
            const SizedBox(height: 16),
          ],
          // 5. ラップタイム・ペース分析
          if (_lapTimeResult != null) LapTimeChartCard(result: _lapTimeResult!),

          const SizedBox(height: 32),
          // ※配当、人気、枠番、脚質、馬体重のカードは各タブへ移植されたため削除
        ],
      ),
    );
  }
}