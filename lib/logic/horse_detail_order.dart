// lib/logic/horse_detail_order.dart

import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの馬の並び順（馬番順で固定。馬番0＝枠順確定前の馬は後ろに馬名順） (v.2026.9.23+26092308)

/// 馬詳細タブに並べる順番の新しいリストを返す（元のリストは変更しない）。
List<PredictionHorseDetail> orderHorsesForDetail(
    List<PredictionHorseDetail> horses) {
  final ordered = List<PredictionHorseDetail>.from(horses);
  ordered.sort((a, b) {
    final aHasNumber = a.horseNumber > 0;
    final bHasNumber = b.horseNumber > 0;
    if (aHasNumber && bHasNumber) {
      final byNumber = a.horseNumber.compareTo(b.horseNumber);
      if (byNumber != 0) return byNumber;
      return a.horseName.compareTo(b.horseName);
    }
    if (aHasNumber) return -1;
    if (bHasNumber) return 1;
    return a.horseName.compareTo(b.horseName);
  });
  return ordered;
}
