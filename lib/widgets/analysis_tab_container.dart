// lib/widgets/analysis_tab_container.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/screens/condition_based_analysis_page.dart';

/// 分析タブ内で「適性評価」と「好走条件」を切り替えるためのコンテナ
class AnalysisTabContainer extends StatefulWidget {
  final PredictionRaceData raceData;
  final Widget existingAnalysisWidget;

  const AnalysisTabContainer({
    super.key,
    required this.raceData,
    required this.existingAnalysisWidget,
  });

  @override
  State<AnalysisTabContainer> createState() => _AnalysisTabContainerState();
}

class _AnalysisTabContainerState extends State<AnalysisTabContainer> with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // サブタブバー：分析タブ内での切り替え
        Container(
          color: Colors.grey.shade100,
          child: TabBar(
            controller: _subTabController,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue.shade700,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: '適性評価', height: 35),
              Tab(text: '好走条件', height: 35),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              // 既存の分析テーブル（引数で受け取る）
              widget.existingAnalysisWidget,
              // Step 5 で作成した新しい好走条件ページ
              ConditionBasedAnalysisPage(raceData: widget.raceData),
            ],
          ),
        ),
      ],
    );
  }
}