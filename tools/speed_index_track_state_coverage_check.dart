// tools/speed_index_track_state_coverage_check.dart
//
// スピード指数 フェーズ7 段階7-0（データ実現性チェック）。
// race_results を track_conditions に結合し、連続量(クッション値・含水率)の
// 取得カバレッジと、単回帰の符号が常識と合うかを確認する使い捨てチェックスクリプト。
// lib/ は一切変更しない。tools/speed_index_fit.py と同じ結合規約
// (venue=raceId[4:6], track_condition_idの5〜6桁目=場コード, track_state_resolver.dartと
// 同じ 日付完全一致→±3日近傍・track_condition_id % 100 != 0 の採用ルール) をDartで再実装したもの。
//
// 実行環境に実Pythonインタープリタ(numpy/pandas)が無いため、本来Pythonで書く想定だった
// tools/speed_index_fit.py 相当のチェックをDartで代替実装している（ユーザー合意済み）。
//
// 使い方:
//   dart run tools/speed_index_track_state_coverage_check.dart --db <path/to/hetaumakeiba_v2.db>
//
// 安全のため、指定DBファイルは書き込みを一切行わない一時コピーへ複製してから開く。

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_parser.dart';

const Map<String, String> _kVenueNames = {
  '01': '札幌', '02': '函館', '03': '福島', '04': '新潟', '05': '東京',
  '06': '中山', '07': '中京', '08': '京都', '09': '阪神', '10': '小倉',
};

// tools/speed_index_fit.py の DIST_BANDS と同一の距離帯定義。
const Map<String, List<(int, int)>> _kDistBands = {
  '芝': [(0, 1400), (1400, 1800), (1800, 2200), (2200, 9999)],
  'ダ': [(0, 1400), (1400, 1800), (1800, 9999)],
};

class _Run {
  final String raceId;
  final String surf; // '芝' or 'ダ'
  final int dist;
  final String venCode;
  final int year;
  final double time; // 秒
  double? cushion;
  double? moistureTurf;
  double? moistureDirt;

  _Run({
    required this.raceId,
    required this.surf,
    required this.dist,
    required this.venCode,
    required this.year,
    required this.time,
  });
}

class _TrackCondition {
  final String venCode;
  final DateTime date;
  final double? cushion;
  final double? moistureTurfGoal;
  final double? moistureDirtGoal;

  _TrackCondition({
    required this.venCode,
    required this.date,
    required this.cushion,
    required this.moistureTurfGoal,
    required this.moistureDirtGoal,
  });
}

/// raceInfoから "(芝|ダ)...(\d+)m" を抽出する（tools/speed_index_fit.py の
/// `re.search(r'(芝|ダ).*?(\d+)m', info)` と同一の正規表現）。
final _surfDistPattern = RegExp(r'(芝|ダ).*?(\d+)m');

/// "YYYY年MM月DD日" 等の表記ゆれをDateTimeへ変換する
/// (lib/utils/speed_index_date_parser.dart の既存パターンと同一のRegExp)。
DateTime? _parseRaceDate(String raceDateStr) {
  final match =
      RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raceDateStr);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

