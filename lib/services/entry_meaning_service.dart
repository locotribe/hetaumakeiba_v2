// lib/services/entry_meaning_service.dart

// [追加] 陣営の本気度指数 実施順6: 出走の意味を、DBの過去走・プロフィール・レース準備の記録から計算して保存する。
// レース結果があるレース（過去レース）では計算せず、保存分を読むだけにする（呼び出し側が使い分ける）。通信はしない (v.2026.10.3+26100307)

import 'package:hetaumakeiba_v2/db/repositories/entry_meaning_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_preparation_repository.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning_snapshot.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
// [追加] 基本情報整理と本賞金照合 Step3: 重賞の本賞金を出馬表キャッシュから引く (v.2026.10.15+26101506)
import 'package:hetaumakeiba_v2/db/repositories/shutuba_table_cache_repository.dart';
import 'package:hetaumakeiba_v2/logic/base_prize_lookup.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';

class EntryMeaningService {
  final HorseRepository _horseRepository;
  final RacePreparationRepository _preparationRepository;
  final EntryMeaningRepository _entryMeaningRepository;
  // [追加] 基本情報整理と本賞金照合 Step3: 重賞の本賞金を引く出馬表キャッシュ (v.2026.10.15+26101506)
  final ShutubaTableCacheRepository _shutubaTableCacheRepository;

  EntryMeaningService({
    HorseRepository? horseRepository,
    RacePreparationRepository? preparationRepository,
    EntryMeaningRepository? entryMeaningRepository,
    ShutubaTableCacheRepository? shutubaTableCacheRepository,
  })  : _horseRepository = horseRepository ?? HorseRepository(),
        _preparationRepository =
            preparationRepository ?? RacePreparationRepository(),
        _entryMeaningRepository =
            entryMeaningRepository ?? EntryMeaningRepository(),
        _shutubaTableCacheRepository =
            shutubaTableCacheRepository ?? ShutubaTableCacheRepository();

  /// 出走の意味を計算する。JRAの平地のレース（isSupported=true）だけ保存する（同じレースの保存は上書き）。
  ///
  /// [onMissingBasePrizes] 収得賞金で重賞の本賞金が要るのに、出馬表キャッシュに本賞金が無かったレース
  /// （レースID → レース名）。1件以上あるときだけ、計算の前に1回呼ぶ。
  // [修正] 基本情報整理と本賞金照合 Step3: 本賞金が無いレースを呼び出し側へ知らせる任意の引数を追加 (v.2026.10.15+26101506)
  Future<EntryMeaningSnapshot> computeAndSave(
    PredictionRaceData race, {
    void Function(Map<String, String> missingRaceNames)? onMissingBasePrizes,
  }) async {
    final recordsByHorseId = <String, List<HorseRaceRecord>>{};
    final profilesByHorseId = <String, HorseProfile>{};
    for (final horse in race.horses) {
      recordsByHorseId[horse.horseId] =
          await _horseRepository.getHorsePerformanceRecords(horse.horseId);
      final profile = await _horseRepository.getHorseProfile(horse.horseId);
      if (profile != null) {
        profilesByHorseId[horse.horseId] = profile;
      }
    }

    // [追加] 基本情報整理と本賞金照合 Step3: 重賞の1・2着のレースの本賞金を出馬表キャッシュから引く（本賞金が0より大きいものだけ）。
    // 引けなかったレースは onMissingBasePrizes で知らせ、計算は今までどおり賞金列から推定する (v.2026.10.15+26101506)
    final basePrizeManByRaceId = <String, List<int>>{};
    final asOf = classifyRace(race).date;
    if (asOf != null) {
      final targets = raceIdsNeedingBasePrize(
        recordsByHorseId: recordsByHorseId,
        asOf: asOf,
      );
      final missing = <String, String>{};
      for (final target in targets.entries) {
        List<int>? pair;
        try {
          final cache =
              await _shutubaTableCacheRepository.getShutubaTableCache(target.key);
          pair = cache == null ? null : basePrizePairOf(cache.predictionRaceData);
        } catch (_) {
          pair = null;
        }
        if (pair != null) {
          basePrizeManByRaceId[target.key] = pair;
        } else {
          missing[target.key] = target.value;
        }
      }
      if (missing.isNotEmpty) {
        onMissingBasePrizes?.call(missing);
      }
    }

    final meanings = buildEntryMeaningsForRace(
      race: race,
      recordsByHorseId: recordsByHorseId,
      profilesByHorseId: profilesByHorseId,
      basePrizeManByRaceId: basePrizeManByRaceId,
    );

    final statuses = await _preparationRepository.getForRace(race.raceId);
    final snapshot = EntryMeaningSnapshot(
      raceId: race.raceId,
      meanings: meanings,
      preparation: entryMeaningPreparationOf(
        shutubaStatus: statuses[PreparationStep.shutuba],
        horsePerformanceStatus: statuses[PreparationStep.horsePerformance],
      ),
      computedAt: DateTime.now(),
    );

    if (meanings.isSupported) {
      await _entryMeaningRepository.save(snapshot);
    }
    return snapshot;
  }

  /// 保存した出走の意味を読む。無ければ null。
  Future<EntryMeaningSnapshot?> loadSaved(String raceId) {
    return _entryMeaningRepository.getForRace(raceId);
  }
}
