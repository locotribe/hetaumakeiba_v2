// lib/logic/qr_code_processor.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/ticket_processing_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(bool) onScannerControl;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete;
  final GlobalKey<SavedTicketsListPageState> savedListKey;
  final TicketProcessingService _ticketProcessingService; // ★ 新しいサービスを追加

  final List<String> _qrResults = [];

  bool _isShowingDuplicateMessageInternal = false;

  QrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onWarningStatusChanged,
    required this.onScannerControl,
    required this.onProcessingComplete,
    required this.savedListKey,
  })  : _dbHelper = dbHelper,
  // ★ コンストラクタでサービスを初期化
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

  // ▼▼▼ ★★★ ここからが修正箇所 ★★★ ▼▼▼
  /// 解析、DB保存、スクレイピング実行のロジックをTicketProcessingServiceに委譲
  Future<void> _processCombinedQrCode(String qrCode) async {
    // ★★★ ここからが修正箇所 ★★★
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _setWarningStatus(true, 'ユーザー情報の取得に失敗しました。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true);
      return;
    }

    // サービスを呼び出してQRコードの処理と保存を行う
    final parsedData = await _ticketProcessingService.processAndSaveTicket(userId, qrCode, savedListKey);
    // ★★★ ここまでが修正箇所 ★★★

    // サービスからの戻り値をチェック
    if (parsedData.containsKey('エラー')) {
      // エラーがあった場合、UIに警告を表示して処理を中断
      _setWarningStatus(true, '馬券の解析に失敗しました');
      _qrResults.clear(); // このクリアは念のため
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true);
      return;
    }

    // 成功した場合、UIを更新し、バックグラウンド処理を開始
    onProcessingComplete(parsedData);

    // スクレイピングはawaitせずに実行（Fire-and-forget）
    // ★★★ ここからが修正箇所 ★★★
    _ticketProcessingService.triggerBackgroundScraping(userId, parsedData, _dbHelper).catchError((e) {
      // ★★★ ここまでが修正箇所 ★★★
      // バックグラウンド処理のエラーはコンソールに出力するのみ
      print('ERROR: バックグラウンドスクレイピング中にエラーが発生しました: $e');
    });
  }
// ▲▲▲ ★★★ ここまでが修正箇所 ★★★ ▲▲▲

// _performBackgroundScraping メソッドは削除されました
}