Future<void> main(List<String> args) async {
  String? dbPath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[i + 1];
    }
  }
  if (dbPath == null) {
    stderr.writeln('使い方: dart run tools/speed_index_track_state_coverage_check.dart --db <path>');
    exit(1);
  }

  final sourceFile = File(dbPath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('DBファイルが見つかりません: $dbPath');
    exit(1);
  }

  // 安全のため一時コピーへ複製してから開く（元ファイルは一切書き込まない）。
  final tempDir =
      await Directory.systemTemp.createTemp('speed_index_track_state_check_');
  final copyPath = '${tempDir.path}/hetaumakeiba_v2_readonly_copy.db';
  await sourceFile.copy(copyPath);

  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    copyPath,
    options: OpenDatabaseOptions(readOnly: true),
  );

  print('DBコピー: $copyPath (元ファイルは未変更)');

  // ---- race_results 読み込み・1〜3着ランのみ抽出 ----
  final raceRows = await db.query('race_results', columns: ['race_id', 'race_result_json']);
  final runs = <_Run>[];
  int skippedNoSurfDist = 0;
  int skippedUnknownVenue = 0;
  int skippedNoRaceDate = 0;

  for (final row in raceRows) {
    final raceId = row['race_id'] as String;
    final json = row['race_result_json'] as String;
    final Map<String, dynamic> d = jsonDecode(json) as Map<String, dynamic>;
    final raceInfo = (d['raceInfo'] as String?) ?? '';
    final m = _surfDistPattern.firstMatch(raceInfo);
    if (m == null) {
      skippedNoSurfDist++;
      continue;
    }
    if (raceId.length < 6) {
      skippedUnknownVenue++;
      continue;
    }
    final venCode = raceId.substring(4, 6);
    if (!_kVenueNames.containsKey(venCode)) {
      skippedUnknownVenue++;
      continue;
    }
    final raceDateStr = (d['raceDate'] as String?) ?? '';
    final raceDate = _parseRaceDate(raceDateStr);
    if (raceDate == null) {
      skippedNoRaceDate++;
      continue;
    }
    final surf = m.group(1)!;
    final dist = int.parse(m.group(2)!);
    final year = int.tryParse(raceId.substring(0, 4)) ?? raceDate.year;

    final horseResults = (d['horseResults'] as List<dynamic>? ?? []);
    for (final hrDyn in horseResults) {
      final hr = hrDyn as Map<String, dynamic>;
      final rank = hr['rank'] as String? ?? '';
      if (rank != '1' && rank != '2' && rank != '3') continue;
      final timeStr = hr['time'] as String? ?? '';
      final time = parseRaceTime(timeStr);
      if (time == null) continue;
      runs.add(_Run(
        raceId: raceId,
        surf: surf,
        dist: dist,
        venCode: venCode,
        year: year,
      time: time,
      ));
    }
  }

  print('race_results総数=${raceRows.length} '
      '抽出run数(1-3着)=${runs.length} '
      'skip(surf/dist不明)=$skippedNoSurfDist skip(場コード不明)=$skippedUnknownVenue '
      'skip(raceDate不明)=$skippedNoRaceDate');

  // raceId -> raceDate のマップ（track_conditions結合用。1レース1回だけ解決すればよい）
  final raceDateById = <String, DateTime>{};
  final venCodeById = <String, String>{};
  for (final row in raceRows) {
    final raceId = row['race_id'] as String;
    if (raceId.length < 6) continue;
    final venCode = raceId.substring(4, 6);
    if (!_kVenueNames.containsKey(venCode)) continue;
    final json = row['race_result_json'] as String;
    final Map<String, dynamic> d = jsonDecode(json) as Map<String, dynamic>;
    final raceDateStr = (d['raceDate'] as String?) ?? '';
    final raceDate = _parseRaceDate(raceDateStr);
    if (raceDate == null) continue;
    raceDateById[raceId] = raceDate;
    venCodeById[raceId] = venCode;
  }

  // ---- track_conditions 読み込み（track_state_resolver.dartと同一の抽出規則） ----
  final tcRows = await db.query(
    'track_conditions',
    columns: [
      'track_condition_id',
      'date',
      'cushion_value',
      'moisture_turf_goal',
      'moisture_dirt_goal',
    ],
  );
  final tcByVenue = <String, List<_TrackCondition>>{};
  int tcSkippedMod100 = 0;
  for (final row in tcRows) {
    final id = row['track_condition_id'] as int;
    if (id % 100 == 0) {
      tcSkippedMod100++;
      continue;
    }
    final idStr = id.toString();
    if (idStr.length < 6) continue;
    final venCode = idStr.substring(4, 6);
    final dateStr = row['date'] as String;
    final date = DateTime.tryParse(dateStr);
    if (date == null) continue;
    tcByVenue.putIfAbsent(venCode, () => []).add(_TrackCondition(
          venCode: venCode,
          date: date,
          cushion: (row['cushion_value'] as num?)?.toDouble(),
          moistureTurfGoal: (row['moisture_turf_goal'] as num?)?.toDouble(),
          moistureDirtGoal: (row['moisture_dirt_goal'] as num?)?.toDouble(),
        ));
  }
  print('track_conditions総数=${tcRows.length} '
      '除外(id%100==0)=$tcSkippedMod100 対象=${tcRows.length - tcSkippedMod100} '
      '場コード種別数=${tcByVenue.length}');

  // raceId -> 解決済みTrackCondition（1レース1回だけ計算してキャッシュ）
  final resolvedByRaceId = <String, _TrackCondition?>{};
  for (final entry in raceDateById.entries) {
    final raceId = entry.key;
    final date = entry.value;
    final venCode = venCodeById[raceId]!;
    final candidates = tcByVenue[venCode];
    if (candidates == null || candidates.isEmpty) {
      resolvedByRaceId[raceId] = null;
      continue;
    }
    _TrackCondition? exact;
    for (final c in candidates) {
      if (c.date.year == date.year &&
          c.date.month == date.month &&
          c.date.day == date.day) {
        exact = c;
        break;
      }
    }
    if (exact != null) {
      resolvedByRaceId[raceId] = exact;
      continue;
    }
    _TrackCondition? nearest;
    int nearestDiff = 4; // ±3日を超えたら不採用(track_state_resolver.dartと同一)
    for (final c in candidates) {
      final diff = c.date.difference(date).inDays.abs();
      if (diff <= 3 && diff < nearestDiff) {
        nearestDiff = diff;
        nearest = c;
      }
    }
    resolvedByRaceId[raceId] = nearest;
  }

  // runsへ結合
  for (final run in runs) {
    final tc = resolvedByRaceId[run.raceId];
    if (tc == null) continue;
    if (run.surf == '芝') {
      run.cushion = tc.cushion;
      run.moistureTurf = tc.moistureTurfGoal;
    } else if (run.surf == 'ダ') {
      run.moistureDirt = tc.moistureDirtGoal;
    }
  }

  // ---- 1. カバレッジ（全体＋年別） ----
  final turfRuns = runs.where((r) => r.surf == '芝').toList();
  final dirtRuns = runs.where((r) => r.surf == 'ダ').toList();

  print('\n=== 1. カバレッジ ===');
  _printCoverage('芝 cushion_value', turfRuns, (r) => r.cushion);
  _printCoverage('芝 moisture_turf_goal', turfRuns, (r) => r.moistureTurf);
  _printCoverage('ダ moisture_dirt_goal', dirtRuns, (r) => r.moistureDirt);

  print('\n--- 年別 ---');
  final years = runs.map((r) => r.year).toSet().toList()..sort();
  for (final y in years) {
    final turfY = turfRuns.where((r) => r.year == y).toList();
    final dirtY = dirtRuns.where((r) => r.year == y).toList();
    if (turfY.isEmpty && dirtY.isEmpty) continue;
    _printCoverage('$y年 芝 cushion_value', turfY, (r) => r.cushion, indent: true);
    _printCoverage('$y年 芝 moisture_turf_goal', turfY, (r) => r.moistureTurf, indent: true);
    _printCoverage('$y年 ダ moisture_dirt_goal', dirtY, (r) => r.moistureDirt, indent: true);
  }

  // ---- 2. 取得できた連続量の分布 ----
  print('\n=== 2. 分布(取得できた値のみ) ===');
  _printDistribution('芝 cushion_value', turfRuns.map((r) => r.cushion).whereType<double>().toList());
  _printDistribution('芝 moisture_turf_goal', turfRuns.map((r) => r.moistureTurf).whereType<double>().toList());
  _printDistribution('ダ moisture_dirt_goal', dirtRuns.map((r) => r.moistureDirt).whereType<double>().toList());

  // ---- 3. 単回帰の当たり（同一(surf,距離帯,場)内でtime~cushion / time~moisture） ----
  print('\n=== 3. 単回帰の当たり（同一サーフェス・距離帯・場内、N>=15のグループのみ集計） ===');
  _printRegressionHitRate(
    '芝: time ~ cushion (期待符号=負: クッション高い(硬い)ほど速い=時計が縮む)',
    turfRuns,
    (r) => r.cushion,
    expectedNegative: true,
  );
  _printRegressionHitRate(
    '芝: time ~ moistureTurf (期待符号=正: 湿るほど遅い=時計が延びる)',
    turfRuns,
    (r) => r.moistureTurf,
    expectedNegative: false,
  );
  _printRegressionHitRate(
    'ダ: time ~ moistureDirt (期待符号=負: 湿るほど速い=時計が縮む)',
    dirtRuns,
    (r) => r.moistureDirt,
    expectedNegative: true,
  );

  await db.close();
  await tempDir.delete(recursive: true);
}

