// test/track_state_resolver_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/logic/analysis/track_state_resolver.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // db_provider.dart の tableTrackConditions と同一スキーマ
    await db.execute('''
      CREATE TABLE track_conditions(
        track_condition_id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,
        week_day TEXT NOT NULL,
        cushion_value REAL,
        moisture_turf_goal REAL,
        moisture_turf_4c REAL,
        moisture_dirt_goal REAL,
        moisture_dirt_4c REAL
      )
    ''');

    // 既知ケース1: クッション値がある芝(2021年以降, 09=阪神)
    await db.insert('track_conditions', {
      'track_condition_id': 202109010101,
      'date': '2021-01-09',
      'week_day': 'sa',
      'cushion_value': 9.5,
      'moisture_turf_goal': 12.0,
      'moisture_turf_4c': 11.0,
      'moisture_dirt_goal': null,
      'moisture_dirt_4c': null,
    });

    // 既知ケース2: ダート(05=東京)
    await db.insert('track_conditions', {
      'track_condition_id': 202305010511,
      'date': '2023-05-01',
      'week_day': 'mo',
      'cushion_value': 8.0,
      'moisture_turf_goal': 14.0,
      'moisture_turf_4c': 13.0,
      'moisture_dirt_goal': 10.0,
      'moisture_dirt_4c': 9.5,
    });

    // 既知ケース3: 2019年以前の芝(06=中山、クッション値未計測)
    await db.insert('track_conditions', {
      'track_condition_id': 201806010201,
      'date': '2018-06-01',
      'week_day': 'fr',
      'cushion_value': null,
      'moisture_turf_goal': 13.5,
      'moisture_turf_4c': 12.5,
      'moisture_dirt_goal': null,
      'moisture_dirt_4c': null,
    });
  });

  tearDown(() async {
    await db.close();
  });

  TrackStateResolver buildResolver() =>
      TrackStateResolver(dbAccessor: () async => db);

  test('クッション値がある芝(2021年以降)はcushionが非null', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '202109010311',
      date: '2021/01/09',
      surface: '芝',
    );
    expect(result.cushion, 9.5);
    expect(result.moisture, 12.0);
  });

  test('ダートはmoisture_dirtが非null、cushionはnull', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '202305010511',
      date: '2023/05/01',
      surface: 'ダ',
    );
    expect(result.cushion, isNull);
    expect(result.moisture, 10.0);
  });

  test('2019年以前の芝はcushionがnull、含水率は取得できる', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '201806010111',
      date: '2018/06/01',
      surface: '芝',
    );
    expect(result.cushion, isNull);
    expect(result.moisture, 13.5);
  });

  test('日付完全一致が無ければ同一週内(±3日)で最近傍を採用する', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '202109010311',
      date: '2021/01/11', // 完全一致(01/09)の2日後
      surface: '芝',
    );
    expect(result.cushion, 9.5);
  });

  test('±3日を超える場合は該当なしでcushion・moistureともにnull', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '202109010311',
      date: '2021/01/20',
      surface: '芝',
    );
    expect(result.cushion, isNull);
    expect(result.moisture, isNull);
  });

  test('raceIdが空でもfallbackVenueNameから場コードを解決できる', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '',
      fallbackVenueName: '阪神',
      date: '2021/01/09',
      surface: '芝',
    );
    expect(result.cushion, 9.5);
    expect(result.moisture, 12.0);
  });

  test('該当場コードのレコードが無い場合はnullを返す', () async {
    final resolver = buildResolver();
    final result = await resolver.resolve(
      raceId: '202110010311', // 10=小倉 (フィクスチャなし)
      date: '2021/01/09',
      surface: '芝',
    );
    expect(result.cushion, isNull);
    expect(result.moisture, isNull);
  });
}
