// lib/services/track_rain_service.dart

// [追加] 馬場予測の天気材料の見直し Step2: 馬場予測に使う「起点の測定から発走までの1時間ごとの雨」を用意する。今までの雨はアメダスの実測、その先と実測の欠けはピンポイント天気（Open-Meteo）の時間別の値。結果はレースごとに端末へ保存し、発走から1時間を過ぎたレースは保存分だけを使う (v.2026.11.18+26111802)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/logic/analysis/track_moisture_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/track_rain_timeline.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/services/amedas_rain_service.dart';

/// 馬場予測の材料（起点の測定と、その起点からの雨）。出馬表ページで1回だけ用意し、レース情報タブと展開シミュで使う。
class TrackPredictionInputs {
  /// 馬場予測の起点にする測定（レース当日より前で一番新しい測定。無ければ最新の測定）
  final TrackConditionRecord? baseline;

  /// 起点から発走までの雨（用意できなければ null）
  final TrackRainInput? rain;

  const TrackPredictionInputs({required this.baseline, required this.rain});
}

class TrackRainService {
  static const String _cachePrefix = 'track_rain_v1_';

  /// アメダスの取得全体の打ち切り
  static const Duration _amedasTimeout = Duration(seconds: 20);

  /// [baseline] は馬場予測の起点にする測定。[pinpoint] はピンポイント天気（取れなければ null）。
  /// [isLocked] が true（発走から1時間を過ぎた）なら取得せず、同じ起点で保存した分を返す（無ければ null）。
  /// 起点が無い・日付が読めないときは null。アメダスもピンポイント天気も無いときは、雨の時間が空の結果を返す。
  static Future<TrackRainInput?> load({
    required String raceId,
    required TrackConditionRecord? baseline,
    required String raceDate,
    required String? startTime,
    required Map<String, dynamic>? pinpoint,
    required bool isLocked,
  }) async {
    if (baseline == null || raceId.length < 6) return null;
    final target = parseRaceStartDateTime(raceDate, startTime);
    if (target == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$raceId';
      final cached = _readCache(prefs, cacheKey, baseline.trackConditionId, target);
      if (isLocked) return cached;

      final venueCode = raceId.substring(4, 6);
      final isRaceDay = TrackMoistureModel.isRaceDayRecord(baseline.trackConditionId);
      final moistureTime = TrackMoistureModel.measurementTime(
          venueCode: venueCode, date: baseline.date, isRaceDay: isRaceDay);
      final cushionTime = TrackMoistureModel.measurementTime(
          venueCode: venueCode, date: baseline.date, isRaceDay: isRaceDay, cushion: true);
      if (moistureTime == null || cushionTime == null) return cached;
      final from = moistureTime.isBefore(cushionTime) ? moistureTime : cushionTime;

      AmedasRainResult? amedas;
      try {
        amedas = await AmedasRainService.fetchHourly(venueCode: venueCode, from: from).timeout(_amedasTimeout);
      } catch (e) {
        debugPrint('アメダス取得エラー: $e');
        amedas = null;
      }

      final input = buildTrackRainInput(
        baselineId: baseline.trackConditionId,
        from: from,
        target: target,
        observed: amedas?.hours ?? const {},
        observedUntil: amedas?.observedUntil,
        forecast: parseOpenMeteoHourlyPrecip(pinpoint?['hourlyPrecip']),
      );

      if (input.hours.isEmpty) return cached ?? input;
      await prefs.setString(cacheKey, json.encode(input.toJson()));
      return input;
    } catch (e) {
      debugPrint('馬場予測の雨の用意でエラー: $e');
      return null;
    }
  }

  /// 同じ起点・同じ発走の日時で保存した分。無い・読めなければ null。
  static TrackRainInput? _readCache(SharedPreferences prefs, String key, int baselineId, DateTime target) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final input = TrackRainInput.fromJson(Map<String, dynamic>.from(json.decode(raw) as Map));
      if (input.baselineId != baselineId || input.target != target) return null;
      return input;
    } catch (_) {
      return null;
    }
  }
}
