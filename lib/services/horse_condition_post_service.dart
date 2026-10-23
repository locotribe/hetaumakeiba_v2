// lib/services/horse_condition_post_service.dart

// [追加] 出走の意味 調教の行 Step3: netkeiba の近況（db.netkeiba.com/social/horse_info_state.html）を全頭取って保存する。
// ログイン不要の静的ページ（EUC-JP）。同じ馬は 12時間に1回まで。要求の間隔は 3秒 (v.2026.10.24+26102403)

import 'dart:async';

import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_condition_post_repository.dart';
import 'package:hetaumakeiba_v2/logic/horse_condition_post_parser.dart';
import 'package:hetaumakeiba_v2/logic/training_fetch_policy.dart';

class HorseConditionPostService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  final HorseConditionPostRepository _repository;

  HorseConditionPostService({HorseConditionPostRepository? repository})
      : _repository = repository ?? HorseConditionPostRepository();

  static String stateUrl(String horseId) =>
      'https://db.netkeiba.com/social/horse_info_state.html?id=$horseId';

  static String _fetchedPrefKey(String horseId) =>
      'nk_condition_fetched_$horseId';

  /// 全頭の近況を順に取って保存する（1頭ごとに [kNetkeibaRequestIntervalMs] ミリ秒あける）。
  /// [force] が false のとき、12時間以内に取った馬は飛ばす。
  /// 1頭の失敗は他の馬に影響させない（ログだけ出す）。戻り値は保存した投稿の数。
  Future<int> fetchAndSaveForHorses(List<String> horseIds,
      {bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    var total = 0;
    var requested = 0;
    for (final horseId in horseIds) {
      if (!force) {
        final lastText = prefs.getString(_fetchedPrefKey(horseId));
        final last = lastText == null ? null : DateTime.tryParse(lastText);
        if (!needsConditionPostFetch(last, DateTime.now())) continue;
      }
      if (requested > 0) {
        await Future.delayed(
            const Duration(milliseconds: kNetkeibaRequestIntervalMs));
      }
      requested++;
      total += await _fetchAndSave(horseId, prefs) ?? 0;
    }
    debugPrint('HorseConditionPostService: 近況 要求$requested頭・保存$total件');
    return total;
  }

  /// 1頭分を取って保存する。失敗は null（エラーは投げない）。
  Future<int?> _fetchAndSave(String horseId, SharedPreferences prefs) async {
    final url = stateUrl(horseId);
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('HorseConditionPostService: HTTP ${response.statusCode} ($url)');
        return null;
      }
      final html = await CharsetConverter.decode('euc-jp', response.bodyBytes);
      final fetchedAt = DateTime.now().toIso8601String();
      final posts =
          HorseConditionPostParser.parse(html, horseId, fetchedAt: fetchedAt);
      await _repository.upsertPosts(posts);
      await prefs.setString(_fetchedPrefKey(horseId), fetchedAt);
      return posts.length;
    } catch (e) {
      debugPrint('HorseConditionPostService: 近況の取得に失敗 (horse=$horseId): $e');
      return null;
    }
  }
}
