// lib/logic/base_prize_lookup.dart

// [追加] 基本情報整理と本賞金照合 Step3: 収得賞金の「重賞は本賞金の半額」を、元のレースの本賞金（出馬表キャッシュの
// basePrize1st・basePrize2nd）で計算するための純粋関数。DB・画面・通信には触れない (v.2026.10.15+26101506)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// 出馬表の本賞金から [1着, 2着]（万円）を作る。
/// どちらかが無い（null または 0 以下）ときは null（本賞金が読めていない出馬表）。
List<int>? basePrizePairOf(PredictionRaceData race) {
  final first = race.basePrize1st;
  final second = race.basePrize2nd;
  if (first == null || first <= 0 || second == null || second <= 0) {
    return null;
  }
  return [first, second];
}

/// 収得賞金の計算で、本賞金が分からず重賞の半額を出せていない走のレースID → レース名。
///
/// 対象は中央の重賞の1着・2着（2歳GⅢの固定額を除く）で、
/// 賞金列から推定した走と、賞金列も空で金額が出せなかった走。レースIDが空の走は入れない。
/// [basePrizeManByRaceId] で本賞金が分かっているレースは入らない。
/// [asOf] より前の走だけを見る（収得賞金の計算と同じ）。
Map<String, String> raceIdsNeedingBasePrize({
  required Map<String, List<HorseRaceRecord>> recordsByHorseId,
  required DateTime asOf,
  Map<String, List<int>> basePrizeManByRaceId = const {},
}) {
  final result = <String, String>{};
  for (final records in recordsByHorseId.values) {
    final prize = calculateEarnedPrize(
      records: records,
      asOf: asOf,
      basePrizeManByRaceId: basePrizeManByRaceId,
    );
    for (final entry in prize.entries) {
      final needsBasePrize = entry.isEstimated ||
          (entry.isUnknown && entry.source == EarnedPrizeSource.jra);
      if (!needsBasePrize) continue;
      final raceId = entry.raceId.trim();
      if (raceId.isEmpty) continue;
      result.putIfAbsent(raceId, () => entry.raceName);
    }
  }
  return result;
}
