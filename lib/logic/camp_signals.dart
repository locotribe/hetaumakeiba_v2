// lib/logic/camp_signals.dart

// [追加] 陣営の本気度指数 実施順5 Step3: 仕上げ・人の視点のうち、出馬表と過去走だけで分かるサイン
// （前走からの日数と間隔の区分・休み明けから何戦目・使い詰め・ブリンカー初・当日の馬体重の増減・
// 乗り替わり・この馬への騎乗回数・主戦・前走騎手が同じレースの別馬に騎乗）を出す純粋関数。
// 日数の区切りはオーナー決定の仮の値（Colabの解析で見直す）。DB・画面・通信には触れない (v.2026.10.3+26100303)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/horse_circumstance.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// 長期休養明け: 前走から180日以上
const int kLongLayoffDays = 180;

/// 休み明け: 前走から60日以上（179日以下）
const int kLayoffDays = 60;

/// 標準（外厩調整を含む）: 前走から28日以上（59日以下）。27日以下は間隔が詰まっている
const int kStandardIntervalDays = 28;

/// 使い詰め: 間隔が詰まっていて、休み明けから数えて4戦目以上
const int kOverworkStartNumber = 4;

/// 前走からの間隔の区分。
enum RestCategory {
  /// 初出走（前走なし）
  debut,

  /// 長期休養明け（180日以上）
  longLayoff,

  /// 休み明け（60〜179日）
  layoff,

  /// 標準（28〜59日。外厩調整を含む）
  standard,

  /// 間隔が詰まっている（27日以下）
  tight,

  /// 判定できない（過去走がDBに1件も無く、新馬戦・未勝利戦でもない＝過去走を取得していない）
  unknown,
}

/// 前走からの日数から間隔の区分を決める。前走が無ければ debut。
RestCategory restCategoryOf(int? daysSinceLastStart) {
  if (daysSinceLastStart == null) return RestCategory.debut;
  if (daysSinceLastStart >= kLongLayoffDays) return RestCategory.longLayoff;
  if (daysSinceLastStart >= kLayoffDays) return RestCategory.layoff;
  if (daysSinceLastStart >= kStandardIntervalDays) {
    return RestCategory.standard;
  }
  return RestCategory.tight;
}

/// 当日の馬体重（'478(+4)' など）から増減を読む。未発表・計不・読めなければ null。
int? bodyWeightChangeOf(String? horseWeight) {
  if (horseWeight == null) return null;
  final m = RegExp(r'\(([+-]?\d+)\)').firstMatch(horseWeight);
  if (m == null) return null;
  return int.tryParse(m.group(1)!.replaceAll('+', ''));
}

/// 2つの日付の差（日数）。時刻・夏時間の影響を受けないように日付だけで数える。
int daysBetween(DateTime later, DateTime earlier) {
  final a = DateTime.utc(later.year, later.month, later.day);
  final b = DateTime.utc(earlier.year, earlier.month, earlier.day);
  return a.difference(b).inDays;
}

/// 出走馬1頭の仕上げ・人のサイン。
class HorseCampSignals {
  final String horseId;
  final int horseNumber;

  /// 判定できるか。過去走がDBに1件も無く、新馬戦・未勝利戦でもないときは false
  /// （過去走を取得していない馬を「初出走」と誤判定しないため）
  final bool canJudge;

  /// 前走（実際に出走した走）からの日数。前走が無ければ null
  final int? daysSinceLastStart;

  final RestCategory restCategory;

  /// 休み明け（前の走から60日以上あいた走）から数えて、今回が何戦目か。
  /// 今回が休み明けなら1。休み明けが無ければデビュー戦を1戦目として数える
  final int startNumberSinceLayoff;

  /// 使い詰めのアラート（前走から27日以下 かつ 休み明けから4戦目以上）
  final bool isOverworked;

  /// ブリンカー初装着（競馬新聞ページの印）
  final bool isFirstBlinker;

  /// 当日の馬体重の増減（kg）。未発表なら null
  final int? bodyWeightChange;

  /// 前走の騎手ID。前走が無い・IDが空なら null
  final String? previousJockeyId;

  /// 乗り替わりか。前走が無い・騎手IDが分からないときは null
  final bool? isJockeyChanged;

  /// 今回の騎手が、この馬にこれまで乗った回数（実際に出走した走だけ）
  final int ridesOnThisHorse;

  /// 今回の騎手が主戦か（この馬に最も多く乗っている騎手。同数を含む。1回以上）
  final bool isMainJockey;

  /// 乗り替わりのとき、前走の騎手が同じレースで乗る別の馬の馬番（取消の馬は除く）。いなければ null
  final int? previousJockeyRidingHorseNumber;

