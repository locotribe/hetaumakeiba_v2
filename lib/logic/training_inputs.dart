// lib/logic/training_inputs.dart

// [追加] 出走の意味 調教の行 Step4: DB から読んだ調教・近況を、出走の意味に渡す入力（HorseTrainingInput）と、計算し直しの判定に使う指紋にまとめる。
// DB・通信は使わない（読んだものを渡されて組み立てるだけ） (v.2026.10.24+26102404)

import 'package:hetaumakeiba_v2/logic/entry_meaning.dart';
import 'package:hetaumakeiba_v2/logic/training_record.dart';
import 'package:hetaumakeiba_v2/models/horse_condition_post_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

/// 調教のステップが終わっていない（調教の行を出さない）ときの指紋。
/// 保存した指紋がこれのままなら、調教が済んだ時点で計算し直しになる。
const String kTrainingNotReadyFingerprint = 'none';

/// 馬ごとの入力と、レース全体の指紋。
class TrainingInputs {
  /// 馬ID → 1頭分の入力
  final Map<String, HorseTrainingInput> byHorseId;

  /// 指紋。馬IDの順に「`trainingFingerprintOf` の文字列:遡り済み(1/0):最終追切の評価」を `|` でつないだもの
  final String fingerprint;

  const TrainingInputs({required this.byHorseId, required this.fingerprint});
}

/// 調教・近況の入力と指紋を作る。
///
/// - [horseIds] 出走馬の馬ID（取消を含む）
/// - [raceDay] 開催日。指紋はこの日より前の分だけを数える
/// - [pakaraByHorseId]・[sessionsByHorseId]・[postsByHorseId] 馬ID → DB にある全部（期間外を含んでよい）
/// - [finalRankByHorseId] 馬ID → このレースの最終追切の評価（A〜E）。無ければ省く
/// - [backfillCompleteHorseIds] pakara を前走の日まで取り終えた印のある馬
///
/// 遡り済みかどうかと最終追切の評価も指紋に入れる（印が付いただけ・評価が付いただけで、取れた行が増えなかったときも表示を直すため）。
TrainingInputs buildTrainingInputs({
  required List<String> horseIds,
  required DateTime raceDay,
  Map<String, List<TrainingTimeModel>> pakaraByHorseId = const {},
  Map<String, List<NetkeibaTrainingSession>> sessionsByHorseId = const {},
  Map<String, List<HorseConditionPost>> postsByHorseId = const {},
  Map<String, String?> finalRankByHorseId = const {},
  Set<String> backfillCompleteHorseIds = const {},
}) {
  final byHorseId = <String, HorseTrainingInput>{};
  final fingerprints = <String, String>{};
  for (final horseId in horseIds) {
    final pakara = pakaraByHorseId[horseId] ?? const <TrainingTimeModel>[];
    final sessions =
        sessionsByHorseId[horseId] ?? const <NetkeibaTrainingSession>[];
    final posts = postsByHorseId[horseId] ?? const <HorseConditionPost>[];
    final complete = backfillCompleteHorseIds.contains(horseId);
    byHorseId[horseId] = HorseTrainingInput(
      pakara: pakara,
      netkeibaSessions: sessions,
      finalOikiriRank: finalRankByHorseId[horseId],
      posts: posts,
      backfillComplete: complete,
    );
    final base = trainingFingerprintOf(
      horseId: horseId,
      raceDate: raceDay,
      pakara: pakara,
      netkeibaSessions: sessions,
      posts: posts,
    );
    fingerprints[horseId] =
        '$base:${complete ? 1 : 0}:${finalRankByHorseId[horseId] ?? ''}';
  }
  final ordered = fingerprints.keys.toList()..sort();
  return TrainingInputs(
    byHorseId: byHorseId,
    fingerprint: ordered.map((id) => fingerprints[id]!).join('|'),
  );
}
