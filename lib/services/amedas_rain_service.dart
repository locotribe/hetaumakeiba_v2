// lib/services/amedas_rain_service.dart

// [追加] 馬場予測の天気材料の見直し Step2: 気象庁アメダス（bosai の JSON。キー不要）から、競馬場の近くの地点の10分ごとの雨を取り、1時間ごとにまとめる。第1の地点で欠けた10分は予備の地点で埋める。地点は係数を決めたときと同じもの（変えると係数が合わなくなる）。済んだ3時間のファイルは端末に保存して2回目から取らない (v.2026.11.18+26111802)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/logic/analysis/track_rain_timeline.dart';

/// アメダスの地点。
class AmedasStation {
  final String code;
  final String name;
  const AmedasStation(this.code, this.name);
}

/// 取得の結果。
class AmedasRainResult {
  /// 1時間の終わりの時刻 → その1時間の雨（mm。欠けて埋まらなければ null）
  final Map<DateTime, double?> hours;

  /// アメダスの最新時刻（ここまでが実測）
  final DateTime observedUntil;

  /// 第1の地点の名前
  final String stationName;

  /// 予備の地点で埋めた10分の数
  final int backupSlots;

  const AmedasRainResult({
    required this.hours,
    required this.observedUntil,
    required this.stationName,
    required this.backupSlots,
  });
}

class AmedasRainService {
  /// 競馬場コード → [第1の地点, 予備の地点]
  static const Map<String, List<AmedasStation>> stations = {
    '01': [AmedasStation('14163', '札幌'), AmedasStation('14116', '山口')],
    '02': [AmedasStation('23232', '函館'), AmedasStation('23281', '高松')],
    '03': [AmedasStation('36127', '福島'), AmedasStation('36066', '梁川')],
    '04': [AmedasStation('54236', '松浜'), AmedasStation('54232', '新潟')],
    '05': [AmedasStation('44116', '府中'), AmedasStation('44071', '練馬')],
    '06': [AmedasStation('45106', '船橋'), AmedasStation('44136', '江戸川臨海')],
    '07': [AmedasStation('51216', '大府'), AmedasStation('51106', '名古屋')],
    '08': [AmedasStation('61306', '長岡京'), AmedasStation('61326', '京田辺')],
    '09': [AmedasStation('63477', '西宮'), AmedasStation('62051', '豊中')],
    '10': [AmedasStation('82097', '東谷'), AmedasStation('82056', '八幡')],
  };

  static const String _base = 'https://www.jma.go.jp/bosai/amedas/data';
  static const Duration _timeout = Duration(seconds: 5);
  static const String _cachePrefix = 'amedas_rain_v1_';

  /// 端末に保存した3時間ぶんのファイルを残す日数（アメダスは約10日分しか公開されない）
  static const int _cacheKeepDays = 14;

  /// 同時に取るファイルの数
  static const int _parallel = 8;

  /// [venueCode] の競馬場の、[from] の後に終わり今（アメダスの最新時刻）までに終わる1時間ごとの雨。
  /// 最新時刻が取れない、または第1の地点のファイルが1つも取れなければ null。
  static Future<AmedasRainResult?> fetchHourly({
    required String venueCode,
    required DateTime from,
  }) async {
    final list = stations[venueCode];
    if (list == null || list.isEmpty) return null;
    try {
      final latestRes = await http.get(Uri.parse('$_base/latest_time.txt')).timeout(_timeout);
      if (latestRes.statusCode != 200) return null;
      final latest = parseAmedasLatestTime(latestRes.body);
      if (latest == null) return null;
      if (!latest.isAfter(from)) {
        return AmedasRainResult(hours: const {}, observedUntil: latest, stationName: list[0].name, backupSlots: 0);
      }

      final prefs = await SharedPreferences.getInstance();
      _removeOldCache(prefs, latest);
      final blocks = _blocks(from, latest);

      final primary = await _fetchStation(list[0].code, blocks, latest, prefs);
      if (primary == null) return null;
      var hourly = hourlyFromTenMinute(primary: primary, from: from, observedUntil: latest);

      if (list.length > 1 && hourly.hours.values.any((v) => v == null)) {
        final backup = await _fetchStation(list[1].code, blocks, latest, prefs);
        if (backup != null) {
          hourly = hourlyFromTenMinute(primary: primary, backup: backup, from: from, observedUntil: latest);
        }
      }

      return AmedasRainResult(
        hours: hourly.hours,
        observedUntil: latest,
        stationName: list[0].name,
        backupSlots: hourly.backupSlots,
      );
    } catch (e) {
      debugPrint('アメダス取得エラー: $e');
      return null;
    }
  }

