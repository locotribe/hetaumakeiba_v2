// lib/logic/analysis/horse_record_asof_filter.dart

// [追加] Phase 1: speed_index_backtest_runner.dart の §5（リーク防止ブロック）と
// 末尾の _parseRecordDate を、挙動を変えずに共有ユーティリティへ抽出したもの。
// shutuba_table_page.dart の _fetchDataWithUserMarks() から、過去レースを開いた際に
// 対象レースより後の成績が分析に混入する（未来データのリーク）問題を防ぐために
// 再利用する (v.2026.9.4+26090404)

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// HorseRaceRecord.date（'2025/07/19' 形式）をDateTimeへ変換する。
/// 変換不能な場合はnullを返す。
/// speed_index_backtest_runner.dart の _parseRecordDate から抽出（挙動は不変）。
DateTime? parseHorseRecordDate(String date) {
  final parts = date.split('/');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// [asOf] より前の成績のみを返す（リーク防止）。
/// [excludeRaceId] が指定され一致するレコードは、日付に関わらず除外する
/// （対象レース自身の除外用）。
/// 日付がパースできないレコードも除外する。
/// 入力の並び順は保持する。
List<HorseRaceRecord> filterRecordsBeforeAsOf(
  List<HorseRaceRecord> all, {
  required DateTime asOf,
  String? excludeRaceId,
}) {
  return all.where((r) {
    if (excludeRaceId != null && r.raceId == excludeRaceId) return false;
    final d = parseHorseRecordDate(r.date);
    return d != null && d.isBefore(asOf);
  }).toList();
}
