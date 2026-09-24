// test/training_evaluation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/training_evaluation.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

TrainingTimeModel _t({
  required String trackType,
  required String location,
  double? f6,
  double? f5,
  double? f4,
  double? f3,
  double? f2,
  double? f1,
}) {
  return TrainingTimeModel(
    horseId: 'h',
    trainingDate: '20260920',
    trainingTime: '0535',
    trackType: trackType,
    location: location,
    f6: f6,
    f5: f5,
    f4: f4,
    f3: f3,
    f2: f2,
    f1: f1,
  );
}

void main() {
  group('trainingCumulatives / trainingSplits', () {
    test('坂路は4F〜1Fの累計、ラップは差＋最後の1F', () {
      final t = _t(trackType: '坂路', location: '美浦', f4: 54.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(trainingCumulatives(t), [54.0, 39.0, 25.0, 12.0]);
      final s = trainingSplits(t);
      expect(s.length, 4);
      expect(s[0], closeTo(15.0, 1e-9)); // 54-39
      expect(s[1], closeTo(14.0, 1e-9)); // 39-25
      expect(s[2], closeTo(13.0, 1e-9)); // 25-12
      expect(s[3], closeTo(12.0, 1e-9)); // 最後は1Fそのもの
    });
  });

  group('dynamicBaseTime / baseDiff', () {
    test('美浦坂路4F 先頭は基準54.5', () {
      final t = _t(trackType: '坂路', location: '美浦', f4: 54.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(dynamicBaseTime(t), TrainingBaseTimes.hanro4fMiho);
      expect(baseDiff(t), closeTo(54.0 - 54.5, 1e-9)); // 速い＝負
    });
    test('栗東坂路4F 先頭は基準53.5', () {
      final t = _t(trackType: '坂路', location: '栗東', f4: 53.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(dynamicBaseTime(t), TrainingBaseTimes.hanro4fRitto);
      expect(baseDiff(t), closeTo(53.0 - 53.5, 1e-9));
    });
    test('美浦ウッド6F 先頭は基準83.0', () {
      final t = _t(trackType: 'ウッド', location: '美浦', f6: 82.0, f5: 67.0, f4: 52.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(dynamicBaseTime(t), TrainingBaseTimes.wood6fMiho);
      expect(baseDiff(t), closeTo(82.0 - 83.0, 1e-9));
    });
    test('栗東ウッド5F 先頭は基準66.0', () {
      final t = _t(trackType: 'ウッド', location: '栗東', f5: 66.0, f4: 51.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(dynamicBaseTime(t), TrainingBaseTimes.wood5fRitto);
    });
    test('基準の無い先頭ハロンなら null', () {
      final t = _t(trackType: 'ウッド', location: '美浦', f3: 39.0, f2: 25.0, f1: 12.0);
      expect(dynamicBaseTime(t), isNull);
      expect(baseDiff(t), isNull);
    });
  });

  group('trainingIntent（ウッドのみ）', () {
    test('栗東 F4のみ＝軽め調整', () {
      final t = _t(trackType: 'ウッド', location: '栗東', f4: 52.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(trainingIntent(t)?.kind, TrainingIntentKind.light);
    });
    test('栗東 F5以上＝実戦的追い', () {
      final t = _t(trackType: 'ウッド', location: '栗東', f5: 66.0, f4: 51.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(trainingIntent(t)?.kind, TrainingIntentKind.practical);
    });
    test('美浦 F4のみ＝終い特化', () {
      final t = _t(trackType: 'ウッド', location: '美浦', f4: 52.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(trainingIntent(t)?.kind, TrainingIntentKind.sharp);
    });
    test('美浦 F5以上＝標準的追い', () {
      final t = _t(trackType: 'ウッド', location: '美浦', f5: 67.0, f4: 52.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(trainingIntent(t)?.kind, TrainingIntentKind.standard);
    });
    test('坂路は意図なし', () {
      final t = _t(trackType: '坂路', location: '美浦', f4: 54.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(trainingIntent(t), isNull);
    });
  });

  group('isOniashi', () {
    test('美浦は1F≤11.3で鬼脚', () {
      expect(isOniashi(_t(trackType: '坂路', location: '美浦', f4: 54.0, f1: 11.3)), isTrue);
      expect(isOniashi(_t(trackType: '坂路', location: '美浦', f4: 54.0, f1: 11.4)), isFalse);
    });
    test('栗東は1F≤11.4で鬼脚', () {
      expect(isOniashi(_t(trackType: '坂路', location: '栗東', f4: 53.0, f1: 11.4)), isTrue);
      expect(isOniashi(_t(trackType: '坂路', location: '栗東', f4: 53.0, f1: 11.5)), isFalse);
    });
  });

  group('lapTrends', () {
    test('終いに向けて加速すると -1 が並ぶ', () {
      // splits: 15,14,13,12 → 各差 -1（加速）
      final t = _t(trackType: '坂路', location: '美浦', f4: 54.0, f3: 39.0, f2: 25.0, f1: 12.0);
      expect(lapTrends(t), [-1, -1, -1]);
    });
    test('終いが失速すると +1', () {
      // cumulatives 54,39,25,13 → splits 15,14,12,13 → 差 -1,-2,+1
      final t = _t(trackType: '坂路', location: '美浦', f4: 54.0, f3: 39.0, f2: 25.0, f1: 13.0);
      expect(lapTrends(t), [-1, -1, 1]);
    });
  });

  group('isComparableCourse', () {
    test('坂路・ウッドは true、それ以外は false', () {
      expect(isComparableCourse(_t(trackType: '坂路', location: '美浦', f4: 54.0)), isTrue);
      expect(isComparableCourse(_t(trackType: 'ウッド', location: '美浦', f6: 82.0)), isTrue);
      expect(isComparableCourse(_t(trackType: 'ＤＰ', location: '美浦', f4: 40.0)), isFalse);
    });
  });
}