  /// [from] を含む3時間のファイルから、[latest] を含む3時間のファイルまで（00・03・…・21時始まり）。
  static List<DateTime> _blocks(DateTime from, DateTime latest) {
    final out = <DateTime>[];
    var t = DateTime(from.year, from.month, from.day, (from.hour ~/ 3) * 3);
    while (!t.isAfter(latest)) {
      out.add(t);
      t = t.add(const Duration(hours: 3));
    }
    return out;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _fileName(DateTime block) =>
      '${block.year}${_two(block.month)}${_two(block.day)}_${_two(block.hour)}';

  static String _timeKey(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}00';

  /// 1地点ぶんの10分値をまとめて返す。1つも取れなければ null。
  static Future<Map<DateTime, double?>?> _fetchStation(
    String code,
    List<DateTime> blocks,
    DateTime latest,
    SharedPreferences prefs,
  ) async {
    final merged = <DateTime, double?>{};
    int ok = 0;
    for (int i = 0; i < blocks.length; i += _parallel) {
      final chunk = blocks.sublist(i, (i + _parallel).clamp(0, blocks.length).toInt());
      final results = await Future.wait(chunk.map((b) => _fetchBlock(code, b, latest, prefs)));
      for (final r in results) {
        if (r == null) continue;
        ok++;
        merged.addAll(r);
      }
    }
    return ok == 0 ? null : merged;
  }

  /// 3時間ぶんのファイル1つ。済んだファイル（最後の10分が最新時刻までに入っている）は端末に保存する。
  static Future<Map<DateTime, double?>?> _fetchBlock(
    String code,
    DateTime block,
    DateTime latest,
    SharedPreferences prefs,
  ) async {
    final name = _fileName(block);
    final cacheKey = '$_cachePrefix${code}_$name';
    final complete = !block.add(const Duration(hours: 2, minutes: 50)).isAfter(latest);

    if (complete) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        try {
          final map = Map<String, dynamic>.from(json.decode(cached) as Map);
          return {
            for (final e in map.entries)
              if (e.key.length == 14)
                DateTime(
                  int.parse(e.key.substring(0, 4)),
                  int.parse(e.key.substring(4, 6)),
                  int.parse(e.key.substring(6, 8)),
                  int.parse(e.key.substring(8, 10)),
                  int.parse(e.key.substring(10, 12)),
                ): (e.value as num?)?.toDouble(),
          };
        } catch (_) {
          // 読めない保存は取り直す
        }
      }
    }

    try {
      final res = await http.get(Uri.parse('$_base/point/$code/$name.json')).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = Map<String, dynamic>.from(json.decode(utf8.decode(res.bodyBytes)) as Map);
      final parsed = parseAmedasTenMinutePrecip(data);
      if (complete) {
        await prefs.setString(cacheKey, json.encode({for (final e in parsed.entries) _timeKey(e.key): e.value}));
      }
      return parsed;
    } catch (e) {
      debugPrint('アメダス取得エラー($code $name): $e');
      return null;
    }
  }

  /// 保存してから [_cacheKeepDays] 日より古い3時間ぶんのファイルを消す。
  static void _removeOldCache(SharedPreferences prefs, DateTime latest) {
    final limit = latest.subtract(const Duration(days: _cacheKeepDays));
    final limitKey = '${limit.year}${_two(limit.month)}${_two(limit.day)}';
    for (final key in prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList()) {
      final parts = key.split('_');
      if (parts.length < 2) continue;
      final day = parts[parts.length - 2];
      if (day.length == 8 && day.compareTo(limitKey) < 0) {
        prefs.remove(key);
      }
    }
  }
}
