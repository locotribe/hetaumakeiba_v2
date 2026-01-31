// lib/screens/condition_based_analysis_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/condition_match_engine.dart';
import 'package:hetaumakeiba_v2/widgets/condition_horse_row.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';

/// 好走条件出馬表タブのメインコンテンツ
class ConditionBasedAnalysisPage extends StatefulWidget {
  final PredictionRaceData raceData;

  const ConditionBasedAnalysisPage({
    super.key,
    required this.raceData,
  });

  @override
  State<ConditionBasedAnalysisPage> createState() => _ConditionBasedAnalysisPageState();
}

class _ConditionBasedAnalysisPageState extends State<ConditionBasedAnalysisPage> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<HorseConditionDisplayData> _displayDataList = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
      final List<HorseConditionDisplayData> resultList = [];
      final Map<String, List<HorseRaceRecord>> allPastRecords = {};

      // 1. 全頭の過去成績をDBから取得
      for (var horse in widget.raceData.horses) {
        final records = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
        allPastRecords[horse.horseId] = records;
      }

      // 2. 各馬のデータを表示モデルに変換
      for (var horse in widget.raceData.horses) {
        final myRecords = allPastRecords[horse.horseId] ?? [];
        final grouped = ConditionMatchEngine.groupRecordsByRank(myRecords);
        final Map<String, RankSummaryDisplay> summaries = {};

        grouped.forEach((rankLabel, records) {
          if (records.isNotEmpty) {
            final range = ConditionMatchEngine.calculateRange(records, widget.raceData.raceDate);

            // 詳細リストの作成（対戦相手スキャンを含む）
            final detailedRaces = records.map((record) {
              final matchup = ConditionMatchEngine.scanMatchups(
                targetRaceId: record.raceId,
                myHorseId: horse.horseId,
                myRank: record.rank,
                currentRaceMembers: widget.raceData.horses,
                allHorsesPastRecords: allPastRecords,
              );
              return PastRaceWithMatchup(record: record, matchupContext: matchup);
            }).toList();

            summaries[rankLabel] = RankSummaryDisplay(
              rankLabel: rankLabel,
              count: records.length,
              distanceRange: range.maxDistance != null ? '${range.minDistance?.toInt()}m〜${range.maxDistance?.toInt()}m' : '-',
              weightRange: range.maxWeight != null ? '${range.minWeight}kg〜${range.maxWeight}kg' : '-',
              carriedWeightRange: range.maxCarriedWeight != null ? '${range.minCarriedWeight}kg〜${range.maxCarriedWeight}kg' : '-',
              venueList: records.map((r) => r.venue.replaceAll(RegExp(r'\d'), '')).toSet().join(', '),
              detailedRaces: detailedRaces,
            );
          }
        });

        resultList.add(HorseConditionDisplayData(
          horseId: horse.horseId,
          horseName: horse.horseName,
          summaries: summaries,
        ));
      }

      if (mounted) {
        setState(() {
          _displayDataList = resultList;
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

    if (_displayDataList.isEmpty) {
      return const Center(child: Text('分析データがありません。'));
    }

    return ListView.builder(
      itemCount: _displayDataList.length,
      itemBuilder: (context, index) {
        return ConditionHorseRow(data: _displayDataList[index]);
      },
    );
  }
}