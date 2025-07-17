// lib/logic/gallery_qr_code_processor.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // analyzeImageのために必要
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // savedListKeyのために必要

class GalleryQrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  // MobileScannerController は analyzeImage のために必要だが、カメラ制御は行わない
  final MobileScannerController _scannerController = MobileScannerController();

  // QRコードの断片内の数字列の長さを数える
  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  // QRコードの文字列が95桁の純粋な数字列であるかを確認するヘルパー関数
  bool _isValidTicketQrSegment(String s) {
    return s.length == 95 && RegExp(r'^[0-9]+$').hasMatch(s);
  }

  // QRコードの断片が後半部分であるか（末尾5桁が60XXXパターンか）を判定するヘルパー関数
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

  // 警告メッセージ表示状態を更新し、コールバック経由で外部に伝える
  void _setWarningStatus(bool status, String? message) {
    onWarningStatusChanged(status, message);
  }

  // ギャラリー画像からのQRコード検出と処理のメインメソッド
  Future<void> processImageQrCode(String imagePath) async {
    _setWarningStatus(false, null); // 処理開始前に既存の警告をクリア

    BarcodeCapture? barcodeCapture;
    try {
      barcodeCapture = await _scannerController.analyzeImage(imagePath);
    } catch (e) {
      print('ERROR: analyzeImage failed: $e');
      _setWarningStatus(true, '画像解析中にエラーが発生しました。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      // ResultPageに遷移させる場合は、ここでonProcessingCompleteを呼ぶ
      onProcessingComplete({'isNotTicket': true, 'エラー': '画像解析エラー', '詳細': e.toString()});
      return;
    }

    if (barcodeCapture == null || barcodeCapture.barcodes.isEmpty) {
      // シナリオA: QRコードが全く検出されなかった場合
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
      // シナリオB: QRコードは検出されたが、有効な馬券形式のものが一つもなかった場合
      _setWarningStatus(true, 'すでに登録されている馬券か馬券ではない画像です');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '馬券形式外', '詳細': '検出されたQRコードが馬券の形式ではありませんでした。'});
      return;
    }

    // シナリオC: 有効な馬券形式のQRコードが検出された場合
    if (detectedValidTicketSegments.length == 1) {
      // サブシナリオC1: 有効な馬券断片が1つ
      _setWarningStatus(true, '馬券のQRコードが一つしか検出されませんでした。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '断片不足', '詳細': '馬券は2つのQRコードで構成されます。'});
      return;
    } else if (detectedValidTicketSegments.length == 2) {
      // サブシナリオC2: 有効な馬券断片が2つ
      String qr1 = detectedValidTicketSegments[0];
      String qr2 = detectedValidTicketSegments[1];

      // 異なるQRコードであることの確認（analyzeImageは重複を返す可能性が低いが念のため）
      if (qr1 == qr2) {
        _setWarningStatus(true, '同じQRコードが複数検出されました。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '同一QRコード', '詳細': '画像に同じQRコードが複数検出されました。'});
        return;
      }

      // 結合処理と重複チェック
      String combinedQrCode;
      String frontPart;
      String backPart;

      bool isQr1Back = _isBackPart(qr1);
      bool isQr2Back = _isBackPart(qr2);

      if (isQr1Back && !isQr2Back) { // QR1が後半、QR2が前半
        frontPart = qr2;
        backPart = qr1;
        print('DEBUG: Gallery: Determined QR2 is front, QR1 is back based on 60XXX pattern.');
      } else if (!isQr1Back && isQr2Back) { // QR2が後半、QR1が前半
        frontPart = qr1;
        backPart = qr2;
        print('DEBUG: Gallery: Determined QR1 is front, QR2 is back based on 60XXX pattern.');
      } else if (isQr1Back && isQr2Back) { // 両方とも後半部分
        _setWarningStatus(true, '両方のQRコードが馬券の後半部分のようです。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '両方後半', '詳細': '画像に両方後半のQRコードが検出されました。'});
        return;
      } else { // どちらも後半部分ではない（両方前半部分、または不正な組み合わせ）
        _setWarningStatus(true, '両方のQRコードが馬券の前半部分のようです。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '両方前半', '詳細': '画像に両方前半のQRコードが検出されました。'});
        return;
      }

      combinedQrCode = frontPart + backPart;
      print('DEBUG: Gallery: Combined QR string for duplicate check: $combinedQrCode');

      final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
      if (existsCombined) {
        _setWarningStatus(true, 'この馬券はすでに読み込みました');
        await Future.delayed(const Duration(seconds: 2));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '重複馬券', '詳細': 'この馬券はすでにデータベースに存在します。'});
        return;
      }

      // 有効な馬券と無効なQRコードが混在している場合も警告
      if (foundAnyInvalidFormatQr) {
        _setWarningStatus(true, '画像に馬券以外のQRコードが混在しています。');
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onProcessingComplete({'isNotTicket': true, 'エラー': '混在QRコード', '詳細': '馬券以外のQRコードも検出されました。'});
        return;
      }

      // 正常処理
      await _processCombinedQrCode(combinedQrCode);
      // _qrResults.clear() はこのクラスでは不要（毎回新しい画像なので）
      print('DEBUG: Gallery: Combined QR code processed. Navigating to ResultPage.');

    } else { // detectedValidTicketSegments.length > 2
      // サブシナリオC3: 有効な馬券断片が3つ以上
      _setWarningStatus(true, '一枚の馬券だけスキャンしてください。');
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '複数馬券', '詳細': '画像に複数の馬券が検出されました。'});
      return;
    }
  }

  // 結合されたQRコードの解析と保存、画面遷移
  Future<void> _processCombinedQrCode(String qrCode) async {
    Map<String, dynamic> parsedData;

    try {
      parsedData = parseHorseracingTicketQr(qrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
        );
        print('DEBUG: Gallery: 馬券が保存されました: ${qrDataToSave.qrCode}');
        await _dbHelper.insertQrData(qrDataToSave);
        savedListKey.currentState?.loadData(); // 保存済みリストをリロード
      } else {
        parsedData = {'エラー': '解析結果にQRデータが含まれていません。', '詳細': '不明な解析結果'};
        print('DEBUG: Gallery: Parsing completed but no QR data found in parsedData: $parsedData');
      }
    } catch (e) {
      // 解析に失敗した場合も警告を表示し、ResultPageに遷移させる
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      print('DEBUG: Gallery: Error during QR code parsing: $e');
      _setWarningStatus(true, '馬券の解析に失敗しました'); // 解析失敗警告
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onProcessingComplete({'isNotTicket': true, 'エラー': '解析失敗', '詳細': e.toString()});
      return; // 画面遷移せずに処理を終了
    }

    onProcessingComplete(parsedData); // 処理完了をコールバックで通知
  }
}
