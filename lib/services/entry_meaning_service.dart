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

class EntryMeaningService {
  final HorseRepository _horseRepository;
  final RacePreparationRepository _preparationRepository;
  final EntryMeaningRepository _entryMeaningRepository;

  EntryMeaningService({
    HorseRepository? horseRepository,
    RacePreparationRepository? preparationRepository,
    EntryMeaningRepository? entryMeaningRepository,
  })  : _horseRepository = horseRepository ?? HorseRepository(),
        _preparationRepository =
            preparationRepository ?? RacePreparationRepository(),
        _entryMeaningRepository =
            entryMeaningRepository ?? EntryMeaningRepository();

  /// 出走の意味を計算する。JRAの平地のレース（isSupported=true）だけ保存する（同じレースの保存は上書き）。
  Future<EntryMeaningSnapshot> computeAndSave(PredictionRaceData race) async {
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

    final meanings = buildEntryMeaningsForRace(
      race: race,
      recordsByHorseId: recordsByHorseId,
      profilesByHorseId: profilesByHorseId,
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
