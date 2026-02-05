// lib/services/ticket_processing_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/analytics_service.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
// ★追加: リポジトリのインポート
import 'package:hetaumakeiba_v2/repositories/race_data_repository.dart';

class TicketProcessingService {
  final DatabaseHelper _dbHelper;
  // ★追加: リポジトリのインスタンス
  final RaceDataRepository _repository = RaceDataRepository();

  TicketProcessingService({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  /// QRコードを解析してDBに保存し、解析結果を返す
  Future<Map<String, dynamic>> processAndSaveTicket(
      String userId,
      String combinedQrCode, GlobalKey<SavedTicketsListPageState> savedListKey) async {
    Map<String, dynamic> parsedData;
    try {
      parsedData = parseHorseracingTicketQr(combinedQrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          userId: userId,
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
          parsedDataJson: json.encode(parsedData),
        );

        // ★修正: リポジトリ経由で保存
        await _repository.saveQrData(qrDataToSave);

        savedListKey.currentState?.reloadData();
      } else {
        parsedData = {'エラー': '解析結果にQRデータが含まれていません。', '詳細': '不明な解析結果'};
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
    }
    return parsedData;
  }

  /// バックグラウンドでレース関連情報をスクレイピングする
  Future<void> triggerBackgroundScraping(
      String userId,
      Map<String, dynamic> parsedData, DatabaseHelper dbHelper) async {
    try {
      final String year = parsedData['年'].toString();
      final String racecourseCode = racecourseDict.entries
          .firstWhere((entry) => entry.value == parsedData['開催場'])
          .key;
      final String round = parsedData['回'].toString();
      final String day = parsedData['日'].toString();
      final String race = parsedData['レース'].toString();
      final String raceUrl = generateNetkeibaUrl(
          year: year,
          racecourseCode: racecourseCode,
          round: round,
          day: day,
          race: race);
      final String? raceId = RaceResultScraperService.getRaceIdFromUrl(raceUrl);

      if (raceId != null) {
        // ここでの既存チェックは「スクレイピングするかどうか」の判断用なのでDB直接参照でOK
        // ただし保存はRepositoryを使う
        final existingRaceResult = await dbHelper.getRaceResult(raceId);

        if (existingRaceResult == null) {
          // ★修正: スクレイピングサービス内ですでにRepository保存が行われるようになったため
          // ここでの戻り値は確認用だが、二重保存を防ぐために insertOrUpdateRaceResult の呼び出しは削除してよい
          // しかし、念のためサービスが保存することを前提に、ここでは呼び出しのみ行う
          final raceResult = await RaceResultScraperService.scrapeRaceDetails(raceUrl);
          // Note: RaceResultScraperService内で saveRaceResult が呼ばれているはず

          for (final horse in raceResult.horseResults) {
            final latestRecord =
            await dbHelper.getLatestHorsePerformanceRecord(horse.horseId);
            if (latestRecord == null || latestRecord.date != raceResult.raceDate) {
              try {
                final horseRecords =
                await HorsePerformanceScraperService.scrapeHorsePerformance(horse.horseId);
                for (final record in horseRecords) {
                  await dbHelper.insertOrUpdateHorsePerformance(record);
                }
                await Future.delayed(const Duration(milliseconds: 500));
              } catch (e) {
                print(
                    'ERROR: 競走馬ID ${horse.horseId} の成績スクレイピングまたは保存中にエラーが発生しました: $e');
              }
            } else {
              print('DEBUG: 競走馬ID ${horse.horseId} の最新成績は既に存在します。スキップします。');
            }
          }
        } else {
          // 既存のレース結果がある場合も、その出走馬の成績を同期する
          final featuredRacePlaceholder = FeaturedRace(
            raceId: existingRaceResult.raceId,
            raceName: existingRaceResult.raceTitle,
            raceGrade: existingRaceResult.raceGrade,
            raceDate: existingRaceResult.raceDate,
            venue: parsedData['開催場'], // 解析データから取得
            raceNumber: parsedData['レース'].toString(), // 解析データから取得
            shutubaTableUrl: raceUrl, // レース結果ページのURLで代替
            lastScraped: DateTime.now(),
            distance: '',
            conditions: '',
            weight: '',
            raceDetails1: existingRaceResult.raceInfo,
            raceDetails2: existingRaceResult.raceGrade,
          );
          await ScraperService.syncNewHorseData([featuredRacePlaceholder], dbHelper);
        }

        await AnalyticsService().updateAggregatesOnResultConfirmed(raceId, userId);
      }
    } catch (e) {
      print('ERROR: バックグラウンドスクレイピング処理全体でエラーが発生しました: $e');
    }
  }
}