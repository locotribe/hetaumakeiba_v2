// lib/widgets/horse_stats_tabs/condition_based_analysis_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_ranking_builder.dart';
import 'package:hetaumakeiba_v2/widgets/horse_stats_tabs/condition_heatmap_table.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';

// [修正] 好走条件 相対順位付け StepB-2: 着順グループ主軸から今回条件ヒートマップへ刷新（クラス名・引数は不変） (v.2026.9.25+26092509)
/// 好走条件出馬表タブ（今回条件ヒートマップ）
class ConditionBasedAnalysisTab extends StatefulWidget {
  final PredictionRaceData raceData;

  const ConditionBasedAnalysisTab({
    super.key,
    required this.raceData,
  });

  @override
  State<ConditionBasedAnalysisTab> createState() => _ConditionBasedAnalysisTabState();
}

class _ConditionBasedAnalysisTabState extends State<ConditionBasedAnalysisTab>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  ConditionRankingTable? _table;
  Map<String, List<HorseRaceRecord>> _allPastRecords = {};
  final HorseRepository _horseRepository = HorseRepository();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  Future<void> _prepareData() async {
    setState(() => _isLoading = true);

    try {
      // 全頭の過去成績をDBから取得（対戦成績・列集計に使用）
      final Map<String, List<HorseRaceRecord>> allPastRecords = {};
      for (var horse in widget.raceData.horses) {
        allPastRecords[horse.horseId] =
            await _horseRepository.getHorsePerformanceRecords(horse.horseId);
      }

      final table = ConditionRankingBuilder.build(
        raceData: widget.raceData,
        allPastRecords: allPastRecords,
      );

      if (mounted) {
        setState(() {
          _allPastRecords = allPastRecords;
          _table = table;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('好走条件データの準備中にエラー: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final table = _table;
    if (table == null || table.rows.isEmpty) {
      return const Center(child: Text('分析データがありません。'));
    }

    return ConditionHeatmapTable(
      table: table,
      allPastRecords: _allPastRecords,
      currentRaceHorses: widget.raceData.horses,
    );
  }
}
