// lib/logic/ai/stats_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/complex_aptitude_model.dart';
import 'package:hetaumakeiba_v2/models/best_time_stats_model.dart';
import 'package:hetaumakeiba_v2/models/fastest_agari_stats_model.dart';

class StatsAnalyzer {
  /// コース種別・距離が完全に一致する過去レースを分析する
  static ComplexAptitudeStats analyzeDistanceCourseAptitude({
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
  }) {
    final raceInfo = raceData.raceDetails1 ?? '';
    if (raceInfo.isEmpty) return ComplexAptitudeStats();

    final String currentTrackType = raceInfo.startsWith('障')
        ? '障'
        : (raceInfo.startsWith('ダ') ? 'ダ' : '芝');
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    final String currentDistance = distanceMatch?.group(1) ?? '';

    if (currentDistance.isEmpty) return ComplexAptitudeStats();

    final List<HorseRaceRecord> filteredRecords = pastRecords.where((record) {
      final String recordTrackType = record.distance.startsWith('障')
          ? '障'
          : (record.distance.startsWith('ダ') ? 'ダ' : '芝');
      final String recordDistance =
      record.distance.replaceAll(RegExp(r'[^0-9]'), '');

      return recordTrackType == currentTrackType &&
          recordDistance == currentDistance;
    }).toList();

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

  /// ★追加: 枠順傾向の分析 (パーセンテージ区分)
  /// 戻り値: {'inner': {winRate: 0.2, count: 5}, 'middle': ..., 'outer': ...}
  static Map<String, Map<String, double>> analyzeGateTendency({
    required List<HorseRaceRecord> pastRecords,
  }) {
    int innerCount = 0, innerWin = 0;
    int middleCount = 0, middleWin = 0;
    int outerCount = 0, outerWin = 0;

    for (final record in pastRecords) {
      final rank = int.tryParse(record.rank);
      final horseNum = int.tryParse(record.horseNumber);
      final totalHorses = int.tryParse(record.numberOfHorses);

      if (rank == null || horseNum == null || totalHorses == null || totalHorses == 0) continue;

      // 位置率 (Position Ratio)
      final double ratio = horseNum / totalHorses;

      if (ratio <= 0.33) {
        innerCount++;
        if (rank == 1) innerWin++;
      } else if (ratio <= 0.66) {
        middleCount++;
        if (rank == 1) middleWin++;
      } else {
        outerCount++;
        if (rank == 1) outerWin++;
      }
    }

    return {
      'inner': {
        'count': innerCount.toDouble(),
        'winRate': innerCount > 0 ? innerWin / innerCount : 0.0,
      },
      'middle': {
        'count': middleCount.toDouble(),
        'winRate': middleCount > 0 ? middleWin / middleCount : 0.0,
      },
      'outer': {
        'count': outerCount.toDouble(),
        'winRate': outerCount > 0 ? outerWin / outerCount : 0.0,
      },
    };
  }

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

  static BestTimeStats? analyzeBestTime({
    required PredictionRaceData raceData,
    required List<HorseRaceRecord> pastRecords,
  }) {
    final venueName = raceData.venue;
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceData.raceDetails1 ?? '');
    if (distanceMatch == null) return null;
    final currentDistance = distanceMatch.group(1)!;

    final relevantRecords = pastRecords.where((record) {
      final recordVenueMatch = record.venue.contains(venueName);
      final recordDistance = record.distance.replaceAll(RegExp(r'[^0-9]'), '');
      return recordVenueMatch && recordDistance == currentDistance;
    }).toList();

    if (relevantRecords.isEmpty) return null;

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

    return BestTimeStats(
      timeInSeconds: minTimeInSeconds,
      formattedTime: bestTimeRecord.time,
      trackCondition: bestTimeRecord.trackCondition,
      raceName: bestTimeRecord.raceName,
      date: bestTimeRecord.date,
    );
  }

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

  static String analyzeTrackAptitude({
    required List<HorseRaceRecord> pastRecords,
  }) {
    final heavyTrackRaces = pastRecords
        .where((r) => ['稍重', '重', '不良'].contains(r.trackCondition))
        .toList();
    final goodTrackRaces =
    pastRecords.where((r) => r.trackCondition == '良').toList();

    if (heavyTrackRaces.isEmpty) {
      return '道悪未知 －';
    }

    final double goodTrackShowRate = goodTrackRaces.isEmpty
        ? -1.0
        : goodTrackRaces.where((r) => (int.tryParse(r.rank) ?? 99) <= 3).length / goodTrackRaces.length;

    final double heavyTrackShowRate =
        heavyTrackRaces.where((r) => (int.tryParse(r.rank) ?? 99) <= 3).length / heavyTrackRaces.length;

    if (goodTrackShowRate < 0) {
      if (heavyTrackShowRate >= 0.5) return '道悪巧者 ◎';
      return '平均的 〇';
    }

    if (heavyTrackShowRate >= goodTrackShowRate + 0.1) {
      return '道悪巧者 ◎';
    } else if (heavyTrackShowRate >= goodTrackShowRate - 0.1) {
      return '平均的 〇';
    } else {
      return '道悪不得手 ✕';
    }
  }
}