void _printCoverage(
  String label,
  List<_Run> runs,
  double? Function(_Run) getter, {
  bool indent = false,
}) {
  final total = runs.length;
  final nonNull = runs.where((r) => getter(r) != null).length;
  final rate = total == 0 ? 0.0 : nonNull / total * 100;
  final prefix = indent ? '  ' : '';
  print('$prefix$label: 総数=$total 取得=$nonNull 取得率=${rate.toStringAsFixed(1)}%');
}

void _printDistribution(String label, List<double> values) {
  if (values.isEmpty) {
    print('$label: 値なし');
    return;
  }
  final sorted = List<double>.from(values)..sort();
  final min = sorted.first;
  final max = sorted.last;
  final median = sorted.length.isOdd
      ? sorted[sorted.length ~/ 2]
      : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
  print('$label: n=${values.length} min=${min.toStringAsFixed(2)} '
      'median=${median.toStringAsFixed(2)} max=${max.toStringAsFixed(2)}');
}

// 単純最小二乗法によるslope(傾き)を返す。分散0またはn<2はnull。
double? _slope(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return null;
  final xMean = xs.reduce((a, b) => a + b) / n;
  final yMean = ys.reduce((a, b) => a + b) / n;
  double num = 0.0;
  double den = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - xMean;
    num += dx * (ys[i] - yMean);
    den += dx * dx;
  }
  if (den == 0.0) return null;
  return num / den;
}

