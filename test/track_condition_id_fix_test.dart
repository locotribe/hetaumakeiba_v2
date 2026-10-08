// test/track_condition_id_fix_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/db/track_condition_id_fix.dart';

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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertRow(int id, String date, String weekDay, double turfGoal) async {
    await db.insert('track_conditions', {
      'track_condition_id': id,
      'date': date,
      'week_day': weekDay,
      'cushion_value': null,
      'moisture_turf_goal': turfGoal,
      'moisture_turf_4c': turfGoal,
      'moisture_dirt_goal': 5.0,
      'moisture_dirt_4c': 5.0,
    });
  }

  Future<List<int>> allIds() async {
    final rows = await db.query(
      'track_conditions',
      columns: ['track_condition_id'],
      orderBy: 'track_condition_id',
    );
    return rows.map((m) => m['track_condition_id'] as int).toList();
  }

  test('表の5件は日次(9〜10桁目)だけが違い、ほかの桁は同じ', () {
    expect(kTrackConditionDdFixes.length, 5);
    for (final fix in kTrackConditionDdFixes) {
      final oldStr = fix.oldId.toString();
      final newStr = fix.newId.toString();
      expect(oldStr.length, 12);
      expect(newStr.length, 12);
      expect(newStr.substring(0, 8), oldStr.substring(0, 8));
      expect(newStr.substring(10), oldStr.substring(10));
      expect(newStr.substring(8, 10) == oldStr.substring(8, 10), isFalse);
      expect(fix.date.substring(0, 4), oldStr.substring(0, 4));
    }
  });

  test('端末の状態（阪神 9/21 は既に07）では4行を直し、値と日付はそのまま', () async {
    await insertRow(201905010508, '2019-02-10', 'su', 17.3);
    await insertRow(201905010609, '2019-02-11', 'mo', 14.6);
    await insertRow(202006030203, '2020-03-29', 'su', 12.9);
    await insertRow(202006030205, '2020-03-31', 'tu', 13.0);
    await insertRow(202606040710, '2026-09-21', 'mo', 18.8);
    await insertRow(202609040710, '2026-09-21', 'mo', 11.9);

    final changed = await applyTrackConditionIdFixes(db, kTrackConditionDdFixes);

    expect(changed, 4);
    expect(await allIds(), [
      201905010509,
      201905010608,
      202006030003,
      202006030205,
      202606040010,
      202609040710,
    ]);
    final moved = await db.query(
      'track_conditions',
      where: 'track_condition_id = ?',
      whereArgs: [201905010608],
    );
    expect(moved.single['date'], '2019-02-10');
    expect(moved.single['moisture_turf_goal'], 17.3);
  });

  test('サーバーと同じ状態（阪神 9/21 が00・中山 9/21 が00）では阪神だけ直す', () async {
    await insertRow(202606040010, '2026-09-21', 'mo', 18.8);
    await insertRow(202609040010, '2026-09-21', 'mo', 11.9);

    final changed = await applyTrackConditionIdFixes(db, kTrackConditionDdFixes);

    expect(changed, 1);
    expect(await allIds(), [202606040010, 202609040710]);
  });

  test('2回目は何も変えない', () async {
    await insertRow(201905010508, '2019-02-10', 'su', 17.3);
    await insertRow(201905010609, '2019-02-11', 'mo', 14.6);

    expect(await applyTrackConditionIdFixes(db, kTrackConditionDdFixes), 2);
    expect(await applyTrackConditionIdFixes(db, kTrackConditionDdFixes), 0);
    expect(await allIds(), [201905010509, 201905010608]);
  });

  test('日付が違う行・変更後IDが既にある行は書き換えない', () async {
    await insertRow(202006030203, '2020-03-28', 'sa', 12.9);
    await insertRow(201905010508, '2019-02-10', 'su', 17.3);
    await insertRow(201905010608, '2019-02-10', 'su', 17.3);

    final changed = await applyTrackConditionIdFixes(db, [
      const TrackConditionIdFix(202006030203, 202006030003, '2020-03-29'),
      const TrackConditionIdFix(201905010508, 201905010608, '2019-02-10'),
    ]);

    expect(changed, 0);
    expect(await allIds(), [201905010508, 201905010608, 202006030203]);
  });

  test('track_conditions の表が無いDBでは何もせず0を返す', () async {
    await db.execute('DROP TABLE track_conditions');

    expect(await applyTrackConditionIdFixes(db, kTrackConditionDdFixes), 0);
  });
}
