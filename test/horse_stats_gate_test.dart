// test/horse_stats_gate_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/horse_stats_gate.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';

RacePreparationStatus _status(
  PreparationStep step,
  PreparationState state,
  DateTime updatedAt,
) {
  return RacePreparationStatus(
    raceId: '202606040611',
    step: step,
    state: state,
    updatedAt: updatedAt,
  );
}

void main() {
  final t0 = DateTime(2026, 10, 2, 10, 0, 0);
  final before = DateTime(2026, 10, 2, 9, 59, 0);
  final after = DateTime(2026, 10, 2, 10, 1, 0);

  group('decideHorseStatsGate: レース準備が投入されるレース（waitForPreparation=true）', () {
    test('準備の記録が無い → wait', () {
      expect(
        decideHorseStatsGate(waitForPreparation: true),
        HorseStatsGateDecision.wait,
      );
    });

    test('出馬表は done・過去走は記録なし → wait', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          shutubaStatus: _status(PreparationStep.shutuba, PreparationState.done, t0),
        ),
        HorseStatsGateDecision.wait,
      );
    });

    test('過去走が pending → wait', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.pending, t0),
        ),
        HorseStatsGateDecision.wait,
      );
    });

    test('過去走が running → wait（保存があっても待つ）', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.running, t0),
          cacheUpdatedAt: after,
        ),
        HorseStatsGateDecision.wait,
      );
    });

    test('過去走が done・保存なし → ready', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.done, t0),
        ),
        HorseStatsGateDecision.ready,
      );
    });

    test('過去走が done・保存が取り直しより前 → readyRecompute', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.done, t0),
          cacheUpdatedAt: before,
        ),
        HorseStatsGateDecision.readyRecompute,
      );
    });

    test('過去走が done・保存が取り直しより後 → ready', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.done, t0),
          cacheUpdatedAt: after,
        ),
        HorseStatsGateDecision.ready,
      );
    });

    test('過去走が failed → failed', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.failed, t0),
          cacheUpdatedAt: after,
        ),
        HorseStatsGateDecision.failed,
      );
    });

    test('出馬表が failed・過去走は記録なし → failed', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: true,
          shutubaStatus: _status(PreparationStep.shutuba, PreparationState.failed, t0),
        ),
        HorseStatsGateDecision.failed,
      );
    });
  });

  group('decideHorseStatsGate: レース準備が投入されないレース（waitForPreparation=false）', () {
    test('準備の記録が無い → ready', () {
      expect(
        decideHorseStatsGate(waitForPreparation: false),
        HorseStatsGateDecision.ready,
      );
    });

    test('過去走が running でも待たない → ready', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: false,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.running, t0),
          cacheUpdatedAt: before,
        ),
        HorseStatsGateDecision.ready,
      );
    });

    test('過去走が done・保存が取り直しより前 → readyRecompute', () {
      expect(
        decideHorseStatsGate(
          waitForPreparation: false,
          horsePerformanceStatus:
              _status(PreparationStep.horsePerformance, PreparationState.done, t0),
          cacheUpdatedAt: before,
        ),
        HorseStatsGateDecision.readyRecompute,
      );
    });
  });
}