void _printRegressionHitRate(
  String label,
  List<_Run> runs,
  double? Function(_Run) getter, {
  required bool expectedNegative,
  int minN = 15,
}) {
  final surf = runs.isEmpty ? '芝' : runs.first.surf;
  final bands = _kDistBands[surf]!;
  int totalGroups = 0;
  int hitGroups = 0;
  final slopes = <double>[];

  for (final band in bands) {
    final byVenue = <String, List<_Run>>{};
    for (final r in runs) {
      if (r.dist >= band.$1 && r.dist < band.$2) {
        byVenue.putIfAbsent(r.venCode, () => []).add(r);
      }
    }
    for (final entry in byVenue.entries) {
      final group = entry.value.where((r) => getter(r) != null).toList();
      if (group.length < minN) continue;
      final xs = group.map((r) => getter(r)!).toList();
      final ys = group.map((r) => r.time).toList();
      final slope = _slope(xs, ys);
      if (slope == null) continue;
      totalGroups++;
      slopes.add(slope);
      final matches = expectedNegative ? slope < 0 : slope > 0;
      if (matches) hitGroups++;
    }
  }

  if (totalGroups == 0) {
    print('$label: 対象グループなし(N>=$minN を満たすサーフェス×距離帯×場が0件)');
    return;
  }
  final hitRate = hitGroups / totalGroups * 100;
  final meanSlope = slopes.reduce((a, b) => a + b) / slopes.length;
  final medianSlope = (List<double>.from(slopes)..sort())[slopes.length ~/ 2];
  print('$label: 対象グループ数=$totalGroups 符号一致=$hitGroups '
      '一致率=${hitRate.toStringAsFixed(1)}% 平均slope=${meanSlope.toStringAsFixed(4)} '
      '中央値slope=${medianSlope.toStringAsFixed(4)}');
}
