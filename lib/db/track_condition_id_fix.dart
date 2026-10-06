// lib/db/track_condition_id_fix.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';

// [追加] 馬場状態ID(YYYYCCKKDDNN)の日次(DD)のずれを、確認済みの「変更前ID→変更後ID」の表で一回だけ直す (v.2026.10.6+26100605)

/// 1行分の修正。[date] が一致する行だけを書き換える。
class TrackConditionIdFix {
  final int oldId;
  final int newId;
  final String date;

  const TrackConditionIdFix(this.oldId, this.newId, this.date);
}

/// 2026-10-06 の点検で見つかった、日次(DD)が規則と違う行。
/// 規則: 測定日にその競馬場でレースがあれば、そのレースIDの日次(9〜10桁目)、無ければ00。
/// 根拠は netkeiba の開催一覧(race_list_sub.html)。管理番号(NN)は変えない。
const List<TrackConditionIdFix> kTrackConditionDdFixes = [
  // 東京 2019-02-10(日): 第6日（2/9の中止で第5日が2/11に順延）
  TrackConditionIdFix(201905010508, 201905010608, '2019-02-10'),
  // 東京 2019-02-11(月): 順延された第5日
  TrackConditionIdFix(201905010609, 201905010509, '2019-02-11'),
  // 中山 2020-03-29(日): 雪で中止。レースが無いので00（第2日は3/31に開催）
  TrackConditionIdFix(202006030203, 202006030003, '2020-03-29'),
  // 阪神 2026-09-21(月): 第7日（自動実行が日付をまたいで00になっていた）
  TrackConditionIdFix(202609040010, 202609040710, '2026-09-21'),
  // 中山 2026-09-21(月): レースが無いので00（端末の取得で07になっていた）
  TrackConditionIdFix(202606040710, 202606040010, '2026-09-21'),
];

/// [fixes] を順に適用し、書き換えた行数を返す。
/// 変更後IDの行が既にあるときは、その修正を飛ばす（主キーの重複を避ける）。
/// 変更前IDが無い・日付が違うときは何もしない。何度実行しても結果は同じ。
/// track_conditions の表が無いDB（テストの合成DBなど）では何もせず0を返す。
Future<int> applyTrackConditionIdFixes(
  DatabaseExecutor db,
  List<TrackConditionIdFix> fixes,
) async {
  // [修正] 表が無いDBではアップグレードを失敗させないよう何もしない（実機は v9 以前から表がある） (v.2026.10.6+26100605)
  final tables = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', DbConstants.tableTrackConditions],
  );
  if (tables.isEmpty) return 0;
  int changed = 0;
  for (final fix in fixes) {
    final existing = await db.query(
      DbConstants.tableTrackConditions,
      columns: ['track_condition_id'],
      where: 'track_condition_id = ?',
      whereArgs: [fix.newId],
    );
    if (existing.isNotEmpty) continue;
    changed += await db.update(
      DbConstants.tableTrackConditions,
      {'track_condition_id': fix.newId},
      where: 'track_condition_id = ? AND date = ?',
      whereArgs: [fix.oldId, fix.date],
    );
  }
  return changed;
}
