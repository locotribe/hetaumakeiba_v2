// test/daily_track_variant_resolver_test.dart

// [追加] フェーズ7 ステップ2: DailyTrackVariantResolverの単体テスト。
// fixture DB(race_resultsのみのin-memory sqlite)で既知の変量値を検証する。
// baseTime(ダ1800・東京・良・2023年)はSpeedIndexBaseTime.resolveの実装どおり
// dirtConst(110.104) + dirtYearTrend(-0.0689)*(2023-2023) = 110.104 秒になる
// (venueOffset['東京']=0.0・condOffset['良']=0.0のため他項は全て0) (v.2026.9.4)

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/logic/analysis/daily_track_variant_resolver.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

HorseResult _horseResult({
  required String rank,
  required String horseNumber,
  required String time,
}) {
  return HorseResult(
    rank: rank,
    frameNumber: horseNumber,
    horseNumber: horseNumber,
    horseName: 'テスト馬$horseNumber',
    horseId: 'H$horseNumber',
    sexAndAge: '牡3',
    weightCarried: '56',
    jockeyName: 'テスト騎手',
    jockeyId: '00000',
    time: time,
    margin: '0.0',
    cornerRanking: '1-1-1-1',
    agari: '35.0',
    odds: '5.0',
    popularity: '1',
    horseWeight: '480(0)',
    trainerName: 'テスト調教師',
    trainerAffiliation: '美浦',
    ownerName: 'テスト馬主',
    prizeMoney: '1000',
  );
}

RaceResult _raceResult({
  required String raceId,
  required String raceInfo,
  required List<HorseResult> horseResults,
}) {
  return RaceResult(
    raceId: raceId,
    raceTitle: 'テストレース',
    raceInfo: raceInfo,
    raceDate: '2023年5月1日',
    raceGrade: '4歳以上1勝クラス',
    horseResults: horseResults,
    refunds: const [],
    cornerPassages: const [],
    lapTimes: const [],
  );
}

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // db_provider.dart の tableRaceResults と同一スキーマ
    await db.execute('''
      CREATE TABLE ${DbConstants.tableRaceResults}(
        race_id TEXT PRIMARY KEY,
        race_result_json TEXT
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertRace(RaceResult race) async {
    await db.insert(DbConstants.tableRaceResults, {
      'race_id': race.raceId,
      'race_result_json': raceResultToJson(race),
    });
  }

  DailyTrackVariantResolver buildResolver() =>
      DailyTrackVariantResolver(dbAccessor: () async => db);

  const dirtInfo = 'ダ右1800m / 天候 : 晴 / ダート : 良';
  const turfInfo = '芝右1800m / 天候 : 晴 / 芝 : 良';

  test('複数レース・十分な頭数(ダート)で平均残差が変量として返る', () async {
    // prefix10=2023050101(2023年・05=東京・1回1日目)。
    // レースA(残差+2.0×5頭)・レースB(残差+1.0×5頭)で加重平均1.5秒を期待する。
    await insertRace(_raceResult(
      raceId: '202305010101',
      raceInfo: dirtInfo,
      horseResults: List.generate(
        5,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '112.104', // baseTime(110.104) + 2.0
        ),
      ),
    ));
    await insertRace(_raceResult(
      raceId: '202305010102',
      raceInfo: dirtInfo,
      horseResults: List.generate(
        5,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '111.104', // baseTime(110.104) + 1.0
        ),
      ),
    ));

    final resolver = buildResolver();
    final result = await resolver
        .resolveForRaceIds(['202305010101', '202305010102']);

    expect(result['202305010101'], closeTo(1.5, 0.001));
    expect(result['202305010102'], closeTo(1.5, 0.001));
  });

  test('有効頭数が閾値(8)未満のサーフェスは変量0.0になる', () async {
    // prefix10=2023050102。芝1レース・3頭のみ(<8)→variant無効。
    await insertRace(_raceResult(
      raceId: '202305010201',
      raceInfo: turfInfo,
      horseResults: List.generate(
        3,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '110.539', // 芝1800・東京・良・2023年のbaseTimeより速い(残差負)
        ),
      ),
    ));

    final resolver = buildResolver();
    final result = await resolver.resolveForRaceIds(['202305010201']);

    expect(result['202305010201'], 0.0);
  });

  test('寄与レース数が閾値(2)未満のサーフェスは頭数十分でも変量0.0になる', () async {
    // prefix10=2023050103。ダート1レースのみ・10頭(頭数は十分)だがレース数1(<2)→無効。
    await insertRace(_raceResult(
      raceId: '202305010301',
      raceInfo: dirtInfo,
      horseResults: List.generate(
        10,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '113.104', // baseTime(110.104) + 3.0
        ),
      ),
    ));

    final resolver = buildResolver();
    final result = await resolver.resolveForRaceIds(['202305010301']);

    expect(result['202305010301'], 0.0);
  });

  test('race_resultsに存在しないraceIdは変量0.0になる', () async {
    final resolver = buildResolver();
    final result = await resolver.resolveForRaceIds(['202305010499']);

    expect(result['202305010499'], 0.0);
  });

  test('同一prefix10内で芝・ダートが混在しても各サーフェス別に平均される', () async {
    // prefix10=2023050105。ダート(残差+1.0×8頭・2レース)と芝(残差-1.0×8頭・2レース)を
    // 同じ開催日に混在させ、互いに打ち消し合わず別々に集計されることを確認する。
    await insertRace(_raceResult(
      raceId: '202305010501',
      raceInfo: dirtInfo,
      horseResults: List.generate(
        4,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '111.104', // ダートbaseTime(110.104) + 1.0
        ),
      ),
    ));
    await insertRace(_raceResult(
      raceId: '202305010502',
      raceInfo: dirtInfo,
      horseResults: List.generate(
        4,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '111.104',
        ),
      ),
    ));
    await insertRace(_raceResult(
      raceId: '202305010503',
      raceInfo: turfInfo,
      horseResults: List.generate(
        4,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '105.539', // 芝baseTime(106.539) - 1.0
        ),
      ),
    ));
    await insertRace(_raceResult(
      raceId: '202305010504',
      raceInfo: turfInfo,
      horseResults: List.generate(
        4,
        (i) => _horseResult(
          rank: '${i + 1}',
          horseNumber: '${i + 1}',
          time: '105.539',
        ),
      ),
    ));

    final resolver = buildResolver();
    final result = await resolver.resolveForRaceIds(
        ['202305010501', '202305010503']);

    expect(result['202305010501'], closeTo(1.0, 0.001));
    expect(result['202305010503'], closeTo(-1.0, 0.001));
  });
}
