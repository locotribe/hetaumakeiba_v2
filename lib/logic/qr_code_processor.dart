// lib/logic/qr_code_processor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart'; // FeaturedRaceモデルをインポート


class QrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(bool) onScannerControl;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  final List<String> _qrResults = [];

  bool _isShowingDuplicateMessageInternal = false;

  QrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onWarningStatusChanged,
    required this.onScannerControl,
    required this.onProcessingComplete,
    required this.savedListKey,
  }) : _dbHelper = dbHelper;

  void _setWarningStatus(bool status, String? message) {
    if (_isShowingDuplicateMessageInternal != status) {
      _isShowingDuplicateMessageInternal = status;
      onWarningStatusChanged(status, message);
    }
  }

  bool _isValidTicketQrSegment(String s) {
    return s.length == 95 && RegExp(r'^[0-9]+$').hasMatch(s);
  }

  bool _isBackPart(String segment) {
    if (segment.length < 5) return false;
    final lastFiveDigits = segment.substring(segment.length - 5);
    return RegExp(r'^60\d{3}$').hasMatch(lastFiveDigits);
  }

  Future<void> processQrCodeDetection(String? rawValue) async {
    if (rawValue == null || rawValue.isEmpty || _isShowingDuplicateMessageInternal) {
      return;
    }

    final bool existsSingle = await _dbHelper.qrCodeExists(rawValue);
    if (existsSingle) {
      onScannerControl(false);
      _setWarningStatus(true, 'この馬券はすでに読み込みました');
      await Future.delayed(const Duration(seconds: 2));
      _setWarningStatus(false, null);
      onScannerControl(true);
      return;
    }

    if (!_isValidTicketQrSegment(rawValue)) {
      onScannerControl(false);
      _setWarningStatus(true, 'これは馬券ではありません');
      _qrResults.clear();
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true);
      return;
    }

    if (_qrResults.isNotEmpty) {
      if (_qrResults[0] == rawValue) {
        return;
      }
      _qrResults.add(rawValue);
    } else {
      _qrResults.add(rawValue);
      return;
    }

    if (_qrResults.length > 2) {
      onScannerControl(false);
      _setWarningStatus(true, '一枚の馬券だけスキャンしてください');
      _qrResults.clear();
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true);
      return;
    }

    if (_qrResults.length == 2) {
      onScannerControl(false);
      String qr1 = _qrResults[0];
      String qr2 = _qrResults[1];
      bool isQr1Back = _isBackPart(qr1);
      bool isQr2Back = _isBackPart(qr2);
      String combinedQrCode;
      String frontPart;
      String backPart;

      if (isQr1Back && !isQr2Back) {
        frontPart = qr2;
        backPart = qr1;
      } else if (!isQr1Back && isQr2Back) {
        frontPart = qr1;
        backPart = qr2;
      } else {
        _setWarningStatus(true, isQr1Back ? '両方のQRコードが馬券の後半部分のようです。' : '両方のQRコードが馬券の前半部分のようです。');
        _qrResults.clear();
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onScannerControl(true);
        return;
      }

      combinedQrCode = frontPart + backPart;
      final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
      if (existsCombined) {
        _setWarningStatus(true, 'この馬券はすでに読み込みました');
        _qrResults.clear();
        await Future.delayed(const Duration(seconds: 2));
        _setWarningStatus(false, null);
        onScannerControl(true);
        return;
      }

      await _processCombinedQrCode(combinedQrCode);
      _qrResults.clear();
    }
  }

  Future<void> _processCombinedQrCode(String qrCode) async {
    Map<String, dynamic> parsedData;
    try {
      parsedData = parseHorseracingTicketQr(qrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
          parsedDataJson: json.encode(parsedData),
        );
        await _dbHelper.insertQrData(qrDataToSave);

        savedListKey.currentState?.reloadData();

        // スクレイピング処理を非同期で開始し、awaitしない
        _performBackgroundScraping(parsedData).catchError((e) {
          print('ERROR: バックグラウンドスクレイピング中にエラーが発生しました: $e');
        });

      } else {
        parsedData = {'エラー': '解析結果にQRデータが含まれていません。', '詳細': '不明な解析結果'};
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      _setWarningStatus(true, '馬券の解析に失敗しました');
      _qrResults.clear();
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true);
      return;
    }
    // スクレイピングが終わるのを待たずに、すぐにUIを更新
    onProcessingComplete(parsedData);
  }

  // スクレイピングとデータベース保存のロジックを非同期で実行する新しいプライベートメソッド
  Future<void> _performBackgroundScraping(Map<String, dynamic> parsedData) async {
    try {
      final String year = parsedData['年'].toString();
      final String racecourseCode = racecourseDict.entries.firstWhere((entry) => entry.value == parsedData['開催場']).key;
      final String round = parsedData['回'].toString();
      final String day = parsedData['日'].toString();
      final String race = parsedData['レース'].toString();
      final String raceUrl = generateNetkeibaUrl(year: year, racecourseCode: racecourseCode, round: round, day: day, race: race);
      final String? raceId = ScraperService.getRaceIdFromUrl(raceUrl);

      if (raceId != null) {
        final existingRaceResult = await _dbHelper.getRaceResult(raceId);
        if (existingRaceResult == null) {
          final raceResult = await ScraperService.scrapeRaceDetails(raceUrl);
          await _dbHelper.insertOrUpdateRaceResult(raceResult);

          for (final horse in raceResult.horseResults) {
            final latestRecord = await _dbHelper.getLatestHorsePerformanceRecord(horse.horseId);
            if (latestRecord == null || latestRecord.date != raceResult.raceDate) {
              try {
                final horseRecords = await ScraperService.scrapeHorsePerformance(horse.horseId);
                for (final record in horseRecords) {
                  await _dbHelper.insertOrUpdateHorsePerformance(record);
                }
                await Future.delayed(const Duration(milliseconds: 500));
              } catch (e) {
                print('ERROR: 競走馬ID ${horse.horseId} の成績スクレイピングまたは保存中にエラーが発生しました: $e');
              }
            } else {
              print('DEBUG: 競走馬ID ${horse.horseId} の最新成績は既に存在します。スキップします。');
            }
          }
                } else {
          // 既存のレース結果がある場合も、その出走馬の成績を同期する
          // home_pageから呼ばれるsyncNewHorseDataと同様のロジック
          // ただし、特定のレースの馬のみを同期するように調整
          final featuredRacePlaceholder = FeaturedRace(
            raceId: existingRaceResult.raceId,
            raceName: existingRaceResult.raceTitle,
            raceGrade: existingRaceResult.raceGrade,
            raceDate: existingRaceResult.raceDate,
            venue: parsedData['開催場'], // 解析データから取得
            raceNumber: parsedData['レース'].toString(), // 解析データから取得
            shutubaTableUrl: raceUrl, // レース結果ページのURLで代替
            lastScraped: DateTime.now(),
            distance: '', conditions: '', weight: '', // これらの情報はexistingRaceResultから取得することも可能
            raceDetails1: existingRaceResult.raceInfo,
            raceDetails2: existingRaceResult.raceGrade,
          );
          await ScraperService.syncNewHorseData([featuredRacePlaceholder], _dbHelper);
        }
      }
    } catch (e) {
      print('ERROR: バックグラウンドスクレイピング処理全体でエラーが発生しました: $e');
    }
  }
}