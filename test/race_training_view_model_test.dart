// test/race_training_view_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/view_models/race_training_view_model.dart';

// [追加] 馬詳細タブStep1: 調教データの見出し文言（移す前の調教タブと同じ文言か） (v.2026.9.23+26092306)

RacePreparationStatus _status(PreparationState state, {int itemCount = 0}) {
  return RacePreparationStatus(
    raceId: '202606040911',
    step: PreparationStep.training,
    state: state,
    itemCount: itemCount,
    updatedAt: DateTime(2026, 9, 23),
  );
}

void main() {
  group('trainingStatusLabel', () {
    test('状態が無いときは未取得', () {
      expect(trainingStatusLabel(null), '※調教データ未取得');
    });

    test('未着手は未取得', () {
      expect(trainingStatusLabel(_status(PreparationState.pending)), '※調教データ未取得');
    });

    test('実行中', () {
      expect(trainingStatusLabel(_status(PreparationState.running)), '※調教データ取得中...');
    });

    test('完了0件は提供なし', () {
      expect(trainingStatusLabel(_status(PreparationState.done)),
          '※このレースの調教データは提供されていません');
    });

    test('完了1件以上', () {
      expect(trainingStatusLabel(_status(PreparationState.done, itemCount: 5)),
          '※直近の調教タイム・ラップ');
    });

    test('失敗', () {
      expect(trainingStatusLabel(_status(PreparationState.failed)),
          '※調教データの取得に失敗しました');
    });

    test('対象外', () {
      expect(trainingStatusLabel(_status(PreparationState.skipped)),
          '※直近の調教タイム・ラップ');
    });
  });
}
