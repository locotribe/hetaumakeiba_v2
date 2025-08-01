// lib/services/ticket_processing_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class TicketProcessingService {
  final DatabaseHelper _dbHelper;

  TicketProcessingService({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  // ▼▼▼ Step 2でロジックを修正 ▼▼▼
  /// QRコードを解析し、初期データとしてDBに保存する
  Future<QrData?> processAndSaveTicket(
      String combinedQrCode, GlobalKey<SavedTicketsListPageState> savedListKey) async {
    try {
      final parsedData = parseHorseracingTicketQr(combinedQrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
          parsedDataJson: json.encode(parsedData),
          status: 'processing', // ステータスを「処理中」に設定
          isHit: null,
          payout: null,
          hitDetails: null,
        );

        final newId = await _dbHelper.insertQrData(qrDataToSave);
        savedListKey.currentState?.reloadData();

        // 保存されたデータをID付きで返す
        return QrData.fromMap((await _dbHelper.getQrData(newId))!.toMap());
      }
    } catch (e) {
      print('Error in processAndSaveTicket: $e');
    }
    return null;
  }

  // ▼▼▼ Step 2で新規追加 ▼▼▼
  /// バックグラウンドでレース結果の取得と当たり判定を行う
  Future<void> handleSettlement(QrData qrData) async {
    try {
      final parsedTicket = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = ScraperService.getRaceIdFromUrl(url)!;

      // 1. DBからレース結果を取得試行
      RaceResult? raceResult = await _dbHelper.getRaceResult(raceId);

      // 2. DBになければスクレイピング
      if (raceResult == null) {
        raceResult = await ScraperService.scrapeRaceDetails(url);
        if (!raceResult.isIncomplete) {
          await _dbHelper.insertOrUpdateRaceResult(raceResult);
        }
      }

      // 3. レース結果に基づいてステータスを更新
      if (raceResult != null && !raceResult.isIncomplete) {
        final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
        final updatedQrData = QrData(
          id: qrData.id,
          qrCode: qrData.qrCode,
          timestamp: qrData.timestamp,
          parsedDataJson: qrData.parsedDataJson,
          status: 'settled',
          isHit: hitResult.isHit,
          payout: hitResult.totalPayout,
          hitDetails: json.encode(hitResult.hitDetails),
        );
        await _dbHelper.updateQrData(updatedQrData);
      } else {
        // レース結果がない、または不完全な場合
        final updatedQrData = QrData(
          id: qrData.id,
          qrCode: qrData.qrCode,
          timestamp: qrData.timestamp,
          parsedDataJson: qrData.parsedDataJson,
          status: 'unsettled',
          isHit: null,
          payout: null,
          hitDetails: null,
        );
        await _dbHelper.updateQrData(updatedQrData);
      }
    } catch (e) {
      print('Error in handleSettlement for qrData.id ${qrData.id}: $e');
      // エラーが発生した場合もステータスを更新して無限ループを防ぐ
      final updatedQrData = QrData(
        id: qrData.id,
        qrCode: qrData.qrCode,
        timestamp: qrData.timestamp,
        parsedDataJson: qrData.parsedDataJson,
        status: 'unsettled', // エラー時は未確定として扱う
      );
      await _dbHelper.updateQrData(updatedQrData);
    }
  }


/// (triggerBackgroundScrapingはhandleSettlementに統合されたため削除)
}