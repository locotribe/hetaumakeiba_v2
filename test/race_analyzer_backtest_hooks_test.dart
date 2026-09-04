// test/race_analyzer_backtest_hooks_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// フェーズ6 バックテスト・ハーネス§1で追加した outFinalPositionScores /
/// speedFactorOverride の2引数を検証する。どちらも省略時(null)は
/// race_analyzer_speed_index_wiring_test.dartが担保する既存挙動を変えない。
Future<String> _dbFilePath() async {
  final dir = await databaseFactory.getDatabasesPath();
  return path.join(dir, DbConstants.dbName);
}

Future<void> _resetDb() async {
  await DbProvider().closeDb();
  final file = File(await _dbFilePath());
  if (await file.exists()) {
    await file.delete();
  }
}

PredictionHorseDetail _horse({
  required String horseId,
  required int horseNumber,
  required int gateNumber,
  required double carriedWeight,
}) {
  return PredictionHorseDetail(
    horseId: horseId,
    horseNumber: horseNumber,
    gateNumber: gateNumber,
    horseName: 'テスト馬$horseNumber',
    sexAndAge: '牡4',
    jockey: 'テスト騎手',
    jockeyId: 'J$horseNumber',
    carriedWeight: carriedWeight,
    trainerName: 'テスト調教師',
    trainerAffiliation: '美浦',
    isScratched: false,
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir =
        await Directory.systemTemp.createTemp('race_analyzer_backtest_hooks_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    await _resetDb();
  });

  tearDown(() async {
    await _resetDb();
  });

  final horses = [
    _horse(horseId: 'H1', horseNumber: 1, gateNumber: 1, carriedWeight: 56.0),
    _horse(horseId: 'H2', horseNumber: 2, gateNumber: 2, carriedWeight: 57.0),
    _horse(horseId: 'H3', horseNumber: 3, gateNumber: 3, carriedWeight: 58.0),
  ];
  final raceData = PredictionRaceData(
    raceId: '202505021211',
    raceName: 'テストG1レース',
    raceDate: '2026年7月30日(木)',
    venue: '東京',
    raceNumber: '11',
    shutubaTableUrl: '',
    raceGrade: 'G1',
    raceDetails1: '芝2000m (左 A)',
    horses: horses,
  );
  final allPastRecords = <String, List<HorseRaceRecord>>{
    'H1': [],
    'H2': [],
    'H3': [],
  };
  const cornersToPredict = ['4コーナー', '直線'];
  final activeParams = <String, HorseSpeedIndex>{
    '1': HorseSpeedIndex(
      horseId: 'H1',
      bestIndex: 300.0,
      recentAvgIndex: 300.0,
      trend: 2.0,
      confidence: 1.0,
      sampleCount: 8,
      calculatedAt: '2026-07-30T00:00:00.000',
    ),
    '2': HorseSpeedIndex(
      horseId: 'H2',
      bestIndex: -100.0,
      recentAvgIndex: -100.0,
      trend: -1.0,
      confidence: 1.0,
      sampleCount: 8,
      calculatedAt: '2026-07-30T00:00:00.000',
    ),
    '3': HorseSpeedIndex(
      horseId: 'H3',
      bestIndex: 100.0,
      recentAvgIndex: 100.0,
      trend: 0.0,
      confidence: 1.0,
      sampleCount: 8,
      calculatedAt: '2026-07-30T00:00:00.000',
    ),
  };

  test('outFinalPositionScoresを渡すと直線処理後の生positionScoreが馬番キーで格納される',
      () async {
    final out = <String, double>{};
    await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
      outFinalPositionScores: out,
    );

    expect(out.keys.toSet(), {'1', '2', '3'});
    // 全馬の値が有限数として格納されていること
    for (final v in out.values) {
      expect(v.isFinite, isTrue);
    }
  });

  test('outFinalPositionScoresを渡さない(既存呼び出し)場合は例外なく従来どおり動作する', () async {
    final development = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      paceOverride: 'ハイペース',
    );
    expect(development['直線'], isNotNull);
  });

  test('speedFactorOverride:0.0を渡すとスピード指数の効果が完全に無効化され、'
      'speedIndexParams未指定時と同じ隊列になる', () async {
    final withOverrideZero = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
      speedFactorOverride: 0.0,
    );
    final withoutSpeedIndex = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      paceOverride: 'ハイペース',
    );
    expect(withOverrideZero, equals(withoutSpeedIndex));
  });

  test('speedFactorOverrideを省略(null)した場合は既存の_kSpeedFactor4c/Straightで'
      '算出した結果と完全一致する(挙動不変)', () async {
    final withoutOverride = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
    );
    final withExplicitNullOverride = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
      speedFactorOverride: null,
    );
    expect(withExplicitNullOverride, equals(withoutOverride));
  });

  test('speedFactorOverrideを既定係数(0.15相当)より大きくすると、'
      '直線処理後の生positionScore(outFinalPositionScores)が変化する(配線の生死確認)。'
      '隊列文字列は既にグループが完全分離済みだと飽和して変化しない場合があるため、'
      '生スコアで確認する', () async {
    final outDefaultFactor = <String, double>{};
    await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
      outFinalPositionScores: outDefaultFactor,
    );
    final outLargeFactor = <String, double>{};
    await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
      speedFactorOverride: 5.0,
      outFinalPositionScores: outLargeFactor,
    );
    expect(outLargeFactor, isNot(equals(outDefaultFactor)));
  });
}
