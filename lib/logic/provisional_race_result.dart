// lib/logic/provisional_race_result.dart

// [追加] 陣営の本気度指数 実施順4: 保存済みのレース結果が「速報ページから保存したもの」かを判定する純粋関数。
// 出馬表準備の「過去のレース結果」ステップで、速報版をdb版に取り直す対象を決めるのに使う。
// DB・通信には触れない (v.2026.10.2+26100208)

import 'package:hetaumakeiba_v2/models/race_result_model.dart';

/// レースIDの5〜6桁目（競馬場コード）が JRA の 01〜10 か。
bool isJraRaceId(String raceId) {
  final id = raceId.trim();
  if (id.length < 6) return false;
  final place = int.tryParse(id.substring(4, 6));
  if (place == null) return false;
  return place >= 1 && place <= 10;
}

/// 保存済みのレース結果が、速報ページから保存したもの（db版に取り直すべきもの）か。
///
/// JRA のレースで、次のどちらかなら true。
/// - 開催日が空
/// - 出走馬がいて、全頭の賞金が空
///
/// 地方・海外のレースは db版でも賞金が空のことがあるため、常に false。
bool isProvisionalJraRaceResult(RaceResult result) {
  if (!isJraRaceId(result.raceId)) return false;
  if (result.raceDate.trim().isEmpty) return true;
  if (result.horseResults.isEmpty) return false;
  return result.horseResults.every((h) => h.prizeMoney.trim().isEmpty);
}
