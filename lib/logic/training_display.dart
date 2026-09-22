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
  final List<TrainingCellView> cells; // 常に5マス
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

/// 5マスの並び（ハロン数）。坂路は先頭(5F)がほぼ空欄。
const List<int> _hanroOrder = [5, 4, 3, 2, 1];
const List<int> _otherOrder = [6, 5, 4, 3, 1];

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
/// 時計は netkeiba の行があればその5枠、無ければ pakara の値を同じ並びに置く。
/// ラップ = そのマスの時計 − 次に値のあるマスの時計、最後の値のマスは1Fそのもの。
TrainingRowView buildTrainingRowView(MergedTrainingEntry entry) {
  final nk = entry.netkeiba;
  final pakara = entry.pakara;
  String courseLabel = '';
  bool isHanro = false;
  Map<int, double> furlongs = {};
  List<int> colors = const [0, 0, 0, 0, 0];

  if (nk != null) {
    courseLabel = nk.courseRaw;
    isHanro = classifyTrainingCourse(nk.courseRaw).isHanro;
    furlongs = slotsToFurlongs(nk.courseRaw, nk.slots);
    colors = List<int>.generate(
        NetkeibaTrainingSession.slotCount, (i) => nk.colors[i] ?? 0);
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
    cells.add(TrainingCellView(time: time, lap: lap, color: colors[i]));
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
  final String title; // 例: 2026/05/31 東京11R 東京優駿 / 今回のレース
  final String? result; // 例: 1着
  final bool isCurrent;
  final List<MergedTrainingEntry> entries; // 新しい順

  const TrainingRaceGroup({
    this.raceId,
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
  final String ymd;
  final String title;
  final String? result;
  final bool isCurrent;

  const _RaceSlot({
    required this.raceId,
    required this.ymd,
    required this.title,
    this.result,
    required this.isCurrent,
  });
}
