// lib/logic/training_merge.dart

import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/utils/training_course_utils.dart';

// [追加] 調教タブ改修Step3: pakara と netkeiba の同じ調教を1件にまとめる（設計書 3-4） (v.2026.9.22+26092212)

/// 突き合わせ後の調教1件。pakara・netkeiba のどちらか一方だけのこともある。
class MergedTrainingEntry {
  final String trainingDate; // YYYYMMDD
  final String? trainingTime; // HHmm（netkeiba を優先、無ければ pakara）
  final TrainingTimeModel? pakara;
  final NetkeibaTrainingSession? netkeiba;

  const MergedTrainingEntry({
    required this.trainingDate,
    this.trainingTime,
    this.pakara,
    this.netkeiba,
  });
}

/// 時刻で突き合わせるときの許容差（分）
const int kTrainingMatchMinutes = 10;

/// 時計で突き合わせるときの許容差（秒）: 1F / 最長の共通ハロン
const double kTrainingMatchLastFurlong = 0.1;
const double kTrainingMatchLongFurlong = 0.2;

/// pakara と netkeiba の調教を突き合わせ、日付・時刻の新しい順に返す。
/// 1. 同じ日付・同じ（地区, 種別）の pakara 行が候補（ＤＰ・函Ｗ など pakara に無いコースは netkeiba のみの行）
/// 2. 両方に時刻があれば、差が [kTrainingMatchMinutes] 分以内で最も近いもの
/// 3. 2 で決まらなければ、1F の差 ≤ [kTrainingMatchLastFurlong] かつ
///    最長の共通ハロン（6F→5F→4F→3F の順で最初に両方ある所）の差 ≤ [kTrainingMatchLongFurlong] で最も近いもの
/// 4. 1本の pakara 行は1本の netkeiba 行にしか使わない
List<MergedTrainingEntry> mergeTrainingSources(
  List<TrainingTimeModel> pakaraList,
  List<NetkeibaTrainingSession> netkeibaList,
) {
  final used = <int>{};
  final entries = <MergedTrainingEntry>[];

  for (final nk in netkeibaList) {
    final info = classifyTrainingCourse(nk.courseRaw);
    int? matchIndex;
    if (info.pakaraTrackType != null) {
      final candidates = <int>[];
      for (int i = 0; i < pakaraList.length; i++) {
        if (used.contains(i)) continue;
        final p = pakaraList[i];
        if (p.trainingDate != nk.trainingDate) continue;
        if (p.trackType != info.pakaraTrackType) continue;
        if (info.location.isNotEmpty && !p.location.contains(info.location)) {
          continue;
        }
        candidates.add(i);
      }
      matchIndex = _matchByTime(nk, pakaraList, candidates) ??
          _matchByClock(nk, pakaraList, candidates);
    }
    if (matchIndex != null) used.add(matchIndex);
    final pakara = matchIndex == null ? null : pakaraList[matchIndex];
    entries.add(MergedTrainingEntry(
      trainingDate: nk.trainingDate,
      trainingTime: nk.trainingTime ?? _timeOrNull(pakara?.trainingTime),
      pakara: pakara,
      netkeiba: nk,
    ));
  }

  for (int i = 0; i < pakaraList.length; i++) {
    if (used.contains(i)) continue;
    final p = pakaraList[i];
    entries.add(MergedTrainingEntry(
      trainingDate: p.trainingDate,
      trainingTime: _timeOrNull(p.trainingTime),
      pakara: p,
    ));
  }

  entries.sort((a, b) {
    final byDate = b.trainingDate.compareTo(a.trainingDate);
    if (byDate != 0) return byDate;
    return (b.trainingTime ?? '').compareTo(a.trainingTime ?? '');
  });
  return entries;
}

String? _timeOrNull(String? hhmm) =>
    (hhmm != null && hhmm.length == 4) ? hhmm : null;

int? _minutes(String? hhmm) {
  if (hhmm == null || hhmm.length != 4) return null;
  final h = int.tryParse(hhmm.substring(0, 2));
  final m = int.tryParse(hhmm.substring(2, 4));
  if (h == null || m == null) return null;
  return h * 60 + m;
}

int? _matchByTime(NetkeibaTrainingSession nk,
    List<TrainingTimeModel> pakaraList, List<int> candidates) {
  final nkMinutes = _minutes(nk.trainingTime);
  if (nkMinutes == null) return null;
  int? best;
  int bestDiff = kTrainingMatchMinutes + 1;
  for (final i in candidates) {
    final pMinutes = _minutes(pakaraList[i].trainingTime);
    if (pMinutes == null) continue;
    final diff = (pMinutes - nkMinutes).abs();
    if (diff <= kTrainingMatchMinutes && diff < bestDiff) {
      best = i;
      bestDiff = diff;
    }
  }
  return best;
}

int? _matchByClock(NetkeibaTrainingSession nk,
    List<TrainingTimeModel> pakaraList, List<int> candidates) {
  const epsilon = 1e-6;
  final nkFurlongs = slotsToFurlongs(nk.courseRaw, nk.slots);
  final nkLast = nkFurlongs[1];
  if (nkLast == null) return null;
  int? best;
  double bestScore = double.infinity;
  for (final i in candidates) {
    final p = pakaraList[i];
    if (p.f1 == null) continue;
    final lastDiff = (p.f1! - nkLast).abs();
    if (lastDiff > kTrainingMatchLastFurlong + epsilon) continue;
    final pFurlongs = <int, double?>{6: p.f6, 5: p.f5, 4: p.f4, 3: p.f3};
    double? longDiff;
    for (final k in const [6, 5, 4, 3]) {
      final a = nkFurlongs[k];
      final b = pFurlongs[k];
      if (a != null && b != null) {
        longDiff = (a - b).abs();
        break;
      }
    }
    if (longDiff != null && longDiff > kTrainingMatchLongFurlong + epsilon) {
      continue;
    }
    final score = lastDiff + (longDiff ?? 0);
    if (score < bestScore) {
      best = i;
      bestScore = score;
    }
  }
  return best;
}
