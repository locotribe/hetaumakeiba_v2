// lib/logic/horse_stats_gate.dart

// [追加] 陣営の本気度指数 過去走取り直しStep2: 出走馬分析タブを開いたとき、
// 「過去走の取り直しを待つ／今までどおり読む／保存済みの計算結果を使わずに計算し直す／
// 取り直し失敗を知らせて計算する」のどれにするかを決める純粋関数。DB・画面には触れない (v.2026.10.2+26100202)

import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';

/// 出走馬分析タブの開き方。
enum HorseStatsGateDecision {
  /// 過去走の取り直しが終わるまで計算を始めない。
  wait,

  /// 計算してよい。保存済みの計算結果があればそれを使ってよい（今までどおり）。
  ready,

  /// 計算してよい。ただし保存済みの計算結果は過去走の取り直しより古いので、使わずに計算し直す。
  readyRecompute,

  /// 過去走の取り直しが失敗した。失敗を知らせ、保存済みの計算結果は使わずに今ある過去走で計算する。
  failed,
}

/// 出走馬分析タブの開き方を決める。
///
/// [waitForPreparation] このレースで過去走の取り直し（レース準備）が投入されるか。
///   レース画面でレース結果が無いとき true（出馬表がレース準備を投入する条件と同じ）。
/// [shutubaStatus] レース準備の「出馬表」ステップの状態（記録が無ければ null）。
/// [horsePerformanceStatus] レース準備の「出走馬の戦績」ステップの状態（記録が無ければ null）。
/// [cacheUpdatedAt] 出走馬分析の計算結果の保存時刻（保存が無ければ null）。
HorseStatsGateDecision decideHorseStatsGate({
  required bool waitForPreparation,
  RacePreparationStatus? shutubaStatus,
  RacePreparationStatus? horsePerformanceStatus,
  DateTime? cacheUpdatedAt,
}) {
  final hpState = horsePerformanceStatus?.state;

  if (waitForPreparation && hpState != PreparationState.done) {
    // 出馬表ステップが失敗すると、過去走ステップは依存が解けず永遠に動かないので失敗扱いにする
    if (hpState == PreparationState.failed ||
        shutubaStatus?.state == PreparationState.failed) {
      return HorseStatsGateDecision.failed;
    }
    return HorseStatsGateDecision.wait;
  }

  if (hpState == PreparationState.done &&
      cacheUpdatedAt != null &&
      cacheUpdatedAt.isBefore(horsePerformanceStatus!.updatedAt)) {
    return HorseStatsGateDecision.readyRecompute;
  }

  return HorseStatsGateDecision.ready;
}
