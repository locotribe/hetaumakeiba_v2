// lib/logic/past_race_horse_data.dart

// [追加] 全出走馬の取得と読み込み Step1: 過去レースの全出走馬を数え、戦績・血統を取る必要がある馬を決める部品。DBやネットには触らない (v.2026.10.16+26101608)

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

/// 着順の欄が取消・除外か（そのレースに出走していない）。
bool isNonStarterRank(String rank) => rank.contains('取') || rank.contains('除');

/// [pastRaces] の全出走馬の馬ID。
///
/// - 取消・除外の馬と、馬IDが空の行は含めない（中止・失格・着順が空欄の馬は含める）。
/// - 同じ馬が複数の年に出ていても1つにまとめる。並びは最初に出てきた順。
List<String> pastRaceHorseIds(List<RaceResult> pastRaces) {
  final seen = <String>{};
  final ids = <String>[];
  for (final race in pastRaces) {
    for (final horse in race.horseResults) {
      if (horse.horseId.isEmpty) continue;
      if (isNonStarterRank(horse.rank)) continue;
      if (seen.add(horse.horseId)) ids.add(horse.horseId);
    }
  }
  return ids;
}

/// [pastRaces] の1〜3着の馬ID（今までの読み込みと同じく、着順が数字で3以下）。
/// 同じ馬が複数の年に出ていても1つにまとめる。並びは最初に出てきた順。
List<String> pastTopFinisherHorseIds(List<RaceResult> pastRaces) {
  final seen = <String>{};
  final ids = <String>[];
  for (final race in pastRaces) {
    for (final horse in race.horseResults) {
      if (horse.horseId.isEmpty) continue;
      final rank = int.tryParse(horse.rank);
      if (rank == null || rank > 3) continue;
      if (seen.add(horse.horseId)) ids.add(horse.horseId);
    }
  }
  return ids;
}

/// 戦績を取る必要があるか。
///
/// その馬が出走した過去レース（[ranRaceIds]）のうち1つでも、戦績（[records]）に
/// 同じレースIDの行が無ければ true。そのレースの行があれば、その前の走も保存されている
/// （戦績のページは全部の走を1度に保存する）ので取らない。
/// 「そのレースより前の走が無ければ取る」にすると、新馬戦から出た馬を毎回取り直してしまうため、この決め方にした。
bool needsPerformanceFetch(
  List<HorseRaceRecord> records,
  Iterable<String> ranRaceIds,
) {
  final saved = <String>{for (final r in records) r.raceId};
  for (final raceId in ranRaceIds) {
    if (!saved.contains(raceId)) return true;
  }
  return false;
}

/// 血統を取る必要があるか（プロフィールが無い、または父の名前が空）。
bool needsPedigreeFetch(HorseProfile? profile) =>
    profile == null || profile.fatherName.isEmpty;

/// 過去レースの全出走馬について、取る必要がある戦績・血統をまとめたもの。
class PastRaceHorseFetchPlan {
  /// 全出走馬の馬ID（[pastRaceHorseIds] と同じ並び）。
  final List<String> horseIds;

  /// 馬ID → 馬名（レース結果の表記。血統だけを保存するときの馬名に使う）。
  final Map<String, String> horseNames;

  /// 戦績を取る馬。
  final Set<String> performanceHorseIds;

  /// 血統を取る馬。
  final Set<String> pedigreeHorseIds;

  const PastRaceHorseFetchPlan({
    required this.horseIds,
    required this.horseNames,
    required this.performanceHorseIds,
    required this.pedigreeHorseIds,
  });

  static const empty = PastRaceHorseFetchPlan(
    horseIds: [],
    horseNames: {},
    performanceHorseIds: {},
    pedigreeHorseIds: {},
  );

  /// 全出走馬の頭数。
  int get totalHorseCount => horseIds.length;

  /// 戦績か血統の少なくとも一方を取る馬（[horseIds] の並び）。
  List<String> get horseIdsToFetch => [
        for (final id in horseIds)
          if (performanceHorseIds.contains(id) || pedigreeHorseIds.contains(id))
            id,
      ];

  /// 取る物が無いか。
  bool get isComplete =>
      performanceHorseIds.isEmpty && pedigreeHorseIds.isEmpty;
}

/// 取る必要がある戦績・血統を決める。
///
/// [recordsByHorse]・[profileByHorse] に無い馬は、戦績・血統が無いものとして扱う。
PastRaceHorseFetchPlan buildPastRaceHorseFetchPlan({
  required List<RaceResult> pastRaces,
  required Map<String, List<HorseRaceRecord>> recordsByHorse,
  required Map<String, HorseProfile?> profileByHorse,
}) {
  final horseIds = pastRaceHorseIds(pastRaces);
  final names = <String, String>{};
  final ranRaceIds = <String, List<String>>{};
  for (final race in pastRaces) {
    for (final horse in race.horseResults) {
      if (horse.horseId.isEmpty) continue;
      if (isNonStarterRank(horse.rank)) continue;
      names.putIfAbsent(horse.horseId, () => horse.horseName);
      ranRaceIds.putIfAbsent(horse.horseId, () => []).add(race.raceId);
    }
  }
  final performance = <String>{};
  final pedigree = <String>{};
  for (final id in horseIds) {
    if (needsPerformanceFetch(
        recordsByHorse[id] ?? const [], ranRaceIds[id] ?? const [])) {
      performance.add(id);
    }
    if (needsPedigreeFetch(profileByHorse[id])) {
      pedigree.add(id);
    }
  }
  return PastRaceHorseFetchPlan(
    horseIds: horseIds,
    horseNames: names,
    performanceHorseIds: performance,
    pedigreeHorseIds: pedigree,
  );
}
