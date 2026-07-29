// test/race_analyzer_speed_index_wiring_test.dart

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

/// フェーズ5-2で追加したスピード指数の展開配線が、既存呼び出し(speedIndexParams未指定)の
/// 挙動を一切変えないことを検証するリグレッションテスト。
/// RaceAnalyzer.simulateRaceDevelopment内部でCoursePresetRepository経由のDBアクセスが
/// 発生するため、sqflite_common_ffiでDbProvider実体を動かし、実際のcourse_presetsを使う。
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
    // [修正] 実DBパスをhorse_speed_index_repository_test.dartと共有すると、
    // flutter testの並列実行時にファイル競合でflakyになるため、
    // ファイル固有の一時ディレクトリへ隔離する (v.2026.7.30+26073001)
    final tempDir = await Directory.systemTemp
        .createTemp('race_analyzer_speed_index_wiring_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    await _resetDb();
  });

  tearDown(() async {
    await _resetDb();
  });

  test('speedIndexParams未指定(既存呼び出し)とconfidence=0全馬の出力は完全一致する', () async {
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

    // 既存呼び出し: speedIndexParams を渡さない(デフォルトのconst {})
    final baseline = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      paceOverride: 'ハイペース',
    );

    // 全馬confidence=0で明示的にspeedIndexParamsを渡すケース
    // (confidence>0ガードが必ず失敗するため、コード上の係数の値に関わらず無効化される)
    final zeroConfidenceParams = <String, HorseSpeedIndex>{
      for (final h in horses)
        h.horseNumber.toString(): HorseSpeedIndex(
          horseId: h.horseId,
          bestIndex: 95.0,
          recentAvgIndex: 90.0,
          trend: 1.0,
          confidence: 0.0,
          sampleCount: 5,
          calculatedAt: '2026-07-30T00:00:00.000',
        ),
    };
    final withZeroConfidence = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: zeroConfidenceParams,
      paceOverride: 'ハイペース',
    );

    expect(withZeroConfidence, equals(baseline));

    // confidence>0かつ極端な乖離を与えた場合は、baselineと結果が変わることも確認する
    // (係数を小さく保つ設計上、緩やかな差では最終順位に現れないことがあるため、
    // 配線自体が死んだコードでないことを検出できるよう意図的に極端な値を用いる)
    // [修正] キーはhorseIdではなくhorseNumber文字列(実装の参照キーと一致させる)
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
    final withActiveSpeedIndex = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      cornersToPredict,
      const {},
      horsesOverride: horses,
      speedIndexParams: activeParams,
      paceOverride: 'ハイペース',
    );

    expect(withActiveSpeedIndex, isNot(equals(baseline)));
  });
}
