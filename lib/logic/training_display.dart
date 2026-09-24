// lib/logic/training_display.dart

import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/utils/training_course_utils.dart';
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';

// [追加] 調教タブ改修Step5: 調教1本の表示用データと、レースごとのまとめ（純粋関数） (v.2026.9.23+26092302)

/// 時計1マス分。
class TrainingCellView {
  final double? time; // 累計タイム（無ければ null → '-' 表示）
  final double? lap; // そのマスから始まるラップ（最後のマスは1Fそのもの）
  final int color; // 0=なし 1=橙 2=薄黄（netkeiba の TokeiColor）

  const TrainingCellView({this.time, this.lap, this.color = 0});
}

/// 調教1本の表示用データ。pakara / netkeiba のどちら由来かは区別しない。
class TrainingRowView {
  final String trainingDate; // YYYYMMDD
  final String? trainingTime; // HHmm
  final String courseLabel; // 栗坂 / 美坂 / ＣＷ / 美Ｗ / ＤＰ …
  final bool isHanro;
  final List<TrainingCellView> cells; // 常に6マス
  final String? trackCondition;
  final String? rider;
  final bool isBestTime;
  final int? position;
  final String? trainingLoad;
  final String? critic;
  final String? rank;
  final List<TrainingPartner> partners;

  const TrainingRowView({
    required this.trainingDate,
    this.trainingTime,
    required this.courseLabel,
    required this.isHanro,
    required this.cells,
    this.trackCondition,
    this.rider,
    this.isBestTime = false,
    this.position,
    this.trainingLoad,
    this.critic,
    this.rank,
    this.partners = const [],
  });

  /// 例: 26/09/16(水)
  String get dateLabel {
    if (trainingDate.length != 8) return trainingDate;
    final y = int.tryParse(trainingDate.substring(0, 4));
    final m = int.tryParse(trainingDate.substring(4, 6));
    final d = int.tryParse(trainingDate.substring(6, 8));
    if (y == null || m == null || d == null) return trainingDate;
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[DateTime(y, m, d).weekday - 1];
    return '${trainingDate.substring(2, 4)}/${trainingDate.substring(4, 6)}/${trainingDate.substring(6, 8)}($weekday)';
  }

  /// 例: 05:35（時刻が無ければ null）
  String? get timeLabel {
    final t = trainingTime;
    if (t == null || t.length != 4) return null;
    return '${t.substring(0, 2)}:${t.substring(2, 4)}';
  }

  /// 見出し（例: 26/09/16(水) 05:35 ＣＷ 重 助手）
  String get headerLabel => [dateLabel, timeLabel, courseLabel, trackCondition, rider]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');

  /// 脚色＋位置（例: 馬也⑧）。どちらも無ければ null。
  String? get loadLabel {
    final load = trainingLoad ?? '';
    var positionText = '';
    final p = position;
    if (p != null && p > 0) {
      positionText = p <= 20 ? String.fromCharCode(0x2460 + p - 1) : '($p)';
    }
    final label = '$load$positionText';
    return label.isEmpty ? null : label;
  }

  /// 最後の1Fが1つ前のラップより速ければ -1、遅ければ 1、同じ・判断できなければ 0。
  int get lastLapTrend {
    final laps = cells.where((c) => c.lap != null).map((c) => c.lap!).toList();
    if (laps.length < 2) return 0;
    final last = laps.last;
    final prev = laps[laps.length - 2];
    if (last < prev) return -1;
    if (last > prev) return 1;
    return 0;
  }
}

// [修正] 中間追切6列化: 表示を6マスにして2Fを出す。坂路は先頭(6F・5F)がほぼ空欄、ウッドは2Fも表示 (v.2026.9.24+26092405)
/// 6マスの並び（ハロン数）。表示用。坂路は先頭(6F・5F)がほぼ空欄。
const List<int> _hanroOrder = [6, 5, 4, 3, 2, 1];
const List<int> _otherOrder = [6, 5, 4, 3, 2, 1];

// [追加] 中間追切6列化: netkeibaのスロット(5枠)→ハロンの対応。色をハロンに割り当てるのに使う（slotsToFurlongsと同じ並び。netkeibaは2Fを持たない） (v.2026.9.24+26092405)
const List<int> _nkSlotOrderHanro = [5, 4, 3, 2, 1];
const List<int> _nkSlotOrderOther = [6, 5, 4, 3, 1];

/// pakara の（地区, 種別）を netkeiba と同じ表記にする。
String pakaraCourseLabel(String location, String trackType) {
  final ritto = location.contains('栗東');
  final miho = location.contains('美浦');
  if (trackType == '坂路') {
    return ritto ? '栗坂' : (miho ? '美坂' : '坂路');
  }
  if (trackType == 'ウッド') {
    return ritto ? 'ＣＷ' : (miho ? '美Ｗ' : 'ウッド');
  }
  return '$location$trackType';
}

