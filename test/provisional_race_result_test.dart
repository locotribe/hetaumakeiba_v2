// test/provisional_race_result_test.dart

// [追加] 陣営の本気度指数 実施順4: 速報版のレース結果の判定（provisional_race_result.dart）の単体テスト (v.2026.10.2+26100208)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/provisional_race_result.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

HorseResult _horse(String prizeMoney) {
  return HorseResult(
    rank: '1',
    frameNumber: '1',
    horseNumber: '1',
    horseName: 'テストホース',
    horseId: '2022100001',
    sexAndAge: '牡4',
    weightCarried: '57',
    jockeyName: '',
    jockeyId: '',
    time: '',
    margin: '',
    cornerRanking: '',
    agari: '',
    odds: '',
    popularity: '',
    horseWeight: '',
    trainerName: '',
    trainerAffiliation: '',
    ownerName: '',
    prizeMoney: prizeMoney,
  );
}

RaceResult _result({
  required String raceId,
  required String raceDate,
  required List<String> prizes,
}) {
  return RaceResult(
    raceId: raceId,
    raceTitle: 'テスト',
    raceInfo: '',
    raceDate: raceDate,
    raceGrade: '',
    horseResults: prizes.map(_horse).toList(),
    refunds: const [],
    cornerPassages: const [],
    lapTimes: const [],
  );
}

void main() {
  group('isJraRaceId', () {
    test('競馬場コード01〜10はJRA', () {
      expect(isJraRaceId('202601010101'), isTrue);
      expect(isJraRaceId('202610020811'), isTrue);
    });

    test('地方・短すぎるIDはJRAではない', () {
      expect(isJraRaceId('202435081212'), isFalse);
      expect(isJraRaceId('202600000101'), isFalse);
      expect(isJraRaceId('2026'), isFalse);
      expect(isJraRaceId(''), isFalse);
    });
  });

  group('isProvisionalJraRaceResult', () {
    test('JRAで開催日が空なら速報版（小倉記念の例）', () {
      expect(
          isProvisionalJraRaceResult(_result(
              raceId: '202610020811', raceDate: '', prizes: ['', ''])),
          isTrue);
    });

    test('JRAで全頭の賞金が空なら速報版', () {
      expect(
          isProvisionalJraRaceResult(_result(
              raceId: '202606040611', raceDate: '2026年09月27日', prizes: ['', ''])),
          isTrue);
    });

    test('JRAで賞金と開催日があればdb版', () {
      expect(
          isProvisionalJraRaceResult(_result(
              raceId: '202608030211',
              raceDate: '2026年04月26日',
              prizes: ['6,027.4', '2,436.4', ''])),
          isFalse);
    });

    test('地方は賞金が空でも速報版としない（クラスターCの例）', () {
      expect(
          isProvisionalJraRaceResult(_result(
              raceId: '202435081212', raceDate: '2024年08月12日', prizes: ['', ''])),
          isFalse);
      expect(
          isProvisionalJraRaceResult(
              _result(raceId: '202435081212', raceDate: '', prizes: [''])),
          isFalse);
    });

    test('JRAで開催日があり出走馬が空なら速報版としない', () {
      expect(
          isProvisionalJraRaceResult(_result(
              raceId: '202608030211', raceDate: '2026年04月26日', prizes: [])),
          isFalse);
    });
  });
}
