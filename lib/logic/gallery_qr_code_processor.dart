// lib/logic/gallery_qr_code_processor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/ticket_processing_service.dart';

class GalleryQrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete;
  final GlobalKey<SavedTicketsListPageState> savedListKey;
  final TicketProcessingService _ticketProcessingService;

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
  })  : _dbHelper = dbHelper,
        _ticketProcessingService = TicketProcessingService(dbHelper: dbHelper);

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

  // ▼▼▼ Step 2でロジックを修正 ▼▼▼
  Future<void> _processCombinedQrCode(String qrCode) async {
    final newQrData = await _ticketProcessingService.processAndSaveTicket(qrCode, savedListKey);

    if (newQrData == null) {
      _setWarningStatus(true, '馬券の解析に失敗しました');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({
        'isNotTicket': true,
        'エラー': '解析失敗',
        '詳細': 'QRコードの解析中に不明なエラーが発生しました。'
      });
      return;
    }

    // UIは即座に更新
    onProcessingComplete(json.decode(newQrData.parsedDataJson));

    // バックグラウンド処理を開始（awaitしない）
    _ticketProcessingService.handleSettlement(newQrData).catchError((e) {
      print('ERROR: バックグラウンド処理(handleSettlement)でエラーが発生しました: $e');
    });
  }
}