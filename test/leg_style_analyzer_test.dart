// test/leg_style_analyzer_test.dart
// [修正] 脚質プロフィール(leg_style_analyzer)の回帰テスト。基底のTARGET3グループ化＋自在バランス条件に更新。マクリ/JSON温存も確認 (v.2026.9.26+26092606)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

HorseRaceRecord _rec({
  required String cornerPassage,
  required String numberOfHorses,
  String agari = '35.0',
  String rank = '5',
}) {
  return HorseRaceRecord(
    horseId: 'h',
    raceId: 'r',
    date: '2025/01/01',
    venue: '1東京1',
    weather: '晴',
    raceNumber: '1',
    raceName: 'テスト',
    numberOfHorses: numberOfHorses,
    frameNumber: '1',
    horseNumber: '1',
    odds: '1.0',
    popularity: '1',
    rank: rank,
    jockey: 'J',
    jockeyId: 'j',
    carriedWeight: '55',
    distance: '芝1600',
    trackCondition: '良',
    time: '1:33.0',
    margin: '',
    cornerPassage: cornerPassage,
    pace: '',
    agari: agari,
    horseWeight: '460(0)',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

void main() {
  group('analyzeSingleRaceStyle', () {
    test('4コーナーで大きく順位を上げたらマクリ（温存）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '10-9-8-2', numberOfHorses: '16')), 'マクリ');
    });
    test('道中で先頭なら逃げ', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16')), '逃げ');
    });
    test('道中後方→最後だけ先頭は逃げにしない（先行）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '2-1', numberOfHorses: '6')), '先行');
    });
    test('中団は差し（TARGET第2グループ）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '5-6-7-7', numberOfHorses: '16')), '差し');
    });
    test('最後方は追込（TARGET第3グループ）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16')), '追込');
    });
    test('通過が取れなければ不明', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '', numberOfHorses: '16')), '不明');
    });
  });

  group('getRunningStyle: primaryStyle', () {
    test('全レース道中先頭ならprimaryStyleは逃げ・分布も逃げ100%', () {
      final records = [
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16', rank: '1'),
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16', rank: '2'),
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16', rank: '3'),
      ];
      final profile = LegStyleAnalyzer.getRunningStyle(records);
      expect(profile.primaryStyle, '逃げ');
      expect(profile.styleDistribution['逃げ'], 1.0);
    });

    test('マクリ率が高いとprimaryStyleはマクリ（温存確認）', () {
      final records = [
        _rec(cornerPassage: '10-9-8-2', numberOfHorses: '16', rank: '1'),
        _rec(cornerPassage: '10-9-8-2', numberOfHorses: '16', rank: '5'),
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16', rank: '3'),
      ];
      final profile = LegStyleAnalyzer.getRunningStyle(records);
      expect(profile.primaryStyle, 'マクリ');
    });
  });

  group('getRunningStyle: 自在バランス条件', () {
    test('前後がバランスし最大脚質<0.5なら自在', () {
      // 逃げ1/先行1/追込1 → 前0.67・後0.33・最大0.33
      final records = [
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16'),
        _rec(cornerPassage: '3-3-3-3', numberOfHorses: '16'),
        _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16'),
      ];
      final profile = LegStyleAnalyzer.getRunningStyle(records);
      expect(profile.primaryStyle, '自在');
    });

    test('後方偏重（前シェア<0.3）は自在にせず最大脚質にする', () {
      // 先行2/差し3/追込4 → 前0.22(<0.3)・最大は追込0.44(<0.5)。自在にならず追込
      final records = [
        _rec(cornerPassage: '3-3-3-3', numberOfHorses: '16'),
        _rec(cornerPassage: '3-3-3-3', numberOfHorses: '16'),
        _rec(cornerPassage: '8-8-8-8', numberOfHorses: '16'),
        _rec(cornerPassage: '8-8-8-8', numberOfHorses: '16'),
        _rec(cornerPassage: '8-8-8-8', numberOfHorses: '16'),
        _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16'),
        _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16'),
        _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16'),
        _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16'),
      ];
      final profile = LegStyleAnalyzer.getRunningStyle(records);
      expect(profile.primaryStyle, '追込');
    });
  });

  group('getRunningStyle: JSON温存', () {
    test('toJson/fromJson で往復してもprimaryStyle・分布が不変', () {
      final records = [
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16', rank: '1'),
        _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16', rank: '4'),
      ];
      final profile = LegStyleAnalyzer.getRunningStyle(records);
      final restored = LegStyleProfile.fromJson(profile.toJson());
      expect(restored.primaryStyle, profile.primaryStyle);
      expect(restored.styleDistribution['逃げ'], profile.styleDistribution['逃げ']);
    });
  });
}
