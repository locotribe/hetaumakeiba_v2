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
// [追加] AI分析データ 天気・コース追加 Step3: コース・プリセット・天気の要約の型 (v.2026.10.11+26101103)
import 'package:hetaumakeiba_v2/logic/ai_export/ai_course_profile.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_weather_snapshot.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

// [追加] 過去レースの印・メモ Step1: 過去レースで付けた印・メモの入れ物。今回のレースのものは入れない (v.2026.10.12+26101203)
bool _aiBlank(String? v) => v == null || v.trim().isEmpty;

/// 過去レースで、その馬に付けた印・予想メモ・回顧メモ（1頭・1レースぶん）。
class AiPastRaceNote {
  /// 印（◎○▲△など。無ければ null）
  final String? mark;

  /// 予想メモ（horse_memos.predictionMemo）
  final String? predictionMemo;

  /// 回顧メモ（horse_memos.reviewMemo）
  final String? reviewMemo;

  const AiPastRaceNote({this.mark, this.predictionMemo, this.reviewMemo});

  /// 印もメモも無い（空白だけを含む）なら true。
  bool get isEmpty =>
      _aiBlank(mark) && _aiBlank(predictionMemo) && _aiBlank(reviewMemo);
}

/// 過去レースのレース単位のメモ（AIの予想・レース総評）。
class AiPastRaceMemo {
  /// AIの予想・買い目（race_memos.aiPredictionMemo。レース前に取り込んだもの）
  final String? aiPrediction;

  /// レース総評（race_memos.memo。レース後に書いたもの）
  final String? review;

  const AiPastRaceMemo({this.aiPrediction, this.review});

  /// どちらも無い（空白だけを含む）なら true。
  bool get isEmpty => _aiBlank(aiPrediction) && _aiBlank(review);
}

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

  /// [追加] T4a: 過去走ごとの馬場(クッション値・含水率)。キー=過去走のraceId。prefix10で照合して収集 (v.2026.9.27+26092709)
  final Map<String, TrackConditionRecord> pastTrackByRaceId;

  // [追加] 過去レースの印・メモ Step1: 過去走ごとの印・予想メモ・回顧メモ。キー=過去走のraceId。今回のレースと中身の無いものは入れない (v.2026.10.12+26101203)
  final Map<String, AiPastRaceNote> pastNotesByRaceId;

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
    this.pastTrackByRaceId = const {},
    this.pastNotesByRaceId = const {},
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

  // [追加] AI分析データ 天気・コース追加 Step3: コース・開催中の馬場推移・最新測定・天気。既存の呼び出しが変わらないよう、すべて省略可 (v.2026.10.11+26101103)
  /// コースの要約（障害・データ無しは null）。
  final AiCourseProfile? courseProfile;

  /// コースプリセット（直線の長さ・特徴文。見つからなければ null）。
  final CoursePreset? coursePreset;

  /// 同じ開催（raceId先頭8桁）の馬場の測定（古い順）。
  final List<TrackConditionRecord> meetingTrackHistory;

  /// その競馬場の最新の測定（レース情報タブの馬場予測の起点と同じ。無ければ null）。
  final TrackConditionRecord? latestVenueTrackCondition;

  /// 天気・馬場予測の要約（取れなければ null）。
  final AiWeatherSnapshot? weatherSnapshot;

  /// 天気が取れなかった理由（取れたときは null）。
  final String? weatherUnavailableReason;

  // [追加] 過去レースの印・メモ Step1: 出走馬の過去走のレースごとの、AIの予想・レース総評。キー=過去走のraceId。今回のレースと中身の無いものは入れない (v.2026.10.12+26101203)
  final Map<String, AiPastRaceMemo> pastRaceMemos;

  const AiRaceExportBundle({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.horses,
    required this.raceStatistics,
    required this.trackCondition,
    required this.raceMemoText,
    this.courseProfile,
    this.coursePreset,
    this.meetingTrackHistory = const [],
    this.latestVenueTrackCondition,
    this.weatherSnapshot,
    this.weatherUnavailableReason,
    this.pastRaceMemos = const {},
  });
}
