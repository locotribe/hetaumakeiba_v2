// lib/logic/analysis/daily_track_variant_resolver.dart

// [追加] フェーズ7 ステップ2: 当日トラック変量(daily track variant)の算出。
// 過去走のraceId群から「同一開催日(prefix10=raceId先頭10桁)・同一サーフェスの
// 全馬タイムの平均残差」を実行時に算出し、SpeedIndexCalculator.calculateへ渡す
// map(raceId→variant秒)を返す。新規のオフライン定数は作らない:
// 変量は既存のSpeedIndexBaseTime(案C回帰定数)とrace_resultsから実行時に算出するのみ。
// memory/スピード指数_フェーズ7設計_v2_当日トラック変量.md §2, §3-2 に従う (v.2026.9.4)

import 'package:sqflite/sqflite.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_base_time.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/logic/race_info_parser.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_parser.dart';

/// 過去走のraceId群について、当日トラック変量(秒)を解決するヘルパー。
/// TrackStateResolverと同じDBアクセス注入パターン(テスト用dbAccessorフック)を使う。
class DailyTrackVariantResolver {
  final Future<Database> Function() _dbAccessor;

  // [追加] 変量算出に必要な最小有効頭数(調整可能)。
  // 対象サーフェスの残差サンプル数がこれ未満の場合、変量は無効(0.0)にする (v.2026.9.4)
  static const int kMinEffectiveHorseCount = 8;

  // [追加] 変量算出に必要な最小寄与レース数(調整可能)。
  // 対象サーフェスの寄与レース数がこれ未満の場合、変量は無効(0.0)にする (v.2026.9.4)
  static const int kMinRaceCount = 2;

  // prefix10 → (surface → variant秒)。N+1回避のためのキャッシュ。
  final Map<String, Map<String, double>> _prefixSurfaceVariantCache = {};

  // "prefix10:raceId" → そのレース自身のサーフェス('芝'/'ダ')。
  // _computeAndCacheVariant内でrace_resultsを読んだ際に埋める。
  final Map<String, String> _raceSurfaceCache = {};

  /// [dbAccessor] はテスト時にfixture用Databaseを注入するためのフック。
  /// 未指定時は既存のDbProvider経由で本番DBへ接続する。
  DailyTrackVariantResolver({Future<Database> Function()? dbAccessor})
      : _dbAccessor = dbAccessor ?? (() async => await DbProvider().database);

  /// 過去走レコード群のraceIdについて、当日トラック変量(秒)を解決して返す。
  /// キー=raceId、値=variant(秒、そのレース自身のサーフェスの変量)。
  /// 算出不能(該当データ無し・年/場が解決不能等)・閾値未満は0.0(補正なし)。
  Future<Map<String, double>> resolveForRaceIds(
      Iterable<String> raceIds) async {
    final result = <String, double>{};
    final validRaceIds =
        raceIds.where((id) => id.length >= 10).toSet().toList();
    if (validRaceIds.isEmpty) return result;

    final prefixToRaceIds = <String, List<String>>{};
    for (final id in validRaceIds) {
      final prefix10 = id.substring(0, 10);
      prefixToRaceIds.putIfAbsent(prefix10, () => []).add(id);
    }

    final db = await _dbAccessor();

    for (final prefix10 in prefixToRaceIds.keys) {
      if (!_prefixSurfaceVariantCache.containsKey(prefix10)) {
        await _computeAndCacheVariant(db, prefix10);
      }
    }

    for (final entry in prefixToRaceIds.entries) {
      final prefix10 = entry.key;
      final surfaceVariants = _prefixSurfaceVariantCache[prefix10] ?? const {};
      for (final raceId in entry.value) {
        final surface = _raceSurfaceCache['$prefix10:$raceId'];
        result[raceId] =
            surface != null ? (surfaceVariants[surface] ?? 0.0) : 0.0;
      }
    }

    return result;
  }

  /// prefix10に属する全レースをDBから取得し、サーフェス別の当日トラック変量を算出して
  /// キャッシュする。年・場コードが解決不能な場合は残差計算をスキップし(=変量0.0)、
  /// サーフェスのみ_raceSurfaceCacheへ記録する。
  Future<void> _computeAndCacheVariant(Database db, String prefix10) async {
    final year = int.tryParse(prefix10.substring(0, 4));
    final placeCode = prefix10.substring(4, 6);
    final venueName = racecourseDict[placeCode];

    final maps = await db.query(
      DbConstants.tableRaceResults,
      where: 'race_id LIKE ?',
      whereArgs: ['$prefix10%'],
    );

    final residualsBySurface = <String, List<double>>{'芝': [], 'ダ': []};
    final contributingRaceIdsBySurface = <String, Set<String>>{
      '芝': {},
      'ダ': {},
    };

    for (final map in maps) {
      final jsonStr = map['race_result_json'] as String?;
      if (jsonStr == null) continue;

      final RaceResult race;
      try {
        race = raceResultFromJson(jsonStr);
      } catch (_) {
        continue;
      }

      final courseInfo = RaceInfoParser.parse(race.raceInfo);
      final surface = courseInfo.trackType;
      final meters = courseInfo.distanceValue;
      if (surface == null) continue;
      if (surface != '芝' && surface != 'ダ') continue;
      if (meters == null) continue;

      _raceSurfaceCache['$prefix10:${race.raceId}'] = surface;

      if (year == null || venueName == null) continue;

      final normalizedCondition = _extractCondition(race.raceInfo, surface);
      final resolved = SpeedIndexBaseTime.resolve(
        surface: surface,
        meters: meters,
        year: year,
        venueName: venueName,
        normalizedCondition: normalizedCondition,
      );
      if (resolved == null) continue;

      for (final hr in race.horseResults) {
        if (int.tryParse(hr.rank) == null) continue;
        final actualTime = parseRaceTime(hr.time);
        if (actualTime == null) continue;
        residualsBySurface[surface]!.add(actualTime - resolved.baseTime);
        contributingRaceIdsBySurface[surface]!.add(race.raceId);
      }
    }

    final variants = <String, double>{};
    for (final surface in ['芝', 'ダ']) {
      final residuals = residualsBySurface[surface]!;
      final raceCount = contributingRaceIdsBySurface[surface]!.length;
      if (residuals.length < kMinEffectiveHorseCount ||
          raceCount < kMinRaceCount) {
        variants[surface] = 0.0;
      } else {
        variants[surface] =
            residuals.reduce((a, b) => a + b) / residuals.length;
      }
    }
    _prefixSurfaceVariantCache[prefix10] = variants;
  }

  /// raceInfoから[surface]の馬場状態("良""稍重""重""不良")を抽出する。
  /// マッチしない場合は空文字を返す(SpeedIndexBaseTime側で該当キー無し=0.0補正扱いになる)。
  static String _extractCondition(String raceInfo, String surface) {
    final match =
        RegExp('$surface[^:]*:\\s*(良|稍重|重|不良)').firstMatch(raceInfo);
    return match?.group(1) ?? '';
  }
}
