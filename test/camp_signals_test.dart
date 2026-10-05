// test/camp_signals_test.dart

// [修正] 陣営の本気度指数: 仕上げ・人のサイン（camp_signals.dart）の単体テスト。120日の区切り・前走の日付・休み明けから数えたか・前走騎手の名前のテストを追加 (v.2026.10.3+26100304)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/camp_signals.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

HorseRaceRecord _r(
  String horseId,
  String date,
  String rank,
  String jockeyId,
) {
  return HorseRaceRecord(
    horseId: horseId,
    raceId: '202605050811',
    date: date,
    venue: '5東京8',
    weather: '',
    raceNumber: '',
    raceName: '3歳以上2勝クラス',
    numberOfHorses: '',
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: '',
    rank: rank,
    jockey: '',
    jockeyId: jockeyId,
    carriedWeight: '',
    distance: '芝1600',
    trackCondition: '',
    time: '',
    margin: '',
    cornerPassage: '',
    pace: '',
    agari: '',
    horseWeight: '',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

PredictionHorseDetail _h(
  String horseId,
  int horseNumber,
  String jockeyId, {
  bool isScratched = false,
  String? horseWeight,
  bool isFirstBlinker = false,
}) {
  return PredictionHorseDetail(
    horseId: horseId,
    horseNumber: horseNumber,
    gateNumber: 1,
    horseName: '馬$horseNumber',
    sexAndAge: '牡4',
    jockey: '',
    jockeyId: jockeyId,
    carriedWeight: 57.0,
    trainerName: '',
    trainerAffiliation: '栗東',
    horseWeight: horseWeight,
    isScratched: isScratched,
    isFirstBlinker: isFirstBlinker,
  );
}

void main() {
  group('間隔の区分（仮の値）', () {
    test('日数の区切り', () {
      expect(restCategoryOf(null), RestCategory.debut);
      expect(restCategoryOf(400), RestCategory.longLayoff);
      expect(restCategoryOf(180), RestCategory.longLayoff);
      // [修正] 120日の区切りを追加 (v.2026.10.3+26100304)
      expect(restCategoryOf(179), RestCategory.longishLayoff);
      expect(restCategoryOf(120), RestCategory.longishLayoff);
      expect(restCategoryOf(119), RestCategory.layoff);
      expect(restCategoryOf(60), RestCategory.layoff);
      expect(restCategoryOf(59), RestCategory.standard);
      expect(restCategoryOf(28), RestCategory.standard);
      expect(restCategoryOf(27), RestCategory.tight);
      expect(restCategoryOf(7), RestCategory.tight);
    });

    test('日付の差', () {
      expect(daysBetween(DateTime(2026, 10, 4), DateTime(2026, 9, 13)), 21);
      expect(daysBetween(DateTime(2026, 10, 4, 15, 40), DateTime(2026, 4, 1)),
          186);
    });
  });

  test('当日の馬体重の増減', () {
    expect(bodyWeightChangeOf('478(+4)'), 4);
    expect(bodyWeightChangeOf('470(-12)'), -12);
    expect(bodyWeightChangeOf('480(0)'), 0);
    expect(bodyWeightChangeOf('計不'), isNull);
    expect(bodyWeightChangeOf(''), isNull);
    expect(bodyWeightChangeOf(null), isNull);
  });

  group('出走馬ごとのサイン', () {
    final records = {
      '2022100021': [
        _r('2022100021', '2025/12/01', '3', 'A'),
        _r('2022100021', '2026/06/01', '1', 'A'),
        _r('2022100021', '2026/06/29', '2', 'B'),
        _r('2022100021', '2026/07/20', '5', 'A'),
        _r('2022100021', '2026/08/10', '取', 'C'),
        _r('2022100021', '2026/09/13', '4', 'B'),
        _r('2022100021', '2026/10/04', '1', 'C'),
      ],
      '2022100022': [
        _r('2022100022', '2026/03/01', '2', 'B'),
        _r('2022100022', '2026/08/30', '1', 'B'),
      ],
      '2022100024': [
        _r('2022100024', '2026/04/01', '中', 'D'),
        _r('2022100024', '2026/03/01', '除', 'E'),
      ],
      '2022100025': [
        _r('2022100025', '2026/08/09', '7', 'F'),
        _r('2022100025', '2026/07/12', '6', 'G'),
        _r('2022100025', '2026/06/14', '3', 'F'),
      ],
    };
    final horses = [
      _h('2022100021', 1, 'C'),
      _h('2022100022', 7, 'B', horseWeight: '480(-6)', isFirstBlinker: true),
      _h('2022100023', 3, 'E', horseWeight: '計不'),
      _h('2022100024', 4, 'D', horseWeight: '470(+12)'),
      _h('2022100025', 5, 'H', horseWeight: '452(0)'),
      _h('2022100026', 6, 'F', isScratched: true),
    ];
    final signals = buildCampSignals(
      raceDate: DateTime(2026, 10, 4),
      horses: horses,
      recordsByHorseId: records,
    );

    test('入力の順に全頭', () {
      expect(signals.map((s) => s.horseNumber).toList(), [1, 7, 3, 4, 5, 6]);
    });

    test('使い詰め・乗り替わり・前走騎手が同じレースの別馬に騎乗', () {
      final s = signals[0];
      expect(s.canJudge, isTrue);
      expect(s.daysSinceLastStart, 21);
      expect(s.restCategory, RestCategory.tight);
      expect(s.startNumberSinceLayoff, 5);
      expect(s.isOverworked, isTrue);
      expect(s.previousJockeyId, 'B');
      expect(s.isJockeyChanged, isTrue);
      expect(s.ridesOnThisHorse, 0);
      expect(s.isMainJockey, isFalse);
      // [修正] 馬番7ではなく、その馬の馬ID (v.2026.10.6+26100601)
      expect(s.previousJockeyRidingHorseId, '2022100022');
      expect(s.isFirstBlinker, isFalse);
      expect(s.bodyWeightChange, isNull);
    });

    test('主戦の継続騎乗・ブリンカー初・馬体重', () {
      final s = signals[1];
      expect(s.daysSinceLastStart, 35);
      expect(s.restCategory, RestCategory.standard);
      expect(s.startNumberSinceLayoff, 2);
      expect(s.isOverworked, isFalse);
      expect(s.isJockeyChanged, isFalse);
      expect(s.ridesOnThisHorse, 2);
      expect(s.isMainJockey, isTrue);
      // [修正] 馬番ではなく馬ID (v.2026.10.6+26100601)
      expect(s.previousJockeyRidingHorseId, isNull);
      expect(s.isFirstBlinker, isTrue);
      expect(s.bodyWeightChange, -6);
    });

    test('過去走が無い馬は判定しない（新馬戦・未勝利戦でないとき）', () {
      final s = signals[2];
      expect(s.canJudge, isFalse);
      expect(s.restCategory, RestCategory.unknown);
      expect(s.daysSinceLastStart, isNull);
      expect(s.startNumberSinceLayoff, 1);
      expect(s.isOverworked, isFalse);
      expect(s.isJockeyChanged, isNull);
      expect(s.ridesOnThisHorse, 0);
      expect(s.isMainJockey, isFalse);
      expect(s.bodyWeightChange, isNull);
    });

    test('長期休養明け（中止は出走・除外は数えない）', () {
      final s = signals[3];
      expect(s.daysSinceLastStart, 186);
      expect(s.restCategory, RestCategory.longLayoff);
      expect(s.startNumberSinceLayoff, 1);
      expect(s.previousJockeyId, 'D');
      expect(s.isJockeyChanged, isFalse);
      expect(s.ridesOnThisHorse, 1);
      expect(s.isMainJockey, isTrue);
      expect(s.bodyWeightChange, 12);
    });

    test('休み明けが無ければデビュー戦から数える・取消の馬の騎手は探さない', () {
      final s = signals[4];
      expect(s.daysSinceLastStart, 56);
      expect(s.restCategory, RestCategory.standard);
      expect(s.startNumberSinceLayoff, 4);
      expect(s.isOverworked, isFalse);
      expect(s.previousJockeyId, 'F');
      expect(s.isJockeyChanged, isTrue);
      // [修正] 馬番ではなく馬ID (v.2026.10.6+26100601)
      expect(s.previousJockeyRidingHorseId, isNull);
      expect(s.bodyWeightChange, 0);
    });

    // [追加] 前走の日付・休み明けから数えたか (v.2026.10.3+26100304)
    test('前走の日付・休み明けから数えたか', () {
      expect(signals[0].lastStartDate, DateTime(2026, 9, 13));
      expect(signals[0].isCountedFromLayoff, isTrue);
      expect(signals[1].lastStartDate, DateTime(2026, 8, 30));
      expect(signals[1].isCountedFromLayoff, isTrue);
      expect(signals[2].lastStartDate, isNull);
      expect(signals[2].isCountedFromLayoff, isFalse);
      expect(signals[3].lastStartDate, DateTime(2026, 4, 1));
      expect(signals[3].isCountedFromLayoff, isTrue);
      expect(signals[4].lastStartDate, DateTime(2026, 8, 9));
      expect(signals[4].isCountedFromLayoff, isFalse);
      expect(signals[0].previousJockeyName, isNull);
    });
  });

  test('新馬戦・未勝利戦では過去走が無い馬を初出走とみなす', () {
    final signals = buildCampSignals(
      raceDate: DateTime(2026, 10, 4),
      horses: [_h('2024100001', 1, 'A')],
      recordsByHorseId: const {},
      isMaidenOrNewcomerRace: true,
    );
    expect(signals.single.canJudge, isTrue);
    expect(signals.single.restCategory, RestCategory.debut);
    expect(signals.single.startNumberSinceLayoff, 1);
  });

  // [追加] 前走騎手の名前（過去走の騎手列。前後の空白を除く） (v.2026.10.3+26100304)
  test('前走騎手の名前は過去走の騎手列から読む', () {
    HorseRaceRecord rec(String horseId, String date, String jockey,
        String jockeyId) {
      return HorseRaceRecord(
        horseId: horseId,
        raceId: '202605050811',
        date: date,
        venue: '5東京8',
        weather: '',
        raceNumber: '',
        raceName: '3歳以上2勝クラス',
        numberOfHorses: '',
        frameNumber: '',
        horseNumber: '',
        odds: '',
        popularity: '',
        rank: '3',
        jockey: jockey,
        jockeyId: jockeyId,
        carriedWeight: '',
        distance: '芝1600',
        trackCondition: '',
        time: '',
        margin: '',
        cornerPassage: '',
        pace: '',
        agari: '',
        horseWeight: '',
        winnerOrSecondHorse: '',
        prizeMoney: '',
      );
    }

    final signals = buildCampSignals(
      raceDate: DateTime(2026, 10, 4),
      horses: [_h('2022100031', 1, '05339'), _h('2022100032', 2, '')],
      recordsByHorseId: {
        '2022100031': [
          rec('2022100031', '2026/09/06', ' 武豊 ', '00666'),
          rec('2022100031', '2026/08/09', 'ルメール', '05339'),
        ],
        '2022100032': [
          rec('2022100032', '2026/09/06', '', ''),
        ],
      },
    );
    expect(signals[0].previousJockeyName, '武豊');
    expect(signals[0].previousJockeyId, '00666');
    expect(signals[0].isJockeyChanged, isTrue);
    expect(signals[0].lastStartDate, DateTime(2026, 9, 6));
    expect(signals[0].daysSinceLastStart, 28);
    expect(signals[0].restCategory, RestCategory.standard);
    expect(signals[0].startNumberSinceLayoff, 3);
    expect(signals[0].isCountedFromLayoff, isFalse);
    expect(signals[1].previousJockeyName, isNull);
    expect(signals[1].isJockeyChanged, isNull);
  });
}
