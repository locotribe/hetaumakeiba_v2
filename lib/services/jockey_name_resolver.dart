// lib/services/jockey_name_resolver.dart

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';

/// 騎手IDから、DBに保存済みの戦績（horse_performance.jockey）に出てくる最も長い騎手名を返す。
/// 出馬表ページの騎手名は「松山」「岩田望」などの省略形のため、競走馬ページ由来の「松山弘平」等に置き換える目的。
/// netkeiba の表記は最大4文字（例: 「吉村誠之」「Ｍ．デム」）のため、5文字以上の名前は4文字までになる。
/// 通信は行わない。結果はアプリ実行中のメモリにキャッシュする（見つからなかった騎手は次回また検索する）。
class JockeyNameResolver {
  static final Map<String, Future<String?>> _cache = {};

  static Future<String?> resolve(String jockeyId) {
    if (jockeyId.isEmpty) return Future.value(null);
    final cached = _cache[jockeyId];
    if (cached != null) return cached;
    final future = _load(jockeyId);
    _cache[jockeyId] = future;
    future.then((value) {
      if (value == null) _cache.remove(jockeyId);
    });
    return future;
  }

  static Future<String?> _load(String jockeyId) async {
    try {
      final db = await DbProvider().database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT jockey FROM ${DbConstants.tableHorsePerformance} WHERE jockey_id = ?',
        [jockeyId],
      );
      String? best;
      for (final row in rows) {
        final name = (row['jockey'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        if (best == null || name.length > best.length) best = name;
      }
      return best;
    } catch (e) {
      debugPrint('JockeyNameResolver: failed for $jockeyId: $e');
      return null;
    }
  }
}
