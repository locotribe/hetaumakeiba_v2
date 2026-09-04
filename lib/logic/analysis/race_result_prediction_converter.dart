// lib/logic/analysis/race_result_prediction_converter.dart

// [追加] フェーズ6 バックテスト・ハーネス: race_page.dartの
// _createPredictionDataFromRaceResult を共有ユーティリティへ抽出（挙動は不変）。
// バックテストハーネスも過去レース(RaceResult)からPredictionRaceDataを
// 再構築する際に同一ロジックを使う (v.2026.9.4)

import 'dart:io';

import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/logic/race_info_parser.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:path_provider/path_provider.dart';

/// 過去レースの確定結果(RaceResult)を、展開シミュ等で使うPredictionRaceData形式へ
/// 変換する共有ロジック。race_page.dart / スピード指数バックテストハーネスの双方から使う。
class RaceResultPredictionConverter {
  /// [raceResult] を PredictionRaceData + horses へ変換する。
  /// オーナー画像パスの解決に [horseRepo] を使う（race_page.dartと同一の解決順）。
  static Future<PredictionRaceData> convert(
    RaceResult raceResult,
    HorseRepository horseRepo,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final currentOwnerImagesDir = '${dir.path}/owner_images';

    final horses = await Future.wait(raceResult.horseResults.map((hr) async {
      final weightMatch = RegExp(r'(\d+)\((.*?)\)').firstMatch(hr.horseWeight);
      final trainerName = hr.trainerName;
      final trainerAffiliation = hr.trainerAffiliation;

      final profile = await horseRepo.getHorseProfile(hr.horseId);
      String ownerImagePath = '';

      if (profile != null && profile.ownerImageLocalPath.isNotEmpty) {
        final savedPath = profile.ownerImageLocalPath;

        final fileName = savedPath.split('/').last;
        final currentFilePath = '$currentOwnerImagesDir/$fileName';

        if (await File(currentFilePath).exists()) {
          ownerImagePath = currentFilePath;
        } else if (await File(savedPath).exists()) {
          ownerImagePath = savedPath;
        }
      }

      return PredictionHorseDetail(
        horseId: hr.horseId,
        horseNumber: int.tryParse(hr.horseNumber) ?? 0,
        gateNumber: int.tryParse(hr.frameNumber) ?? 0,
        horseName: hr.horseName,
        sexAndAge: hr.sexAndAge,
        jockey: hr.jockeyName,
        jockeyId: hr.jockeyId,
        carriedWeight: double.tryParse(hr.weightCarried) ?? 0.0,
        trainerName: trainerName,
        trainerAffiliation: trainerAffiliation,
        odds: double.tryParse(hr.odds),
        popularity: int.tryParse(hr.popularity),
        horseWeight: weightMatch?.group(1),
        isScratched: int.tryParse(hr.rank) == null,
        ownerImageLocalPath: ownerImagePath,
      );
    }).toList());

    final raceNumber = raceResult.raceId.length >= 2
        ? int.tryParse(raceResult.raceId.substring(raceResult.raceId.length - 2))?.toString() ?? ''
        : '';

    String venueName = '';
    if (raceResult.raceId.length >= 12) {
      final placeCode = raceResult.raceId.substring(4, 6);
      venueName = racecourseDict[placeCode] ?? '';
    }

    if (venueName.isEmpty) {
      venueName = racecourseDict.entries.firstWhere(
              (e) => raceResult.raceInfo.contains(e.value),
          orElse: () => const MapEntry("", "")
      ).value;
    }

    final courseInfo = RaceInfoParser.parse(raceResult.raceInfo);

    return PredictionRaceData(
      raceId: raceResult.raceId,
      raceName: raceResult.raceTitle,
      raceDate: raceResult.raceDate,
      venue: venueName,
      raceNumber: raceNumber,
      shutubaTableUrl: 'https://db.netkeiba.com/race/${raceResult.raceId}',
      raceGrade: raceResult.raceGrade,
      raceDetails1: raceResult.raceInfo,
      horses: horses,
      trackType: courseInfo.trackType,
      distanceValue: courseInfo.distanceValue,
      direction: courseInfo.direction,
      courseInOut: courseInfo.courseInOut,
    );
  }
}