/// 突き合わせ後の1件を表示用データにする。
/// 時計は netkeiba の行があればその枠、無ければ pakara の値を同じ並びに置く。
/// netkeiba に無いハロン（主にウッドの2F）は、同じ調教の pakara があれば pakara で補完する。
/// ラップ = そのマスの時計 − 次に値のあるマスの時計、最後の値のマスは1Fそのもの。
TrainingRowView buildTrainingRowView(MergedTrainingEntry entry) {
  final nk = entry.netkeiba;
  final pakara = entry.pakara;
  String courseLabel = '';
  bool isHanro = false;
  Map<int, double> furlongs = {};
  // [修正] 中間追切6列化: 色はハロン→色で持つ（列を増やしても崩れないように） (v.2026.9.24+26092405)
  final Map<int, int> colorByFurlong = {};

  if (nk != null) {
    courseLabel = nk.courseRaw;
    isHanro = classifyTrainingCourse(nk.courseRaw).isHanro;
    furlongs = slotsToFurlongs(nk.courseRaw, nk.slots);
    // [追加] 中間追切6列化: netkeibaの色(5枠)をハロンに割り当てる (v.2026.9.24+26092405)
    final nkSlotOrder = isHanro ? _nkSlotOrderHanro : _nkSlotOrderOther;
    for (int i = 0; i < nkSlotOrder.length && i < nk.colors.length; i++) {
      final c = nk.colors[i];
      if (c != null) colorByFurlong[nkSlotOrder[i]] = c;
    }
    // [追加] 中間追切6列化: netkeibaに無いハロン(主にウッドの2F)を、同じ調教のpakaraで補完（netkeibaにある枠は上書きしない） (v.2026.9.24+26092405)
    if (pakara != null) {
      void fillFromPakara(int furlong, double? value) {
        if (value != null && !furlongs.containsKey(furlong)) {
          furlongs[furlong] = value;
        }
      }

      fillFromPakara(6, pakara.f6);
      fillFromPakara(5, pakara.f5);
      fillFromPakara(4, pakara.f4);
      fillFromPakara(3, pakara.f3);
      fillFromPakara(2, pakara.f2);
      fillFromPakara(1, pakara.f1);
    }
  } else if (pakara != null) {
    courseLabel = pakaraCourseLabel(pakara.location, pakara.trackType);
    isHanro = pakara.trackType == '坂路';
    furlongs = {
      if (pakara.f6 != null) 6: pakara.f6!,
      if (pakara.f5 != null) 5: pakara.f5!,
      if (pakara.f4 != null) 4: pakara.f4!,
      if (pakara.f3 != null) 3: pakara.f3!,
      if (pakara.f2 != null) 2: pakara.f2!,
      if (pakara.f1 != null) 1: pakara.f1!,
    };
  }

  final order = isHanro ? _hanroOrder : _otherOrder;
  final times = order.map((k) => furlongs[k]).toList();
  final cells = <TrainingCellView>[];
  for (int i = 0; i < times.length; i++) {
    final time = times[i];
    double? lap;
    if (time != null) {
      double? next;
      for (int j = i + 1; j < times.length; j++) {
        if (times[j] != null) {
          next = times[j];
          break;
        }
      }
      final value = next == null ? time : time - next;
      lap = double.parse(value.toStringAsFixed(1));
    }
    // [修正] 中間追切6列化: 色はハロン→色マップから引く（無ければ0=色なし） (v.2026.9.24+26092405)
    cells.add(TrainingCellView(
        time: time, lap: lap, color: colorByFurlong[order[i]] ?? 0));
  }

  return TrainingRowView(
    trainingDate: entry.trainingDate,
    trainingTime: entry.trainingTime,
    courseLabel: courseLabel,
    isHanro: isHanro,
    cells: cells,
    trackCondition: nk?.trackCondition,
    rider: nk?.rider,
    isBestTime: nk?.isBestTime == true,
    position: nk?.position,
    trainingLoad: nk?.trainingLoad,
    critic: nk?.critic,
    rank: nk?.rank,
    partners: nk?.partners ?? const [],
  );
}

/// このレースの最終追切を選ぶ。
/// 1. このレース向けで、調教ページ由来（ラップが入っている）netkeiba の行
/// 2. 無ければ一覧の先頭（レース日より前の最新の1本）
/// [entries] はレース日より前に絞った新しい順の一覧。
MergedTrainingEntry? pickFinalEntry(
    List<MergedTrainingEntry> entries, String raceId) {
  for (final entry in entries) {
    final nk = entry.netkeiba;
    if (nk != null && nk.raceId == raceId && nk.laps.any((l) => l != null)) {
      return entry;
    }
  }
  return entries.isEmpty ? null : entries.first;
}

/// レースごとのまとまり。
class TrainingRaceGroup {
  final String? raceId;
  // [追加] 調教タイム個別データ移植Step2: レース見出しのレース遷移リンク用の日付（例: 2025/07/19） (v.2026.9.25+26092502)
  final String raceDate;
  final String title; // 例: 2026/05/31 東京11R 東京優駿 / 今回のレース
  final String? result; // 例: 1着
  final bool isCurrent;
  final List<MergedTrainingEntry> entries; // 新しい順

  const TrainingRaceGroup({
    this.raceId,
    this.raceDate = '',
    required this.title,
    this.result,
    required this.isCurrent,
    required this.entries,
  });
}