  const HorseCampSignals({
    required this.horseId,
    required this.horseNumber,
    required this.canJudge,
    required this.daysSinceLastStart,
    required this.restCategory,
    required this.startNumberSinceLayoff,
    required this.isOverworked,
    required this.isFirstBlinker,
    required this.bodyWeightChange,
    required this.previousJockeyId,
    required this.isJockeyChanged,
    required this.ridesOnThisHorse,
    required this.isMainJockey,
    required this.previousJockeyRidingHorseNumber,
  });
}

class _Start {
  final DateTime date;
  final HorseRaceRecord record;

  _Start(this.date, this.record);
}

/// 出走馬ごとの仕上げ・人のサインを出す（入力の順）。
///
/// [raceDate] 今回レースの開催日。この日より前（同じ日は含まない）の走だけを見る。
/// [horses] 出馬表の出走馬（取消を含む）。
/// [recordsByHorseId] 馬ID → その馬の過去走（horse_performance の行・順不同）。
///   地方・海外・障害の走も「出走」として間隔に数える。取消・除外は数えない。
/// [isMaidenOrNewcomerRace] 今回が新馬戦・未勝利戦か。true のときだけ、過去走が1件も無い馬を初出走とみなす。
///   false のときに過去走が1件も無い馬は、過去走を取得していないとみなして判定しない（RestCategory.unknown）。
List<HorseCampSignals> buildCampSignals({
  required DateTime raceDate,
  required List<PredictionHorseDetail> horses,
  required Map<String, List<HorseRaceRecord>> recordsByHorseId,
  bool isMaidenOrNewcomerRace = false,
}) {
  final raceDay = DateTime(raceDate.year, raceDate.month, raceDate.day);
  final result = <HorseCampSignals>[];

  for (final horse in horses) {
    final records =
        recordsByHorseId[horse.horseId] ?? const <HorseRaceRecord>[];
    final canJudge = records.isNotEmpty || isMaidenOrNewcomerRace;
    final starts = <_Start>[];
    for (final record in records) {
      final date = parseEarnedPrizeDate(record.date);
      if (date == null || !date.isBefore(raceDay)) continue;
      if (!isRaceStart(record)) continue;
      starts.add(_Start(date, record));
    }
    // 新しい順
    starts.sort((a, b) => b.date.compareTo(a.date));

    final daysSinceLastStart =
        starts.isEmpty ? null : daysBetween(raceDay, starts.first.date);

    var startNumber = 1;
    var current = raceDay;
    for (final start in starts) {
      if (daysBetween(current, start.date) >= kLayoffDays) break;
      startNumber++;
      current = start.date;
    }

    final isOverworked = daysSinceLastStart != null &&
        daysSinceLastStart < kStandardIntervalDays &&
        startNumber >= kOverworkStartNumber;

    final rideCounts = <String, int>{};
    for (final start in starts) {
      final id = start.record.jockeyId.trim();
      if (id.isEmpty) continue;
      rideCounts[id] = (rideCounts[id] ?? 0) + 1;
    }
    var maxRides = 0;
    for (final count in rideCounts.values) {
      if (count > maxRides) maxRides = count;
    }
    final currentJockeyId = horse.jockeyId.trim();
    final ridesOnThisHorse =
        currentJockeyId.isEmpty ? 0 : (rideCounts[currentJockeyId] ?? 0);
    final isMainJockey = ridesOnThisHorse > 0 && ridesOnThisHorse >= maxRides;

    String? previousJockeyId;
    if (starts.isNotEmpty) {
      final id = starts.first.record.jockeyId.trim();
      if (id.isNotEmpty) previousJockeyId = id;
    }
    bool? isJockeyChanged;
    if (previousJockeyId != null && currentJockeyId.isNotEmpty) {
      isJockeyChanged = previousJockeyId != currentJockeyId;
    }

    int? previousJockeyRidingHorseNumber;
    if (isJockeyChanged == true) {
      for (final other in horses) {
        if (other.horseId == horse.horseId || other.isScratched) continue;
        if (other.jockeyId.trim() == previousJockeyId) {
          previousJockeyRidingHorseNumber = other.horseNumber;
          break;
        }
      }
    }

    result.add(HorseCampSignals(
      horseId: horse.horseId,
      horseNumber: horse.horseNumber,
      canJudge: canJudge,
      daysSinceLastStart: daysSinceLastStart,
      restCategory: canJudge
          ? restCategoryOf(daysSinceLastStart)
          : RestCategory.unknown,
      startNumberSinceLayoff: startNumber,
      isOverworked: isOverworked,
      isFirstBlinker: horse.isFirstBlinker,
      bodyWeightChange: bodyWeightChangeOf(horse.horseWeight),
      previousJockeyId: previousJockeyId,
      isJockeyChanged: isJockeyChanged,
      ridesOnThisHorse: ridesOnThisHorse,
      isMainJockey: isMainJockey,
      previousJockeyRidingHorseNumber: previousJockeyRidingHorseNumber,
    ));
  }

  return result;
}
