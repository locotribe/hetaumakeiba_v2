// lib/services/horse_fetch_outcome_store.dart

// [追加] 過去走の取得状況ポップアップ: 馬ごとの戦績の取得結果（成功・初出走で戦績なし・失敗）と、
// 戦績内レースの結果の取得に失敗したレースIDを SharedPreferences に記録して読む。
// DB のテーブルは増やさない。読み書きの失敗は握りつぶす（取得処理を止めないため） (v.2026.11.5+26110501)

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/logic/past_record_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HorseFetchOutcomeStore {
  static String _horseKey(String horseId) => 'horse_perf_outcome_v1_$horseId';

  static String _failedRacesKey(String raceId) =>
      'prep_past_result_failed_v1_$raceId';

  /// 1頭の戦績を取得した結果を保存する（上書き）。
  static Future<void> saveOutcome(
      String horseId, HorseFetchOutcome outcome) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_horseKey(horseId), outcome.encode());
    } catch (e) {
      debugPrint('HorseFetchOutcomeStore: 取得結果の保存に失敗 ($horseId): $e');
    }
  }

  /// [horseIds] の馬の、最後の取得結果を読む（記録が無い馬は含まない）。
  static Future<Map<String, HorseFetchOutcome>> loadOutcomes(
      Iterable<String> horseIds) async {
    final result = <String, HorseFetchOutcome>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final horseId in horseIds) {
        final outcome =
            HorseFetchOutcome.decode(prefs.getString(_horseKey(horseId)));
        if (outcome != null) result[horseId] = outcome;
      }
    } catch (e) {
      debugPrint('HorseFetchOutcomeStore: 取得結果の読み込みに失敗: $e');
    }
    return result;
  }

  /// レース [raceId] の準備で、結果を取得できなかった戦績内レースのIDを保存する（上書き。空なら記録を消す）。
  static Future<void> saveFailedPastRaceIds(
      String raceId, List<String> failedPastRaceIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (failedPastRaceIds.isEmpty) {
        await prefs.remove(_failedRacesKey(raceId));
      } else {
        await prefs.setStringList(_failedRacesKey(raceId), failedPastRaceIds);
      }
    } catch (e) {
      debugPrint('HorseFetchOutcomeStore: 失敗したレースの保存に失敗 ($raceId): $e');
    }
  }

  /// [saveFailedPastRaceIds] で保存したIDを読む。
  static Future<Set<String>> loadFailedPastRaceIds(String raceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_failedRacesKey(raceId)) ?? const <String>[])
          .toSet();
    } catch (e) {
      debugPrint('HorseFetchOutcomeStore: 失敗したレースの読み込みに失敗 ($raceId): $e');
      return <String>{};
    }
  }
}
