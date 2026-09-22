// test/training_factor_netkeiba_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/historical_match_engine_factors/training_factor.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

TrainingTimeModel _p(String horseId, String date, double f4) => TrainingTimeModel(
      horseId: horseId,
      trainingDate: date,
      trainingTime: '0700',
      trackType: '坂路',
      location: '栗東',
      f4: f4,
      f3: f4 - 14.0,
      f2: f4 - 27.0,
      f1: 12.5,
    );

Map<String, List<TrainingTimeModel>> _sampleData() => {
      'h1': [_p('h1', '20260916', 53.0), _p('h1', '20260909', 53.5)],
      'h2': [_p('h2', '20260916', 54.5), _p('h2', '20260909', 55.0)],
    };

void main() {
  group('netkeibaAdjustment', () {
    test('評価の加減点', () {
      expect(TrainingFactor.netkeibaAdjustment(rank: 'A'), 1.5);
      expect(TrainingFactor.netkeibaAdjustment(rank: 'B'), 0.0);
      expect(TrainingFactor.netkeibaAdjustment(rank: 'C'), -1.0);
      expect(TrainingFactor.netkeibaAdjustment(rank: 'D'), -2.0);
      expect(TrainingFactor.netkeibaAdjustment(rank: null), 0.0);
    });
    test('併せ馬と一番時計', () {
      expect(
          TrainingFactor.netkeibaAdjustment(rank: 'B', partners: const [
            TrainingPartner(side: '内', name: 'A', text: '一杯と併せ０秒６先着'),
          ]),
          0.5);
      expect(
          TrainingFactor.netkeibaAdjustment(rank: 'B', partners: const [
            TrainingPartner(side: '外', name: 'A', text: '馬也に０秒３遅れ'),
          ]),
          -0.5);
      expect(TrainingFactor.netkeibaAdjustment(rank: 'A', isBestTime: true), 2.0);
    });
  });

  test('rankOnlyScore', () {
    expect(TrainingFactor.rankOnlyScore('A'), 3.0);
    expect(TrainingFactor.rankOnlyScore('B'), 1.0);
    expect(TrainingFactor.rankOnlyScore('C'), -1.0);
    expect(TrainingFactor.rankOnlyScore('D'), -3.0);
    expect(TrainingFactor.rankOnlyScore(null), -5.0);
  });

  test('坂路・ウッドの時計が無い馬は netkeiba の評価だけで採点する', () {
    final result = TrainingFactor().evaluate(
      'h9',
      const {},
      '牡4',
      review: const NetkeibaTrainingReview(
          raceId: 'r', horseId: 'h9', rank: 'A', critic: '態勢整う'),
    );
    expect(result.score, 3.0);
    expect(result.rank, 'A');
    expect(result.diagnosis, contains('netkeibaの評価のみ'));
  });

  test('評価も無ければ従来どおり -5.0', () {
    final result = TrainingFactor().evaluate('h9', const {}, '牡4');
    expect(result.score, -5.0);
    expect(result.diagnosis, '調教データなし');
  });

  test('評価Cの加点分だけ点が下がり、診断文に netkeiba が付く', () {
    final base = TrainingFactor().evaluate('h1', _sampleData(), '牡4');
    final withRank = TrainingFactor().evaluate(
      'h1',
      _sampleData(),
      '牡4',
      review: const NetkeibaTrainingReview(
          raceId: 'r', horseId: 'h1', rank: 'C', critic: '良化薄い'),
    );
    expect(withRank.score, closeTo(base.score - 1.0, 0.001));
    expect(withRank.diagnosis, contains('netkeiba: C 良化薄い'));
    expect(base.diagnosis, isNot(contains('netkeiba')));
  });

  test('netkeiba だけにある坂路の時計も計算に使う', () {
    final onlyNetkeiba = TrainingFactor().evaluate(
      'h1',
      const {},
      '牡4',
      netkeibaTrainingMap: {
        'h1': [
          NetkeibaTrainingSession(
            horseId: 'h1',
            trainingDate: '20260916',
            courseRaw: '栗坂',
            seq: 0,
            slots: [null, 53.0, 39.0, 26.0, 12.5],
          ),
        ],
      },
    );
    expect(onlyNetkeiba.diagnosis, isNot('調教データなし'));
    expect(onlyNetkeiba.score, greaterThan(-5.0));
  });
}
