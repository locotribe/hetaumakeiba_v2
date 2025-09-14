// lib/logic/ai/stats_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/complex_aptitude_model.dart';
import 'package:hetaumakeiba_v2/models/best_time_stats_model.dart';
import 'package:hetaumakeiba_v2/models/fastest_agari_stats_model.dart';

class StatsAnalyzer {
  /// コース・距離・馬場状態の3要素が完全に一致する過去レースを分析する
  static ComplexAptitudeStats analyzeComplexAptitude({
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
  }) {
    // 1. 今回のレース条件を解析
    final raceInfo = raceData.raceDetails1 ?? '';
    if (raceInfo.isEmpty) return ComplexAptitudeStats();

    // コース種別 (芝/ダート/障害)
    final String currentTrackType = raceInfo.startsWith('障')
        ? '障'
        : (raceInfo.startsWith('ダ') ? 'ダ' : '芝');
    // 距離
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    final String currentDistance = distanceMatch?.group(1) ?? '';
    // 馬場状態
    String currentTrackCondition = '良'; // デフォルト
    if (raceInfo.contains('稍重'))
      currentTrackCondition = '稍重';
    else if (raceInfo.contains('重'))
      currentTrackCondition = '重';
    else if (raceInfo.contains('不良')) currentTrackCondition = '不良';

    if (currentDistance.isEmpty) return ComplexAptitudeStats();

    // 2. 条件に完全一致する過去レースをフィルタリング
    final List<HorseRaceRecord> filteredRecords = pastRecords.where((record) {
      // 過去レースのコース種別
      final String recordTrackType = record.distance.startsWith('障')
          ? '障'
          : (record.distance.startsWith('ダ') ? 'ダ' : '芝');
      // 過去レースの距離
      final String recordDistance =
      record.distance.replaceAll(RegExp(r'[^0-9]'), '');

      return recordTrackType == currentTrackType &&
          recordDistance == currentDistance &&
          record.trackCondition == currentTrackCondition;
    }).toList();

    // 3. 成績を集計
    if (filteredRecords.isEmpty) {
      return ComplexAptitudeStats();
    }

    int winCount = 0;
    int placeCount = 0;
    int showCount = 0;

    for (final record in filteredRecords) {
      final rank = int.tryParse(record.rank);
      if (rank == null) continue;
      if (rank == 1) winCount++;
      if (rank <= 2) placeCount++;
      if (rank <= 3) showCount++;
    }

    final raceCount = filteredRecords.length;
    final otherCount = raceCount - showCount;

    return ComplexAptitudeStats(
      raceCount: raceCount,
      winCount: winCount,
      placeCount: placeCount,
      showCount: showCount,
      recordString:
      '$winCount-${placeCount - winCount}-${showCount - placeCount}-$otherCount',
    );
  }

  /// タイム文字列（例: "1:58.2"）を秒数（例: 118.2）に変換する
  static double? _parseTimeToSeconds(String timeStr) {
    if (timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    try {
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = double.parse(parts[1]);
        return (minutes * 60) + seconds;
      } else if (parts.length == 1) {
        return double.parse(parts[0]);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// 今回のレースと同一競馬場・同一距離の過去レースから持ち時計（ベストタイム）を算出する
  static BestTimeStats? analyzeBestTime({
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
  }) {
    // 1. 今回のレース条件を特定
    final venueName = raceData.venue;
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceData.raceDetails1 ?? '');
    if (distanceMatch == null) return null;
    final currentDistance = distanceMatch.group(1)!;

    // 2. 条件に一致する過去レースをフィルタリング
    final relevantRecords = pastRecords.where((record) {
      final recordVenueMatch = record.venue.contains(venueName);
      final recordDistance = record.distance.replaceAll(RegExp(r'[^0-9]'), '');
      return recordVenueMatch && recordDistance == currentDistance;
    }).toList();

    if (relevantRecords.isEmpty) return null;

    // 3. 最速タイムを持つレコードを特定
    HorseRaceRecord? bestTimeRecord;
    double minTimeInSeconds = double.infinity;

    for (final record in relevantRecords) {
      final timeInSeconds = _parseTimeToSeconds(record.time);
      if (timeInSeconds != null && timeInSeconds < minTimeInSeconds) {
        minTimeInSeconds = timeInSeconds;
        bestTimeRecord = record;
      }
    }

    if (bestTimeRecord == null) return null;

    // 4. 結果をBestTimeStatsモデルに格納して返す
    return BestTimeStats(
      timeInSeconds: minTimeInSeconds,
      formattedTime: bestTimeRecord.time,
      trackCondition: bestTimeRecord.trackCondition,
      raceName: bestTimeRecord.raceName,
      date: bestTimeRecord.date,
    );
  }

  /// 過去レースから最速の上がり3ハロンタイムを分析する
  static FastestAgariStats? analyzeFastestAgari({
    required List<HorseRaceRecord> pastRecords,
  }) {
    if (pastRecords.isEmpty) return null;

    HorseRaceRecord? bestAgariRecord;
    double fastestAgari = double.infinity;

    for (final record in pastRecords) {
      final agariTime = double.tryParse(record.agari);
      if (agariTime != null && agariTime > 0 && agariTime < fastestAgari) {
        fastestAgari = agariTime;
        bestAgariRecord = record;
      }
    }

    if (bestAgariRecord == null) return null;

    return FastestAgariStats(
      agariInSeconds: fastestAgari,
      formattedAgari: bestAgariRecord.agari,
      trackCondition: bestAgariRecord.trackCondition,
      raceName: bestAgariRecord.raceName,
      date: bestAgariRecord.date,
    );
  }
}