/// 過去レースの見出し（例: 2025/07/19 福島11R 〇〇特別）
String pastRaceTitle(HorseRaceRecord record) {
  final place =
      RegExp(r'[^\d\s]+').firstMatch(record.venue)?.group(0) ?? record.venue;
  final number = record.raceNumber.trim().isEmpty ? '' : '${record.raceNumber.trim()}R';
  return [record.date, '$place$number', record.raceName]
      .where((s) => s.trim().isNotEmpty)
      .join(' ');
}

/// 過去レースの着順（例: 1着 / 中止）。無ければ null。
String? pastRaceResult(HorseRaceRecord record) {
  final rank = record.rank.trim();
  if (rank.isEmpty) return null;
  return int.tryParse(rank) != null ? '$rank着' : rank;
}

/// 調教をレースごとに振り分ける（調教日より後で最初のレースのまとまりへ）。
/// [entries] はレース日より前に絞った新しい順の一覧、[pastRaces] はその馬の過去成績。
/// 今回のレースより後のレースは無視する。空のまとまりは返さない。新しいレースから順に返す。
List<TrainingRaceGroup> groupTrainingByRace({
  required List<MergedTrainingEntry> entries,
  required List<HorseRaceRecord> pastRaces,
  required String currentRaceId,
  required String currentRaceYmd,
}) {
  final slots = <_RaceSlot>[];
  for (final record in pastRaces) {
    if (record.raceId == currentRaceId) continue;
    final ymd = toYyyymmdd(record.date);
    if (ymd == null) continue;
    if (currentRaceYmd.isNotEmpty && ymd.compareTo(currentRaceYmd) >= 0) {
      continue;
    }
    slots.add(_RaceSlot(
      raceId: record.raceId,
      // [追加] 調教タイム個別データ移植Step2: レース遷移リンク用の日付 (v.2026.9.25+26092502)
      raceDate: record.date,
      ymd: ymd,
      title: pastRaceTitle(record),
      result: pastRaceResult(record),
      isCurrent: false,
    ));
  }
  slots.add(_RaceSlot(
    raceId: currentRaceId,
    ymd: currentRaceYmd.isEmpty ? '99999999' : currentRaceYmd,
    title: '今回のレース',
    result: null,
    isCurrent: true,
  ));
  slots.sort((a, b) => a.ymd.compareTo(b.ymd));

  final buckets = <int, List<MergedTrainingEntry>>{};
  for (final entry in entries) {
    var index = slots.length - 1;
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].ymd.compareTo(entry.trainingDate) > 0) {
        index = i;
        break;
      }
    }
    buckets.putIfAbsent(index, () => []).add(entry);
  }

  final groups = <TrainingRaceGroup>[];
  for (int i = slots.length - 1; i >= 0; i--) {
    final list = buckets[i];
    if (list == null || list.isEmpty) continue;
    final slot = slots[i];
    groups.add(TrainingRaceGroup(
      raceId: slot.raceId,
      // [追加] 調教タイム個別データ移植Step2: レース遷移リンク用の日付 (v.2026.9.25+26092502)
      raceDate: slot.raceDate,
      title: slot.title,
      result: slot.result,
      isCurrent: slot.isCurrent,
      entries: list,
    ));
  }
  return groups;
}

class _RaceSlot {
  final String raceId;
  // [追加] 調教タイム個別データ移植Step2: レース遷移リンク用の日付 (v.2026.9.25+26092502)
  final String raceDate;
  final String ymd;
  final String title;
  final String? result;
  final bool isCurrent;

  const _RaceSlot({
    required this.raceId,
    this.raceDate = '',
    required this.ymd,
    required this.title,
    this.result,
    required this.isCurrent,
  });
}

// [追加] 調教タブ改修Step6: 調教と出走レースを日付順に並べた一覧（調教タイムタブ用） (v.2026.9.23+26092303)

/// 一覧の1件。調教（[entry]）か出走レース（[race]）のどちらか一方が入る。
class TrainingTimelineItem {
  final String date; // YYYYMMDD
  final MergedTrainingEntry? entry;
  final HorseRaceRecord? race;

  const TrainingTimelineItem({required this.date, this.entry, this.race});

  bool get isRace => race != null;
}

/// 調教と出走レースを日付の新しい順に並べる。同じ日はレースを先、調教は時刻の新しい順。
/// 日付が読めないレースは入れない。
List<TrainingTimelineItem> buildTrainingTimeline(
  List<MergedTrainingEntry> entries,
  List<HorseRaceRecord> races,
) {
  final items = <TrainingTimelineItem>[
    for (final entry in entries)
      TrainingTimelineItem(date: entry.trainingDate, entry: entry),
  ];
  for (final race in races) {
    final ymd = toYyyymmdd(race.date);
    if (ymd != null) items.add(TrainingTimelineItem(date: ymd, race: race));
  }
  items.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    if (a.isRace != b.isRace) return a.isRace ? -1 : 1;
    return (b.entry?.trainingTime ?? '').compareTo(a.entry?.trainingTime ?? '');
  });
  return items;
}
