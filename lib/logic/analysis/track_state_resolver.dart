// lib/logic/analysis/track_state_resolver.dart

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/course_presets.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

/// 各走（日付＋競馬場）にその日のクッション値・含水率を紐付けるヘルパー。
/// track_conditions テーブルには競馬場名の列が無く、track_condition_id
/// (12桁: YYYYCCKKDDNN) の5〜6桁目にJRA2桁場コードが埋め込まれているため、
/// race_id の同位置(5〜6桁目)から場コードを抽出して結合キーとする。
class TrackStateResolver {
  final Future<Database> Function() _dbAccessor;

  /// [dbAccessor] はテスト時に fixture 用 Database を注入するためのフック。
  /// 未指定時は既存の DbProvider 経由で本番DBへ接続する。
  TrackStateResolver({Future<Database> Function()? dbAccessor})
      : _dbAccessor = dbAccessor ?? (() async => await DbProvider().database);

  /// 指定レース・日付・馬場種別に対応するクッション値・含水率を解決する。
  /// 場コード・日付のいずれかが解決できない場合、または該当レコードが
  /// 無い場合は cushion・moisture ともに null を返す。
  Future<({double? cushion, double? moisture})> resolve({
    required String raceId,
    String? fallbackVenueName,
    required String date,
    required String surface,
  }) async {
    final venueCode = _resolveVenueCode(raceId, fallbackVenueName);
    final normalizedDate = _normalizeDate(date);
    if (venueCode == null || normalizedDate == null) {
      return (cushion: null, moisture: null);
    }

    final record = await _findRecord(venueCode, normalizedDate);
    if (record == null) return (cushion: null, moisture: null);

    if (surface == '芝') {
      return (cushion: record.cushionValue, moisture: record.moistureTurfGoal);
    } else if (surface == 'ダ') {
      return (cushion: null, moisture: record.moistureDirtGoal);
    }
    return (cushion: null, moisture: null);
  }

  /// raceId[4:6](5〜6桁目)を優先して場コードとする。
  /// raceId が空・不正な場合は fallbackVenueName を course_presets の
  /// venueName→venueCode 変換で補う。
  String? _resolveVenueCode(String raceId, String? fallbackVenueName) {
    if (raceId.length >= 6) {
      final code = raceId.substring(4, 6);
      if (RegExp(r'^\d{2}$').hasMatch(code)) return code;
    }
    if (fallbackVenueName != null && fallbackVenueName.isNotEmpty) {
      for (final preset in coursePresets) {
        if (preset.venueName == fallbackVenueName) return preset.venueCode;
      }
    }
    return null;
  }

  /// "YYYY/MM/DD"・"YYYY-MM-DD" いずれの表記も "YYYY-MM-DD" へ正規化する。
  String? _normalizeDate(String date) {
    final trimmed = date.trim();
    if (trimmed.isEmpty) return null;
    final unified = trimmed.replaceAll('/', '-');
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(unified);
    if (match == null) return null;
    final y = match.group(1)!;
    final m = match.group(2)!.padLeft(2, '0');
    final d = match.group(3)!.padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// venueCode に一致する track_conditions から date完全一致のレコードを探し、
  /// 無ければ同一週内(±3日)で最も近い日付のレコードを返す。
  /// track_condition_id % 100 == 0 (前日データ) の行は既存リポジトリの
  /// 読み出しパターンと同様に除外する。
  Future<TrackConditionRecord?> _findRecord(
    String venueCode,
    String normalizedDate,
  ) async {
    final db = await _dbAccessor();
    final maps = await db.query(
      DbConstants.tableTrackConditions,
      where:
          'SUBSTR(CAST(track_condition_id AS TEXT), 5, 2) = ? AND track_condition_id % 100 != 0',
      whereArgs: [venueCode],
    );
    if (maps.isEmpty) return null;

    final records = maps.map((m) => TrackConditionRecord.fromJson(m)).toList();

    for (final r in records) {
      if (r.date == normalizedDate) return r;
    }

    final target = DateTime.tryParse(normalizedDate);
    if (target == null) return null;

    TrackConditionRecord? nearest;
    int nearestDiff = 4; // ±3日を超えたら不採用
    for (final r in records) {
      final d = DateTime.tryParse(r.date);
      if (d == null) continue;
      final diff = d.difference(target).inDays.abs();
      if (diff <= 3 && diff < nearestDiff) {
        nearestDiff = diff;
        nearest = r;
      }
    }
    return nearest;
  }
}
