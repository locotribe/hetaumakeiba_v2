// lib/services/horse_laptime_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// [追加] 個別ラップ取得Step2: 取得要否の判定（最新の過去走・24時間の間隔） (v.2026.9.23+26092304)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_past_race_extra_repository.dart';
import 'package:hetaumakeiba_v2/logic/horse_laptime_parser.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';

// [追加] 個別ラップ取得: 前走の個別ラップページの取得・保存（ログイン不要） (v.2026.9.23+26092304)
class HorseLapTimeService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  final HorsePastRaceExtraRepository _repository;
  // [追加] 個別ラップ取得Step2: 最新の過去走を見るためのリポジトリ (v.2026.9.23+26092304)
  final HorseRepository _horseRepository;

  HorseLapTimeService({
    HorsePastRaceExtraRepository? repository,
    HorseRepository? horseRepository,
  })  : _repository = repository ?? HorsePastRaceExtraRepository(),
        _horseRepository = horseRepository ?? HorseRepository();

  static String lapTimeUrl(String horseId) =>
      'https://db.sp.netkeiba.com/horse/horse_laptime.html?id=$horseId';

  /// 指定馬の個別ラップページを取得して保存し、保存した内容を返す。失敗時は空（エラーは投げない）。
  Future<List<HorsePastRaceExtra>> fetchAndSave(String horseId) async {
    try {
      final response = await http
          .get(Uri.parse(lapTimeUrl(horseId)), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('HorseLapTimeService: HTTP ${response.statusCode} (horse=$horseId)');
        return const [];
      }
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final extras = HorseLapTimeParser.parse(html, horseId,
          fetchedAt: DateTime.now().toIso8601String());
      await _repository.upsertMerge(extras);
      // [追加] 個別ラップ取得Step2: 取得日時を記録（24時間は取り直さない） (v.2026.9.23+26092304)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _fetchedPrefKey(horseId), DateTime.now().toIso8601String());
      debugPrint('HorseLapTimeService: horse=$horseId 個別ラップ ${extras.length}走 '
          '${extras.map((e) => '${e.raceId} 前${e.individualFirst3f}-後${e.individualLast3f}').join(' ')}');
      return extras;
    } catch (e) {
      debugPrint('HorseLapTimeService: 取得に失敗 (horse=$horseId): $e');
      return const [];
    }
  }

  // [追加] 個別ラップ取得Step2: 取得が必要なときだけ取る。
  // ・DB の最も新しい過去走に個別ラップがあれば取らない
  // ・同じ馬は24時間に1回まで（前走に個別ラップが無い馬を毎回取りに行かないため） (v.2026.9.23+26092304)
  Future<bool> needsFetch(String horseId) async {
    try {
      final records = await _horseRepository.getHorsePerformanceRecords(horseId);
      if (records.isEmpty) return false;
      final latestRaceId = records.first.raceId;
      if (latestRaceId.isEmpty) return false;
      final extras = await _repository.getForHorse(horseId, [latestRaceId]);
      if (extras[latestRaceId]?.individualLaps != null) return false;
      final prefs = await SharedPreferences.getInstance();
      final last = DateTime.tryParse(prefs.getString(_fetchedPrefKey(horseId)) ?? '');
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('HorseLapTimeService: 取得要否の判定に失敗 (horse=$horseId): $e');
      return false;
    }
  }

  /// 必要な馬だけ、1頭ずつ間隔を空けて取得する。
  Future<void> fetchAndSaveForHorses(List<String> horseIds) async {
    int fetched = 0;
    for (final horseId in horseIds) {
      if (!await needsFetch(horseId)) continue;
      await fetchAndSave(horseId);
      fetched++;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (fetched > 0) {
      debugPrint('HorseLapTimeService: 個別ラップ $fetched/${horseIds.length}頭 取得');
    }
  }

  static String _fetchedPrefKey(String horseId) => 'laptime_fetched_$horseId';
}
