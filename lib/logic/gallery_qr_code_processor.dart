// lib/logic/gallery_qr_code_processor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart'; // ★★★★★ 追加：競走馬成績モデルをインポート ★★★★★
import 'package:hetaumakeiba_v2/models/race_result_model.dart'; // ★★★★★ 追加：RaceResultモデルをインポート ★★★★★


class GalleryQrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  final MobileScannerController _scannerController = MobileScannerController();

  bool _isValidTicketQrSegment(String s) {
    return s.length == 95 && RegExp(r'^[0-9]+$').hasMatch(s);
  }

  bool _isBackPart(String segment) {
    if (segment.length < 5) return false;
    final lastFiveDigits = segment.substring(segment.length - 5);
    return RegExp(r'^60\d{3}$').hasMatch(lastFiveDigits);
  }

  GalleryQrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onWarningStatusChanged,
    required this.onProcessingComplete,
    required this.savedListKey,
  }) : _dbHelper = dbHelper;

  void _setWarningStatus(bool status, String? message) {
    onWarningStatusChanged(status, message);
  }

  Future<void> processImageQrCode(String imagePath) async {
    _setWarningStatus(false, null);

    BarcodeCapture? barcodeCapture;
    try {
      barcodeCapture = await _scannerController.analyzeImage(imagePath);
    } catch (e) {
      _setWarningStatus(true, '画像解析中にエラーが発生しました。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '画像解析エラー', '詳細': e.toString()});
      return;
    }

    if (barcodeCapture == null || barcodeCapture.barcodes.isEmpty) {
      _setWarningStatus(true, '画像からQRコードを検出できませんでした。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': 'QRコード未検出', '詳細': '画像にQRコードがありませんでした。'});
      return;
    }

    List<String> detectedValidTicketSegments = [];
    bool foundAnyInvalidFormatQr = false;

    for (var barcode in barcodeCapture.barcodes) {
      if (barcode.rawValue != null) {
        if (_isValidTicketQrSegment(barcode.rawValue!)) {
          detectedValidTicketSegments.add(barcode.rawValue!);
        } else {
          foundAnyInvalidFormatQr = true;
        }
      }
    }

    if (detectedValidTicketSegments.isEmpty) {
      _setWarningStatus(true, 'すでに登録されている馬券か馬券ではない画像です');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '馬券形式外', '詳細': '検出されたQRコードが馬券の形式ではありませんでした。'});
      return;
    }

    if (detectedValidTicketSegments.length == 1) {
      _setWarningStatus(true, '馬券のQRコードが一つしか検出されませんでした。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '断片不足', '詳細': '馬券は2つのQRコードで構成されます。'});
      return;
    } else if (detectedValidTicketSegments.length == 2) {
      String qr1 = detectedValidTicketSegments[0];
      String qr2 = detectedValidTicketSegments[1];

      if (qr1 == qr2) {
        _setWarningStatus(true, '同じQRコードが複数検出されました。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '同一QRコード', '詳細': '画像に同じQRコードが複数検出されました。'});
        return;
      }

      String combinedQrCode;
      String frontPart;
      String backPart;

      bool isQr1Back = _isBackPart(qr1);
      bool isQr2Back = _isBackPart(qr2);

      if (isQr1Back && !isQr2Back) {
        frontPart = qr2;
        backPart = qr1;
      } else if (!isQr1Back && isQr2Back) {
        frontPart = qr1;
        backPart = qr2;
      } else {
        _setWarningStatus(true, isQr1Back ? '両方のQRコードが馬券の後半部分のようです。' : '両方のQRコードが馬券の前半部分のようです。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': isQr1Back ? '両方後半' : '両方前半', '詳細': '不正な組み合わせです。'});
        return;
      }

      combinedQrCode = frontPart + backPart;
      final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
      if (existsCombined) {
        _setWarningStatus(true, 'この馬券はすでに読み込みました');
        await Future.delayed(const Duration(seconds: 2));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '重複馬券', '詳細': 'この馬券はすでにデータベースに存在します。'});
        return;
      }

      if (foundAnyInvalidFormatQr) {
        _setWarningStatus(true, '画像に馬券以外のQRコードが混在しています。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '混在QRコード', '詳細': '馬券以外のQRコードも検出されました。'});
        return;
      }

      await _processCombinedQrCode(combinedQrCode);

    } else {
      _setWarningStatus(true, '一枚の馬券だけスキャンしてください。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '複数馬券', '詳細': '画像に複数の馬券が検出されました。'});
      return;
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

        // ▼▼▼ 関数名を loadData から reloadData に変更 ▼▼▼
        savedListKey.currentState?.reloadData();

        RaceResult? raceResult; // レース結果を保持する変数
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
              raceResult = await ScraperService.scrapeRaceDetails(raceUrl); // スクレイピング結果を代入
              await _dbHelper.insertOrUpdateRaceResult(raceResult!);
            } else {
              raceResult = existingRaceResult; // 既存の結果があればそれを使用
            }

            // ★★★★★ ここから追加：競走馬成績のスクレイピングと保存 ★★★★★
            if (raceResult != null) {
              for (final horse in raceResult.horseResults) {
                // 同じhorseIdとdateのデータが既に存在するかチェック
                final latestRecord = await _dbHelper.getLatestHorsePerformanceRecord(horse.horseId);
                // 最新のデータがまだ存在しない、または日付が異なる場合にのみスクレイピング
                if (latestRecord == null || latestRecord.date != raceResult.raceDate) {
                  try {
                    final horseRecords = await ScraperService.scrapeHorsePerformance(horse.horseId);
                    for (final record in horseRecords) {
                      await _dbHelper.insertOrUpdateHorsePerformance(record);
                    }
                    // 過度なリクエストを防ぐため、各馬のスクレイピング後に短い遅延を入れる
                    await Future.delayed(const Duration(milliseconds: 500));
                  } catch (e) {
                    print('ERROR: 競走馬ID ${horse.horseId} の成績スクレイピングまたは保存中にエラーが発生しました: $e');
                  }
                } else {
                  print('DEBUG: 競走馬ID ${horse.horseId} の最新成績は既に存在します。スキップします。');
                }
              }
            }
            // ★★★★★ ここまで追加 ★★★★★

          }
        } catch (e) {
          print('ERROR: Gallery: レースデータのスクレイピングまたは保存中にエラーが発生しました: $e');
        }
      } else {
        parsedData = {'エラー': '解析結果にQRデータが含まれていません。', '詳細': '不明な解析結果'};
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      _setWarningStatus(true, '馬券の解析に失敗しました');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '解析失敗', '詳細': e.toString()});
      return;
    }

    onProcessingComplete(parsedData);
  }
}
