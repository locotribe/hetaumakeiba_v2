// lib/models/ai_export/ai_race_export_bundle.dart
// [追加] AI分析データエクスポート Step2: 収集結果の入れ物（純粋なデータ保持クラス）。DBやI/Oは持たない。ビルダー(Step3)がこれを受けてMarkdownを描画する (v.2026.9.27+26092702)

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

/// 競走馬1頭ぶんの収集データ。
class AiHorseData {
  final String horseId;

  /// 過去成績（馬柱の素）。
  final List<HorseRaceRecord> performance;

  /// 過去走ごとの追加詳細（キー: 過去走の raceId）。
  final Map<String, HorsePastRaceExtra> extrasByRaceId;

  /// 調教（1本ごと）。
  final List<NetkeibaTrainingSession> trainingSessions;

  /// 今回レースに向けた調教評価・厩舎コメント（無ければ null）。
  final NetkeibaTrainingReview? trainingReview;

  /// 血統プロフィール（無ければ null）。
  final HorseProfile? profile;

  /// スピード指数（無ければ null）。
  final HorseSpeedIndex? speedIndex;

  /// シミュレーション用パラメータ（無ければ null）。
  final HorseSimulationParams? simulationParams;

  /// 旧・調教タイム（pakara）。
  final List<TrainingTimeModel> trainingTimes;

  const AiHorseData({
    required this.horseId,
    required this.performance,
    required this.extrasByRaceId,
    required this.trainingSessions,
    required this.trainingReview,
    required this.profile,
    required this.speedIndex,
    required this.simulationParams,
    required this.trainingTimes,
  });
}

/// レース1本ぶんの収集データ（AI分析用Markdownの素材）。
class AiRaceExportBundle {
  final String raceId;
  final String raceName;
  final String raceDate;

  /// 出走馬（collect に渡した horseIds の順）。
  final List<AiHorseData> horses;

  /// 過去10年統計（無ければ null）。
  final RaceStatistics? raceStatistics;

  /// 当日の馬場（クッション値・含水率。無ければ null）。
  final TrackConditionRecord? trackCondition;

  /// レース単位メモの本文（無ければ null）。
  final String? raceMemoText;

  const AiRaceExportBundle({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.horses,
    required this.raceStatistics,
    required this.trackCondition,
    required this.raceMemoText,
  });
}
