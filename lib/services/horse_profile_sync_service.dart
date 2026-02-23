// lib/services/horse_profile_sync_service.dart

import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/services/horse_profile_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';

class HorseProfileSyncService {
  final HorseRepository _horseRepository;
  final ScrapingManager _scrapingManager;

  HorseProfileSyncService({
    HorseRepository? horseRepository,
    ScrapingManager? scrapingManager,
  })  : _horseRepository = horseRepository ?? HorseRepository(),
        _scrapingManager = scrapingManager ?? ScrapingManager();

  /// 出走馬リストを受け取り、プロフィールがない馬のデータをバックグラウンドで取得する
  Future<void> syncMissingHorseProfiles(
      List<PredictionHorseDetail> horses,
      Function(String horseId) onProfileUpdated,
      ) async {
    print('DEBUG: syncMissingHorseProfiles started for ${horses.length} horses via Manager.');

    for (final horse in horses) {
      final existingProfile = await _horseRepository.getHorseProfile(horse.horseId);

      if (existingProfile == null || existingProfile.ownerName.isEmpty) {
        _scrapingManager.addRequest(
            'プロフィール取得: ${horse.horseName}',
                () async {
              print('DEBUG: Executing queued profile fetch for: ${horse.horseName} (${horse.horseId})');
              final newProfile = await HorseProfileScraperService.scrapeAndSaveProfile(horse.horseId);

              if (newProfile != null) {
                print('DEBUG: Profile synced for ${horse.horseId}, calling callback.');
                onProfileUpdated(horse.horseId);
              } else {
                print('DEBUG: Failed to sync profile for ${horse.horseId}');
              }
            }
        );
      }
    }
  }
}