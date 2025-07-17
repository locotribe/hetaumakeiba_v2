// lib/logic/qr_code_processor.dart

import 'package:flutter/material.dart'; // Navigatorのために必要
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート

class QrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool) onDuplicateStatusChanged; // 重複メッセージ表示の状態を外部に伝えるコールバック
  final Function(Map<String, dynamic> parsedData) onProcessingComplete; // 処理完了後の画面遷移を要求するコールバック
  final GlobalKey<SavedTicketsListPageState> savedListKey; // SavedTicketsListPageの更新用

  final List<String> _qrResults = []; // 検出されたQRコード断片の一時保存用

  bool _isShowingDuplicateMessageInternal = false;

  QrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onDuplicateStatusChanged,
    required this.onProcessingComplete,
    required this.savedListKey,
  }) : _dbHelper = dbHelper;

  // 重複メッセージ表示状態を更新し、コールバック経由で外部に伝える
  void _setDuplicateMessageStatus(bool status) {
    if (_isShowingDuplicateMessageInternal != status) {
      _isShowingDuplicateMessageInternal = status;
      onDuplicateStatusChanged(status);
    }
  }

  // QRコードの断片内の数字列の長さを数える
  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  // QRコード検出時のメイン処理
  Future<void> processQrCodeDetection(String? rawValue) async {
    if (rawValue == null || rawValue.isEmpty || _isShowingDuplicateMessageInternal) {
      return;
    }

    // rawValue単体での重複チェック
    final bool existsSingle = await _dbHelper.qrCodeExists(rawValue);
    if (existsSingle) {
      print('DEBUG: Duplicate single QR code detected (rawValue): $rawValue');
      _setDuplicateMessageStatus(true);
      await Future.delayed(const Duration(seconds: 2));
      _setDuplicateMessageStatus(false);
      return; // 重複したQRコードはこれ以上処理しない
    }

    _qrResults.add(rawValue);

    // 2つのQRコードの断片が揃った場合のみ処理
    if (_qrResults.length == 2) {
      String firstPart = _qrResults[0];
      String secondPart = _qrResults[1];

      // データベースに保存されている形式に合わせてQRコードを結合
      String combinedQrCode;
      int count1 = _countSequence(firstPart);
      int count2 = _countSequence(secondPart);

      if (count1 > count2) {
        combinedQrCode = secondPart + firstPart;
      } else {
        combinedQrCode = firstPart + secondPart;
      }

      print('DEBUG: Combined QR string for duplicate check: $combinedQrCode');

      final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
      if (existsCombined) {
        print('DEBUG: Duplicate QR code detected (combined): $combinedQrCode');
        _setDuplicateMessageStatus(true);
        _qrResults.clear(); // 検出された断片をクリア
        await Future.delayed(const Duration(seconds: 2));
        _setDuplicateMessageStatus(false);
        return; // 重複したQRコードはこれ以上処理しない
      } else {
        // 重複ではない場合、通常通り処理と保存に進む
        await _processCombinedQrCode(combinedQrCode);
        _qrResults.clear(); // 処理後、検出された断片をクリア
      }
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
        print('DEBUG: 馬券が保存されました: ${qrDataToSave.qrCode}');
        await _dbHelper.insertQrData(qrDataToSave);
        print('馬券が保存されました: ${qrDataToSave.qrCode}');

        savedListKey.currentState?.loadData(); // 保存済みリストをリロード
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
    }

    onProcessingComplete(parsedData); // 処理完了をコールバックで通知
  }
}