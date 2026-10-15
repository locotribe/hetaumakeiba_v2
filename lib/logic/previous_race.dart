// lib/logic/previous_race.dart

// [追加] 前走と路線の部品 Step1: 基準日より前に実際に出走した走と、前走（その一番新しい走）を返す共通の部品。取消・除外・着順が空欄の行は飛ばし、中止・失格は出走に数える（本気度 camp_signals と同じ決め方） (v.2026.10.16+26101605)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/horse_circumstance.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 実際に出走した走1つ（読み取った日付つき）。
class RaceStart {
  final DateTime date;
  final HorseRaceRecord record;

  const RaceStart(this.date, this.record);
}

/// [raceDate] より前（同じ日は含まない）に実際に出走した走を、新しい順に返す。
///
/// - 実際に出走した走は isRaceStart（着順が数字・中止・失格）。取消・除外・着順が空欄の行は含めない。
/// - 日付（'2025/07/19' の形）が読めない行は含めない。
/// - [raceDate] が null のときは日付で絞らない（基準日が分からないとき用）。
/// - [records] の並び順は問わない。
List<RaceStart> startsBefore(
  List<HorseRaceRecord> records,
  DateTime? raceDate,
) {
  final raceDay = raceDate == null
      ? null
      : DateTime(raceDate.year, raceDate.month, raceDate.day);
  final starts = <RaceStart>[];
  for (final record in records) {
    final date = parseEarnedPrizeDate(record.date);
    if (date == null) continue;
    if (raceDay != null && !date.isBefore(raceDay)) continue;
    if (!isRaceStart(record)) continue;
    starts.add(RaceStart(date, record));
  }
  // 新しい順
  starts.sort((a, b) => b.date.compareTo(a.date));
  return starts;
}

/// 前走 = [raceDate] より前に実際に出走した一番新しい走。無ければ null。
/// [raceDate] が null のときは日付で絞らず、実際に出走した一番新しい走を返す。
HorseRaceRecord? previousStartOf(
  List<HorseRaceRecord>? records,
  DateTime? raceDate,
) {
  if (records == null || records.isEmpty) return null;
  final starts = startsBefore(records, raceDate);
  return starts.isEmpty ? null : starts.first.record;
}
