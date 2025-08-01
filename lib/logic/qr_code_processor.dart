// lib/logic/qr_code_processor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/ticket_processing_service.dart';

class QrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(bool) onScannerControl;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete;
  final GlobalKey<SavedTicketsListPageState> savedListKey;
  final TicketProcessingService _ticketProcessingService;

  final List<String> _qrResults = [];

  bool _isShowingDuplicateMessageInternal = false;

  QrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onWarningStatusChanged,
    required this.onScannerControl,
    required this.onProcessingComplete,
    required this.savedListKey,
  })  : _dbHelper = dbHelper,
        _ticketProcessingService = TicketProcessingService(dbHelper: dbHelper);

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

  // ▼▼▼ Step 2でロジックを修正 ▼▼▼
  Future<void> _processCombinedQrCode(String qrCode) async {
    final newQrData = await _ticketProcessingService.processAndSaveTicket(qrCode, savedListKey);

    if (newQrData == null) {
      _setWarningStatus(true, '馬券の解析に失敗しました');
      _qrResults.clear();
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true);
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