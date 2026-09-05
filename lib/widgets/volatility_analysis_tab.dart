// lib/widgets/volatility_analysis_tab.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/volatility_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/past_top_horses_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/payout_comparison_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/popularity_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/frame_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/leg_style_chart_card.dart';
import 'package:hetaumakeiba_v2/widgets/volatility_components/horse_weight_card.dart';

class VolatilityAnalysisTab extends StatefulWidget {
  final List<String> targetRaceIds;

  // [追加] タブ最上部に差し込む任意のウィジェット（ファクター該当数カード等） (v.2026.9.5+26090506)
  final Widget? headerWidget;

  const VolatilityAnalysisTab({
    Key? key,
    required this.targetRaceIds,
    this.headerWidget,
  }) : super(key: key);

  @override
  State<VolatilityAnalysisTab> createState() => _VolatilityAnalysisTabState();
}

class _VolatilityAnalysisTabState extends State<VolatilityAnalysisTab> {
  final RaceRepository _raceRepo = RaceRepository();
  bool _isLoading = true;

  VolatilityResult? _volatilityResult;
  PayoutAnalysisResult? _payoutResult;
  PopularityAnalysisResult? _popularityResult;
  FrameAnalysisResult? _frameResult;
  LegStyleAnalysisResult? _legStyleResult;
  HorseWeightAnalysisResult? _horseWeightResult;

  // 過去の上位3頭と馬場状態を保持する変数
  List<PastRaceTop3Result>? _pastTop3Result;
  final Map<String, TrackConditionRecord> _trackConditionMap = {};

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
    final bundle = await compute(runVolatilityAnalysis, pastRaces);

    if (mounted) {
      setState(() {
        // 既存の解析（compute()で実行した結果を反映）
        _volatilityResult = bundle.volatilityResult;
        _payoutResult = bundle.payoutResult;
        _popularityResult = bundle.popularityResult;
        _frameResult = bundle.frameResult;
        _legStyleResult = bundle.legStyleResult;
        _horseWeightResult = bundle.horseWeightResult;
        _pastTop3Result = bundle.pastTop3Result;

        _isLoading = false;
      });
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
          // [追加] 0. ファクター該当数（横断集計） (v.2026.9.5+26090506)
          if (widget.headerWidget != null) ...[
            widget.headerWidget!,
            const SizedBox(height: 16),
          ],
          // 1. 波乱度
          VolatilityCard(res: _volatilityResult!),
          const SizedBox(height: 16),
          // 2. 過去レース上位3頭と馬場状態
          PastTopHorsesCard(pastTop3Result: _pastTop3Result, trackConditionMap: _trackConditionMap),
          const SizedBox(height: 16),
          // ※馬場状態の傾向は「馬場」タブ、好走血統クロスは「血統」タブ、
          //   ラップタイム・ペース分析は「ペース」タブへ移設 (v.2026.9.5+26090506)
          const SizedBox(height: 32),
          // ※配当、人気、枠番、脚質、馬体重のカードは各タブへ移植されたため削除
        ],
      ),
    );
  }
}