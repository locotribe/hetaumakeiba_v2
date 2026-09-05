// lib/models/race_analysis_bundle.dart

import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

// [追加] 過去分析タブの子タブ群が共通で使う分析データの入れ物 (v.2026.9.5+26090506)
///
/// 従来は StatsMatchTab が自前で約300クエリ分の読み込みを行っていたが、
/// 子タブを分割すると同じ読み込みがタブの数だけ繰り返されてしまう。
/// そのため親（RaceStatisticsPage）で1回だけ読み込み、この入れ物に詰めて各子タブへ渡す。
///
/// 注意: 類似馬分析（約2,560回の計算）はここには含めない。
/// 類似馬は結果分析タブ（StatsMatchTab）だけが使うため、従来どおりそちら側で計算する。
class RaceAnalysisBundle {
  /// 分析対象となった過去レース群
  final List<RaceResult> pastRaces;

  /// 今回の出走馬の過去成績（Key: horseId）
  final Map<String, List<HorseRaceRecord>> currentHorseHistory;

  /// 過去レースの1〜3着馬の過去成績（Key: horseId）
  final Map<String, List<HorseRaceRecord>> pastTopHorseRecords;

  /// 過去レース当日の馬場状態（Key: 過去レースのraceId）
  final Map<String, TrackConditionRecord> trackConditionMap;

  /// 今回の出走馬が過去に走ったレースの馬場状態（Key: そのレースのraceId）
  final Map<String, TrackConditionRecord> horsePastTrackConditions;

  /// 血統プロフィール（今回の出走馬＋過去の1〜3着馬）（Key: horseId）
  final Map<String, HorseProfile> horseProfileMap;

  /// 馬場状態（クッション値・含水率）の傾向
  final TrackConditionTrendResult trackConditionTrendResult;

  /// 好走血統 × 馬場状態のクロス分析
  final CrossAnalysisResult pedigreeCrossResult;

  /// 波乱度（過去1〜3着馬の平均人気など）
  final VolatilityResult volatilityResult;

  // [追加] ラップタイム・ペースの分析結果（ペースタブで表示） (v.2026.9.5+26090506)
  final LapTimeAnalysisResult? lapTimeResult;

  // [追加] 血統取得の進捗判定用。過去1〜3着馬の実頭数 (v.2026.9.5+26090506)
  final int totalTargetHorseCount;

  // [追加] 血統取得の進捗判定用。父名が未取得の頭数 (v.2026.9.5+26090506)
  final int missingPedigreeCount;

  /// ペース別シミュレーション結果（Key: horseId）
  final Map<String, RelativeEvaluationResult> relativeBattleResults;

  /// HistoricalMatchEngine による各馬のファクター別スコア
  final List<HistoricalMatchModel> matchResults;

  /// 過去傾向のサマリー（基準体重・有利ゾーン・王道ローテなど）
  final TrendSummary? summary;

  /// 今回のレースがダートかどうか
  final bool isDirt;

  /// 今回のレースの開催日（ローテーション判定の基準日）
  final String targetRaceDate;

  const RaceAnalysisBundle({
    required this.pastRaces,
    required this.currentHorseHistory,
    required this.pastTopHorseRecords,
    required this.trackConditionMap,
    required this.horsePastTrackConditions,
    required this.horseProfileMap,
    required this.trackConditionTrendResult,
    required this.pedigreeCrossResult,
    required this.volatilityResult,
    required this.lapTimeResult,
    required this.totalTargetHorseCount,
    required this.missingPedigreeCount,
    required this.relativeBattleResults,
    required this.matchResults,
    required this.summary,
    required this.isDirt,
    required this.targetRaceDate,
  });

  /// horseId から該当馬のファクター別スコアを引く
  HistoricalMatchModel? matchFor(String horseId) {
    for (final item in matchResults) {
      if (item.horseId == horseId) return item;
    }
    return null;
  }

  /// 分析対象となったレース数
  int get raceCount => pastRaces.length;

  /// 血統プロフィールが1件も取得できていないか（血統タブの案内表示に使用）
  bool get hasNoPedigreeData => horseProfileMap.isEmpty;

  /// 血統データが1頭でも不足しているか
  bool get hasMissingPedigree => missingPedigreeCount > 0;
}
