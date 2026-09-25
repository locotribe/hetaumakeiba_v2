// test/leg_style_analyzer_test.dart
// [追加] 脚質プロフィール(leg_style_analyzer)の回帰テスト。基底委譲後もマクリ/自在・JSONが温存されることを確認 (v.2026.9.26+26092605)

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
    test('4コーナーで大きく順位を上げたらマクリ', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '10-9-8-2', numberOfHorses: '16')), 'マクリ');
    });
    test('最終コーナー1位は逃げ（基底委譲）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '1-1-1-1', numberOfHorses: '16')), '逃げ');
    });
    test('少頭数の1位も逃げ（2コーナー）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '2-1', numberOfHorses: '6')), '逃げ');
    });
    test('中団は差し（基底委譲）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '5-6-7-7', numberOfHorses: '16')), '差し');
    });
    test('最後方は追込（基底委譲）', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '16-16-15-14', numberOfHorses: '16')), '追込');
    });
    test('通過が取れなければ不明', () {
      expect(LegStyleAnalyzer.analyzeSingleRaceStyle(
          _rec(cornerPassage: '', numberOfHorses: '16')), '不明');
    });
  });

  group('getRunningStyle', () {
    test('全レース先頭ならprimaryStyleは逃げ・分布も逃げ100%', () {
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

    test('toJson/fromJson で往復してもprimaryStyle・分布が不変（スキーマ温存）', () {
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
