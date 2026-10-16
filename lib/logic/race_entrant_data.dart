// lib/logic/race_entrant_data.dart

// [追加] 出走馬データ読み込み統一 Step1: 今回の出走馬のデータ（レース日より前に絞った戦績・血統・調教・騎手成績）と、
// 相対評価の結果をまとめて持つ入れ物と、それを作るための純粋な関数。DB・画面には触れない。
// 読み込みは race_entrant_data_service.dart が行う (v.2026.10.16+26101618)

import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/relative_battle_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

/// 相対評価の試行回数（今までの3か所の呼び出しと同じ既定値）。
const int kRelativeBattleIterations = 100;

/// 今回の出走馬のデータ一式（1レースにつき1つ）。
class RaceEntrantData {
  /// 今回のレースID。
  final String raceId;

  /// 今回のレース日（読めなければ null。そのときは戦績を日付で絞っていない）。
  final DateTime? raceDay;

  /// 馬ID → レース日より前の戦績（そのレース自身の行も除く。取消・除外の行は残す。並びは DB の順のまま）。
  final Map<String, List<HorseRaceRecord>> recordsByHorse;

  /// 馬ID → 血統（プロフィール）。DB に無い馬は入らない。
  final Map<String, HorseProfile> profilesByHorse;

  /// 馬ID → pakara の調教（レース日より前）。
  final Map<String, List<TrainingTimeModel>> pakaraTrainingByHorse;

  /// 馬ID → netkeiba の調教（レース日より前）。
  final Map<String, List<NetkeibaTrainingSession>> netkeibaTrainingByHorse;

  /// 馬ID → 今回のレースの netkeiba の調教評価。
  final Map<String, NetkeibaTrainingReview> netkeibaReviews;

  /// 騎手ID → 騎手成績（今回の騎手・前走の騎手）。
  final Map<String, JockeyStats> jockeyStats;

  /// 相対評価の結果（取消の馬を除く。順位の順）。
  final List<RelativeEvaluationResult> relativeResults;

  const RaceEntrantData({
    required this.raceId,
    required this.raceDay,
    required this.recordsByHorse,
    required this.profilesByHorse,
    required this.pakaraTrainingByHorse,
    required this.netkeibaTrainingByHorse,
    required this.netkeibaReviews,
    required this.jockeyStats,
    required this.relativeResults,
  });

  /// その馬のレース日より前の戦績（無ければ空）。
  List<HorseRaceRecord> recordsOf(String horseId) =>
      recordsByHorse[horseId] ?? const <HorseRaceRecord>[];

  /// 馬ID → 相対評価の結果。
  Map<String, RelativeEvaluationResult> get relativeByHorse =>
      {for (final r in relativeResults) r.horseId: r};
}

/// 相対評価の乱数の種。レースIDの文字から決まる（同じレースならいつも同じ値）。
/// 31倍して足す計算を 2147483647 で割った余りにしているので、どの環境でも同じ値になる。
int relativeBattleSeedOf(String raceId) {
  var hash = 7;
  for (final unit in raceId.codeUnits) {
    hash = (hash * 31 + unit) % 2147483647;
  }
  return hash;
}

/// 各馬の戦績を、今回のレース日より前の走だけにする（そのレース自身の行も除く）。
/// 取消・除外の行は残す（使う側で決める）。
/// [raceDay] が null（レース日が読めない）のときは絞らない（出馬表の分析と同じ扱い）。
Map<String, List<HorseRaceRecord>> recordsBeforeRace(
  Map<String, List<HorseRaceRecord>> recordsByHorse, {
  required DateTime? raceDay,
  required String raceId,
}) {
  if (raceDay == null) {
    return {
      for (final entry in recordsByHorse.entries)
        entry.key: List<HorseRaceRecord>.of(entry.value),
    };
  }
  return {
    for (final entry in recordsByHorse.entries)
      entry.key: filterRecordsBeforeAsOf(
        entry.value,
        asOf: raceDay,
        excludeRaceId: raceId,
      ),
  };
}

/// 騎手成績を読む騎手ID（今回の騎手・前走の騎手・戦績のいちばん上の行の騎手。空は除く）。
/// 展開シミュの騎手要素と、相対評価の騎手の点の両方で使う。
Set<String> jockeyIdsForStatsOf(
  List<PredictionHorseDetail> horses,
  Map<String, List<HorseRaceRecord>> recordsByHorse,
) {
  final ids = <String>{};
  for (final horse in horses) {
    if (horse.jockeyId.isNotEmpty) ids.add(horse.jockeyId);
    final previousJockeyId = horse.previousJockeyId;
    if (previousJockeyId != null && previousJockeyId.isNotEmpty) {
      ids.add(previousJockeyId);
    }
    final records = recordsByHorse[horse.horseId];
    if (records != null &&
        records.isNotEmpty &&
        records.first.jockeyId.isNotEmpty) {
      ids.add(records.first.jockeyId);
    }
  }
  return ids;
}

/// 相対評価を1回計算する。取消の馬は入れない。乱数の種はレースIDから決める。
/// 騎手成績・調教を渡さないときは、その点を付けずに計算する（今までの過去分析・結果分析と同じ）。
List<RelativeEvaluationResult> computeRelativeBattle({
  required String raceId,
  required List<PredictionHorseDetail> horses,
  required Map<String, List<HorseRaceRecord>> recordsByHorse,
  Map<String, JockeyStats>? jockeyStats,
  Map<String, List<TrainingTimeModel>>? pakaraTrainingByHorse,
  Map<String, List<NetkeibaTrainingSession>>? netkeibaTrainingByHorse,
  Map<String, NetkeibaTrainingReview>? netkeibaReviews,
}) {
  final runningHorses = horses.where((h) => !h.isScratched).toList();
  return RelativeBattleCalculator(seed: relativeBattleSeedOf(raceId))
      .runSimulation(
    runningHorses,
    iterations: kRelativeBattleIterations,
    jockeyStats: jockeyStats,
    horsePerformanceMap: recordsByHorse,
    trainingDataMap: pakaraTrainingByHorse,
    netkeibaTrainingMap: netkeibaTrainingByHorse,
    netkeibaReviews: netkeibaReviews,
    raceId: raceId,
  );
}

/// 読み込み係が「同じ入力か」を見分けるための文字列。
/// 相対評価・騎手成績に使う欄（馬番・騎手・オッズ・人気・取消・脚質・距離適性など）とレース日・開催場所が同じなら同じ文字列になる。
/// オッズの更新や取消で変わると、読み込み係は計算し直す。
String raceEntrantInputKeyOf(PredictionRaceData raceData) {
  final buffer = StringBuffer()
    ..write(raceData.raceId)
    ..write('|')
    ..write(raceData.raceDate)
    ..write('|')
    ..write(raceData.venue)
    ..write('|')
    ..write(raceData.raceDetails1 ?? '');
  for (final horse in raceData.horses) {
    final aptitude = horse.distanceCourseAptitudeStats;
    final style = horse.legStyleProfile;
    buffer
      ..write('\n')
      ..writeAll(<Object?>[
        horse.horseId,
        horse.horseNumber,
        horse.horseName,
        horse.sexAndAge,
        horse.jockey,
        horse.jockeyId,
        horse.isScratched,
        horse.odds,
        horse.effectiveOdds,
        horse.popularity,
        horse.overallScore,
        horse.previousJockeyId,
        aptitude?.raceCount,
        aptitude?.winCount,
        style?.primaryStyle,
        style?.styleDistribution,
        style?.styleWinRates,
      ], '|');
  }
  return buffer.toString();
}
