// lib/services/ticket_processing_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class TicketProcessingService {
  final DatabaseHelper _dbHelper;

  TicketProcessingService({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  /// QRコードを解析してDBに保存し、解析結果を返す
  Future<Map<String, dynamic>> processAndSaveTicket(
      String combinedQrCode, GlobalKey<SavedTicketsListPageState> savedListKey) async {
    Map<String, dynamic> parsedData;
    try {
      parsedData = parseHorseracingTicketQr(combinedQrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
          parsedDataJson: json.encode(parsedData),
        );
        await _dbHelper.insertQrData(qrDataToSave);

        // キャッシュ無効化ロジック
        final now = DateTime.now();
        final currentYear = now.year;
        final currentMonth = now.month;

        final url = generateNetkeibaUrl(
          year: parsedData['年'].toString(),
          racecourseCode: racecourseDict.entries
              .firstWhere((entry) => entry.value == parsedData['開催場'])
              .key,
          round: parsedData['回'].toString(),
          day: parsedData['日'].toString(),
          race: parsedData['レース'].toString(),
        );
        final raceId = ScraperService.getRaceIdFromUrl(url);

        if (raceId != null) {
          final raceResult = await _dbHelper.getRaceResult(raceId);
          if (raceResult != null) {
            try {
              final dateParts = raceResult.raceDate.split(RegExp(r'[年月日]'));
              final year = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);

              if (year < currentYear || (year == currentYear && month < currentMonth)) {
                final period = "$year-${month.toString().padLeft(2, '0')}";
                await _dbHelper.deleteSummary(period);
                print('DEBUG: Cache invalidated for period $period due to new ticket addition.');
              }
            } catch (e) {
              print('Error during cache invalidation logic: $e');
            }
          }
        }

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
      final String? raceId = ScraperService.getRaceIdFromUrl(raceUrl);

      if (raceId != null) {
        final existingRaceResult = await dbHelper.getRaceResult(raceId);
        if (existingRaceResult == null) {
          final raceResult = await ScraperService.scrapeRaceDetails(raceUrl);
          await dbHelper.insertOrUpdateRaceResult(raceResult);

          for (final horse in raceResult.horseResults) {
            final latestRecord =
            await dbHelper.getLatestHorsePerformanceRecord(horse.horseId);
            if (latestRecord == null || latestRecord.date != raceResult.raceDate) {
              try {
                final horseRecords =
                await ScraperService.scrapeHorsePerformance(horse.horseId);
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
            weight: '', // これらの情報はexistingRaceResultから取得することも可能
            raceDetails1: existingRaceResult.raceInfo,
            raceDetails2: existingRaceResult.raceGrade,
          );
          await ScraperService.syncNewHorseData([featuredRacePlaceholder], dbHelper);
        }
      }
    } catch (e) {
      print('ERROR: バックグラウンドスクレイピング処理全体でエラーが発生しました: $e');
    }
  }
}