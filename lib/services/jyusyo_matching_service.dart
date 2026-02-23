// lib/services/jyusyo_matching_service.dart

import 'package:hetaumakeiba_v2/db/repositories/jyusyo_race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/jyusyoichiran_page_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';

class JyusyoMatchingService {
  final JyusyoRaceRepository _jyusyoRaceRepository;
  final RaceRepository _raceRepository;

  JyusyoMatchingService({
    JyusyoRaceRepository? jyusyoRaceRepository,
    RaceRepository? raceRepository,
  })  : _jyusyoRaceRepository = jyusyoRaceRepository ?? JyusyoRaceRepository(),
        _raceRepository = raceRepository ?? RaceRepository();

  /// スケジュールデータから重賞一覧のIDを更新・自動連携する
  Future<void> reflectScheduleDataToJyusyoRaces(RaceSchedule schedule) async {
    print('DEBUG: reflectScheduleDataToJyusyoRaces START for date: ${schedule.date}');

    int year;
    try {
      year = int.parse(schedule.date.substring(0, 4));
    } catch (e) {
      print('DEBUG: Error parsing year from date: $e');
      return;
    }

    final maps = await _jyusyoRaceRepository.getJyusyoRacesByYear(year);
    List<JyusyoRace> jyusyoRaces = maps.map((m) => JyusyoRace.fromMap(m)).toList();

    if (jyusyoRaces.isEmpty) {
      print('DEBUG: No Jyusyo races found in DB for year $year');
      return;
    }

    String scheduleDateMMdd = schedule.date.substring(5).replaceAll('-', '/');
    int processedCount = 0;
    int matchedCount = 0;

    for (var venue in schedule.venues) {
      for (var race in venue.races) {
        if (race.raceId.isEmpty) continue;

        var candidates = jyusyoRaces.where((j) {
          bool hasNoId = j.raceId == null || j.raceId!.isEmpty;
          bool dateMatch = j.date.startsWith(scheduleDateMMdd);
          bool venueMatch = venue.venueTitle.contains(j.venue);
          return hasNoId && dateMatch && venueMatch;
        }).toList();

        for (var candidate in candidates) {
          bool isMatch = false;

          // 条件1: グレードの一致
          if (candidate.grade.isNotEmpty && race.grade.isNotEmpty) {
            if (candidate.grade == race.grade) {
              isMatch = true;
            }
          }

          // 条件2: 距離の一致
          if (!isMatch) {
            RegExp digitRegex = RegExp(r'(\d+)');
            String? dist1 = digitRegex.firstMatch(candidate.distance)?.group(1);
            String? dist2 = digitRegex.firstMatch(race.details)?.group(1);

            if (dist1 != null && dist2 != null && dist1 == dist2) {
              isMatch = true;
            }
          }

          // 条件3: レース名の類似判定
          if (!isMatch) {
            String n1 = candidate.raceName.replaceAll(RegExp(r'\s'), '');
            String n2 = race.raceName.replaceAll(RegExp(r'\s'), '');
            if (n1 == n2) {
              isMatch = true;
            }
          }

          if (isMatch && candidate.id != null) {
            await _jyusyoRaceRepository.updateJyusyoRaceId(candidate.id!, race.raceId);
            matchedCount++;
          }
        }
        processedCount++;
      }
    }
    print('DEBUG: reflectScheduleDataToJyusyoRaces END. Processed: $processedCount, Matched: $matchedCount');
  }

  /// コース種別・距離・グレードによる厳格マッチング
  Future<List<JyusyoRace>> fillMissingJyusyoIdsFromLocalSchedule(int year, {int? targetMonth}) async {
    List<JyusyoRace> updatedRaces = [];

    final maps = await _jyusyoRaceRepository.getJyusyoRacesByYear(year);
    List<JyusyoRace> allRaces = maps.map((m) => JyusyoRace.fromMap(m)).toList();

    List<JyusyoRace> missingIdRaces = allRaces.where((r) {
      if (r.raceId != null && r.raceId!.isNotEmpty) return false;

      final dateMatch = RegExp(r'^(\d{1,2})/').firstMatch(r.date);
      if (dateMatch == null) return false;

      int raceMonth = int.parse(dateMatch.group(1)!);
      if (targetMonth != null && raceMonth != targetMonth) return false;

      return true;
    }).toList();

    if (missingIdRaces.isEmpty) return [];

    for (var targetRace in missingIdRaces) {
      String dateStr = targetRace.date;
      final dateMatch = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(dateStr);
      if (dateMatch == null) continue;

      String month = dateMatch.group(1)!.padLeft(2, '0');
      String day = dateMatch.group(2)!.padLeft(2, '0');
      String targetDate = '$year-$month-$day';

      final schedule = await _raceRepository.getRaceSchedule(targetDate);
      if (schedule == null) continue;

      bool isUpdated = false;
      String? foundRaceId;

      for (var venue in schedule.venues) {
        if (!venue.venueTitle.contains(targetRace.venue)) continue;

        for (var race in venue.races) {
          if (race.raceId.isEmpty) continue;

          bool isMatch = false;

          String type1 = _getCourseType(targetRace.distance);
          String type2 = _getCourseType(race.details);

          int? dist1 = _extractNumber(targetRace.distance);
          int? dist2 = _extractNumber(race.details);

          if (type1.isNotEmpty && type2.isNotEmpty && dist1 != null && dist2 != null) {
            if (type1 == type2 && dist1 == dist2) {
              isMatch = true;
            }
          }

          if (!isMatch && targetRace.grade.isNotEmpty && race.grade.isNotEmpty) {
            String g1 = targetRace.grade.replaceAll(RegExp(r'[.\-\s]'), '');
            String g2 = race.grade.replaceAll(RegExp(r'[.\-\s]'), '');
            if (g1 == g2) {
              isMatch = true;
            }
          }

          if (isMatch) {
            foundRaceId = race.raceId;
            isUpdated = true;
            break;
          }
        }
        if (isUpdated) break;
      }

      if (isUpdated && foundRaceId != null && targetRace.id != null) {
        await _jyusyoRaceRepository.updateJyusyoRaceId(targetRace.id!, foundRaceId);

        updatedRaces.add(JyusyoRace(
          id: targetRace.id,
          raceId: foundRaceId,
          year: targetRace.year,
          date: targetRace.date,
          raceName: targetRace.raceName,
          grade: targetRace.grade,
          venue: targetRace.venue,
          distance: targetRace.distance,
          conditions: targetRace.conditions,
          weight: targetRace.weight,
          sourceUrl: targetRace.sourceUrl,
        ));
      }
    }

    return updatedRaces;
  }

  int? _extractNumber(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  String _getCourseType(String text) {
    if (text.contains('障')) return '障';
    if (text.contains('ダ')) return 'ダ';
    if (text.contains('芝')) return '芝';
    return '';
  }
}