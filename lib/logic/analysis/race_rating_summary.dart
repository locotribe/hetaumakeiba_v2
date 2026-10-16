// lib/logic/analysis/race_rating_summary.dart

// [追加] 能力分析を馬詳細へ Step1: 今回の出走馬の Rt（能力分析）をまとめて計算する純粋な部品。馬詳細の「能力・条件」・「全」ページの能力の表と、
// レース情報タブのレースレベル診断で使う。戦績は読み込み係（RaceEntrantDataService）のレース日より前の戦績を渡す。DB・画面には触れない (v.2026.10.17+26101701)

import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// レースレベル診断の区分。
enum RaceLevelKind {
  /// クラスの標準を大きく上回る（ハイレベルな一戦）
  high,

  /// 標準的なレースレベル
  standard,

  /// 手薄（低調なメンバー構成）
  low,
}

/// レースレベル診断の差の区切り（±1.5。今までの能力分析タブと同じ）。
const double kRaceLevelThreshold = 1.5;

/// レースレベル診断の結果。
class RaceLevelDiagnosis {
  /// 予想レースレベル（出走馬の実力Trendの平均×0.7＋クラスの標準の Rt×0.3）。
  final double predictedLevel;

  /// 予想レースレベル − クラスの標準の Rt。
  final double diff;

  /// 今回のクラスの標準の Rt（AdvancedRatingEngine.classStandardRatingOf）。
  final double classStandardRating;

  final RaceLevelKind kind;

  /// 分析信頼度（'A (高)'・'B (中)'・'C (低)'）。出走する馬のうち、Rt を計算できる過去成績が3走以上ある馬の割合で決める。
  final String reliabilityGrade;

  const RaceLevelDiagnosis({
    required this.predictedLevel,
    required this.diff,
    required this.classStandardRating,
    required this.kind,
    required this.reliabilityGrade,
  });
}

/// 今回の出走馬の Rt をまとめたもの（1レースにつき1つ）。
class RaceRatingSummary {
  /// 馬ID → Rt の計算結果（取消の馬も入る）。
  final Map<String, HorseRatingProfile> profiles;

  /// 取消の馬を除く出走馬の馬ID（実力Trendの高い順。同じ値なら渡した馬の順）。
  final List<String> trendOrder;

  /// 今回のクラスの標準の Rt。
  final double classStandardRating;

  /// レースレベル診断。出走する馬に Rt を計算できる馬がいないときは null。
  final RaceLevelDiagnosis? level;

  const RaceRatingSummary({
    required this.profiles,
    required this.trendOrder,
    required this.classStandardRating,
    required this.level,
  });

  /// その馬の Rt の計算結果（無ければ null）。
  HorseRatingProfile? profileOf(String horseId) => profiles[horseId];

  /// 実力Trendの順位（1始まり）。取消の馬は null。
  int? trendRankOf(String horseId) {
    final index = trendOrder.indexOf(horseId);
    return index < 0 ? null : index + 1;
  }

  /// 期待値Gap（今回の人気 − 実力Trendの順位）。人気が無いときは 10 として計算する（今までの能力分析タブと同じ）。取消の馬は null。
  int? gapOf(PredictionHorseDetail horse) {
    final rank = trendRankOf(horse.horseId);
    if (rank == null) return null;
    return (horse.popularity ?? 10) - rank;
  }
}

/// 期待値Gap の評価の文字（今までの能力分析タブと同じ区切り）。
String ratingGapLabelOf(int gap) {
  if (gap >= 6) return '過小評価★';
  if (gap >= 3) return '妙味あり';
  if (gap <= -6) return '過剰人気⚠';
  if (gap <= -3) return '人気先行';
  return '適正';
}

/// 状態サイクルの診断メモ（今までの能力分析タブと同じ文）。
String ratingMomentumNoteOf(String momentumStatus) {
  switch (momentumStatus) {
    case '反動警戒':
      return '前走で実力以上に激走。疲労による凡走に注意。';
    case '上昇期':
      return '直近でRtを上げており、さらなる前進が見込める。';
    case '叩き一変注意':
      return '近走は不振だが地力はある。一変の余地あり。';
    default:
      return '大きな波は見られず平行線。';
  }
}

