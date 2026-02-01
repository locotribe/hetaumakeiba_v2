// lib/models/condition_presentation_model.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/condition_match_engine.dart';

/// UIに表示するために最適化された、馬ごとの好走条件データモデル
class HorseConditionDisplayData {
  final String horseId;
  final String horseName;
  final Map<String, RankSummaryDisplay> summaries; // Key: "1着", "2着", etc.

  HorseConditionDisplayData({
    required this.horseId,
    required this.horseName,
    required this.summaries,
  });
}

/// 各着順グループのサマリー表示用データ
class RankSummaryDisplay {
  final String rankLabel; // "1着", "2着" など
  final int count;        // 該当回数
  final String distanceRange;    // 例: "1600m〜2000m"
  final String weightRange;      // 例: "460kg〜480kg"
  final String carriedWeightRange; // 例: "54.0kg〜56.0kg"
  final String venueList;        // 実績のある開催地（例: "東京, 中山"）
  final String legStyleSummary;    // 脚質サマリー (例: "逃(1) 先(2)")
  final String directionSummary;   // 回りサマリー (例: "右(3)")
  final String trackConditionSummary; // 馬場サマリー (例: "良(2)")
  final List<PastRaceWithMatchup> detailedRaces; // タップ時に表示する詳細リスト

  RankSummaryDisplay({
    required this.rankLabel,
    required this.count,
    required this.distanceRange,
    required this.weightRange,
    required this.carriedWeightRange,
    required this.venueList,
    required this.legStyleSummary,
    required this.directionSummary,
    required this.trackConditionSummary,
    required this.detailedRaces,
  });
}

/// 対戦情報が付与された過去レース詳細データ
class PastRaceWithMatchup {
  final HorseRaceRecord record;
  final RaceMatchupContext? matchupContext; // 今回のメンバーとの対戦情報

  PastRaceWithMatchup({
    required this.record,
    this.matchupContext,
  });
}