// test/training_merge_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

TrainingTimeModel _p(
  String date,
  String time, {
  String track = '坂路',
  String location = '栗東',
  double? f6,
  double? f5,
  double? f4,
  double? f3,
  double? f2,
  double? f1,
}) =>
    TrainingTimeModel(
      horseId: 'h1',
      trainingDate: date,
      trainingTime: time,
      trackType: track,
      location: location,
      f6: f6,
      f5: f5,
      f4: f4,
      f3: f3,
      f2: f2,
      f1: f1,
    );

NetkeibaTrainingSession _n(String date, String course, List<double?> slots,
        {String? time}) =>
    NetkeibaTrainingSession(
      horseId: 'h1',
      trainingDate: date,
      courseRaw: course,
      seq: 0,
      trainingTime: time,
      slots: slots,
      rank: 'B',
    );

void main() {
  test('坂路: 時刻が無くても時計で突き合わせる（同じ日の軽めの調教とは区別）', () {
    final pakara = [
      _p('20260917', '0712', f4: 52.4, f3: 38.1, f2: 24.8, f1: 12.3),
      _p('20260917', '0630', f4: 60.1, f3: 44.0, f2: 29.0, f1: 14.5),
    ];
    final nk = [_n('20260917', '栗坂', [null, 52.4, 38.1, 24.8, 12.3])];
    final result = mergeTrainingSources(pakara, nk);
    expect(result.length, 2);
    expect(result[0].trainingTime, '0712');
    expect(result[0].pakara!.f4, 52.4);
    expect(result[0].netkeiba, isNotNull);
    expect(result[1].trainingTime, '0630');
    expect(result[1].netkeiba, isNull);
  });

  test('ウッド: 時刻が10分以内なら時刻で突き合わせる', () {
    final pakara = [
      _p('20260916', '0540',
          track: 'ウッド', f6: 89.1, f5: 73.0, f4: 55.8, f3: 39.7, f2: 24.0, f1: 11.8),
    ];
    final nk = [
      _n('20260916', 'ＣＷ', [89.0, 73.0, 55.8, 39.7, 11.8], time: '0535')
    ];
    final result = mergeTrainingSources(pakara, nk);
    expect(result.length, 1);
    expect(result[0].pakara, isNotNull);
    expect(result[0].trainingTime, '0535');
  });

  test('時刻が離れていても時計が合えば突き合わせる', () {
    final pakara = [
      _p('20260916', '0600',
          track: 'ウッド', f6: 89.0, f5: 73.0, f4: 55.8, f3: 39.7, f2: 24.0, f1: 11.8),
    ];
    final nk = [
      _n('20260916', 'ＣＷ', [89.0, 73.0, 55.8, 39.7, 11.8], time: '0535')
    ];
    final result = mergeTrainingSources(pakara, nk);
    expect(result.single.pakara, isNotNull);
  });

  test('時計が合わない・地区が違う・pakara に無いコースは別々の行', () {
    final pakara = [
      _p('20260916', '0700', f4: 53.0, f3: 38.5, f2: 25.0, f1: 12.6),
      _p('20260915', '0700', location: '美浦', f4: 52.4, f3: 38.1, f2: 24.8, f1: 12.3),
    ];
    final nk = [
      _n('20260916', '栗坂', [null, 52.4, 38.1, 24.8, 12.3]),
      _n('20260915', '栗坂', [null, 52.4, 38.1, 24.8, 12.3]),
      _n('20260914', 'ＤＰ', [84.7, 64.9, 50.9, 37.9, 12.0]),
    ];
    final result = mergeTrainingSources(pakara, nk);
    expect(result.length, 5);
    expect(result.where((e) => e.pakara != null && e.netkeiba != null), isEmpty);
    expect(result.map((e) => e.trainingDate).toList(),
        ['20260916', '20260916', '20260915', '20260915', '20260914']);
  });

  test('1本の pakara 行は1本の netkeiba 行にしか使わない', () {
    final pakara = [
      _p('20260917', '0712', f4: 52.4, f3: 38.1, f2: 24.8, f1: 12.3),
    ];
    final nk = [
      _n('20260917', '栗坂', [null, 52.4, 38.1, 24.8, 12.3]),
      _n('20260917', '栗坂', [null, 52.5, 38.1, 24.8, 12.3]),
    ];
    final result = mergeTrainingSources(pakara, nk);
    expect(result.where((e) => e.pakara != null).length, 1);
    expect(result.length, 2);
  });
}