/// 今回の出走馬の Rt をまとめて計算する。
/// - [recordsByHorse] は今回のレース日より前の戦績（読み込み係の recordsByHorse）。着順が数字でない行は Rt の計算で外れる。
/// - 性別は [profilesByHorse] の血統から取る。無ければ '牡'（今までの能力分析タブと同じ）。
/// - 取消の馬は Rt を計算するが、実力Trendの順位・期待値Gap・レースレベル診断には入れない。
RaceRatingSummary buildRaceRatingSummary({
  required List<PredictionHorseDetail> horses,
  required Map<String, List<HorseRaceRecord>> recordsByHorse,
  required Map<String, HorseProfile> profilesByHorse,
  required RaceClassGrade currentClass,
}) {
  final profiles = <String, HorseRatingProfile>{};
  for (final horse in horses) {
    final gender = profilesByHorse[horse.horseId]?.gender ?? '牡';
    profiles[horse.horseId] = AdvancedRatingEngine.analyze(
      recordsByHorse[horse.horseId] ?? const <HorseRaceRecord>[],
      horse.horseId,
      gender,
      currentClass,
    );
  }

  final runners = horses.where((h) => !h.isScratched).toList();
  final indexed = <MapEntry<int, PredictionHorseDetail>>[
    for (var i = 0; i < runners.length; i++) MapEntry(i, runners[i]),
  ];
  indexed.sort((a, b) {
    final byTrend = profiles[b.value.horseId]!
        .latestTrend
        .compareTo(profiles[a.value.horseId]!.latestTrend);
    return byTrend != 0 ? byTrend : a.key.compareTo(b.key);
  });

  return RaceRatingSummary(
    profiles: profiles,
    trendOrder: [for (final entry in indexed) entry.value.horseId],
    classStandardRating:
        AdvancedRatingEngine.classStandardRatingOf(currentClass),
    level: diagnoseRaceLevel(
      runners: runners,
      profiles: profiles,
      currentClass: currentClass,
    ),
  );
}

/// レースレベル診断（今までの能力分析タブの計算を移したもの）。
/// - 平均は、出走する馬（取消を除く）のうち Rt を計算できた馬の実力Trendで取る。
/// - 比べる相手は今回のクラスの標準の Rt（今までは今回のレース名から出した基準値で、ほぼ全レースで 80 だった）。
/// - 分析信頼度の分母は出走する馬の頭数（今までは取消の馬も数えていた）。
RaceLevelDiagnosis? diagnoseRaceLevel({
  required List<PredictionHorseDetail> runners,
  required Map<String, HorseRatingProfile> profiles,
  required RaceClassGrade currentClass,
}) {
  if (runners.isEmpty) return null;
  double totalTrend = 0;
  int validHorseCount = 0;
  int dataSufficiencyCount = 0;
  for (final horse in runners) {
    final profile = profiles[horse.horseId];
    if (profile == null || profile.history.isEmpty) continue;
    totalTrend += profile.latestTrend;
    validHorseCount++;
    if (profile.history.length >= 3) dataSufficiencyCount++;
  }
  if (validHorseCount == 0) return null;

  final standard = AdvancedRatingEngine.classStandardRatingOf(currentClass);
  final avgTrend = totalTrend / validHorseCount;
  final predicted = (avgTrend * 0.7) + (standard * 0.3);
  final diff = predicted - standard;

  final RaceLevelKind kind;
  if (diff >= kRaceLevelThreshold) {
    kind = RaceLevelKind.high;
  } else if (diff <= -kRaceLevelThreshold) {
    kind = RaceLevelKind.low;
  } else {
    kind = RaceLevelKind.standard;
  }

  final sufficiencyRatio = dataSufficiencyCount / runners.length;
  final String reliabilityGrade;
  if (sufficiencyRatio >= 0.8) {
    reliabilityGrade = 'A (高)';
  } else if (sufficiencyRatio >= 0.5) {
    reliabilityGrade = 'B (中)';
  } else {
    reliabilityGrade = 'C (低)';
  }

  return RaceLevelDiagnosis(
    predictedLevel: predicted,
    diff: diff,
    classStandardRating: standard,
    kind: kind,
    reliabilityGrade: reliabilityGrade,
  );
}
