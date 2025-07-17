// lib/logic/qr_code_processor.dart

import 'package:flutter/material.dart'; // Navigatorのために必要
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート

class QrCodeProcessor {
  final DatabaseHelper _dbHelper;
  // コールバックの型を変更: bool (ステータス) と String? (メッセージ) を渡す
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(Map<String, dynamic> parsedData) onProcessingComplete; // 処理完了後の画面遷移を要求するコールバック
  final GlobalKey<SavedTicketsListPageState> savedListKey; // SavedTicketsListPageの更新用

  final List<String> _qrResults = []; // 検出されたQRコード断片の一時保存用

  bool _isShowingDuplicateMessageInternal = false;

  QrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onWarningStatusChanged, // コンストラクタの引数名を変更
    required this.onProcessingComplete,
    required this.savedListKey,
  }) : _dbHelper = dbHelper;

  // 警告メッセージ表示状態を更新し、コールバック経由で外部に伝える
  // メソッド名も変更
  void _setWarningStatus(bool status, String? message) {
    if (_isShowingDuplicateMessageInternal != status) {
      _isShowingDuplicateMessageInternal = status;
      onWarningStatusChanged(status, message); // メッセージも渡す
    }
  }

  // QRコードの断片内の数字列の長さを数える
  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  // QRコードの文字列が95桁の純粋な数字列であるかを確認するヘルパー関数
  bool _isValidTicketQrSegment(String s) {
    return s.length == 95 && RegExp(r'^[0-9]+$').hasMatch(s);
  }

  // QRコード検出時のメイン処理
  Future<void> processQrCodeDetection(String? rawValue) async {
    if (rawValue == null || rawValue.isEmpty || _isShowingDuplicateMessageInternal) {
      print('DEBUG: processQrCodeDetection: Invalid rawValue or duplicate message active. rawValue: $rawValue, _isShowingDuplicateMessageInternal: $_isShowingDuplicateMessageInternal');
      return;
    }

    // #1: QRコードの内容が馬券の断片として有効か事前チェック
    if (!_isValidTicketQrSegment(rawValue)) {
      print('DEBUG: Not a valid ticket QR segment: $rawValue');
      _setWarningStatus(true, 'これは馬券ではありません'); // 警告メッセージを指定
      _qrResults.clear(); // 無効なQRコードを検出した場合はクリア
      await Future.delayed(const Duration(seconds: 3)); // 警告表示時間
      _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
      return;
    }

    // rawValue単体での重複チェック
    final bool existsSingle = await _dbHelper.qrCodeExists(rawValue);
    if (existsSingle) {
      print('DEBUG: Duplicate single QR code detected (rawValue): $rawValue');
      _setWarningStatus(true, 'この馬券はすでに読み込みました'); // 警告メッセージを指定
      await Future.delayed(const Duration(seconds: 2));
      _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
      return; // 重複したQRコードはこれ以上処理しない
    }

    _qrResults.add(rawValue);
    print('DEBUG: Added rawValue to _qrResults. Current length: ${_qrResults.length}');

    // #2: 3つ以上のQRコード断片が検出された場合の処理
    if (_qrResults.length > 2) {
      print('DEBUG: More than 2 valid QR codes detected. Clearing results.');
      _setWarningStatus(true, '一枚の馬券だけスキャンしてください'); // 警告メッセージを指定
      _qrResults.clear(); // すべての検出された断片をクリア
      await Future.delayed(const Duration(seconds: 3)); // 警告表示時間
      _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
      return;
    }

    // 2つのQRコードの断片が揃った場合のみ処理
    if (_qrResults.length == 2) {
      String firstPart = _qrResults[0];
      String secondPart = _qrResults[1];

      int count1 = _countSequence(firstPart);
      int count2 = _countSequence(secondPart);
      print('DEBUG: Two QR parts detected. count1: $count1, count2: $count2');

      // 閾値の設定（実際のデータに基づいて調整してください）
      // 後半部分の0-9数列が複数回繰り返される場合の閾値
      const int thresholdForBothBackHalves = 5; // 例: 5回以上なら後半部分の可能性が高い
      // 前半部分の0-9数列の最大出現回数を考慮した閾値
      const int thresholdForBothFrontHalves = 4; // 例: 4回以下なら前半部分の可能性が高い

      // #3: 両方の断片が「後半部分」である可能性が高い場合の判定
      if (count1 >= thresholdForBothBackHalves && count2 >= thresholdForBothBackHalves) {
        print('DEBUG: Both detected QR parts appear to be back halves. Aborting combined processing.');
        _setWarningStatus(true, '両方のQRコードが馬券の後半部分のようです。'); // 警告メッセージを指定
        _qrResults.clear(); // 検出された断片をクリア
        await Future.delayed(const Duration(seconds: 3)); // 警告表示時間
        _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
        return;
      }

      // #4: 両方の断片が「前半部分」である可能性が高い場合の判定
      if (count1 <= thresholdForBothFrontHalves && count2 <= thresholdForBothFrontHalves) {
        print('DEBUG: Both detected QR parts appear to be front halves. Aborting combined processing.');
        _setWarningStatus(true, '両方のQRコードが馬券の前半部分のようです。'); // 警告メッセージを指定
        _qrResults.clear(); // 検出された断片をクリア
        await Future.delayed(const Duration(seconds: 3)); // 警告表示時間
        _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
        return;
      }

      // データベースに保存されている形式に合わせてQRコードを結合
      // 前提条件「0から9の数列が多い方を後半に結合」に基づき、少ない方を前半、多い方を後半とする
      String combinedQrCode;
      if (count1 > count2) {
        // firstPartの方が0-9数列が多い（＝後半）ので、secondPart + firstPart
        combinedQrCode = secondPart + firstPart;
        print('DEBUG: Combined as secondPart + firstPart. count1: $count1 (firstPart), count2: $count2 (secondPart)');
      } else {
        // secondPartの方が0-9数列が多いか同数（＝後半）なので、firstPart + secondPart
        combinedQrCode = firstPart + secondPart;
        print('DEBUG: Combined as firstPart + secondPart. count1: $count1 (firstPart), count2: $count2 (secondPart)');
      }

      print('DEBUG: Combined QR string for duplicate check: $combinedQrCode');

      final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
      if (existsCombined) {
        print('DEBUG: Duplicate QR code detected (combined): $combinedQrCode');
        _setWarningStatus(true, 'この馬券はすでに読み込みました'); // 警告メッセージを指定
        _qrResults.clear(); // 検出された断片をクリア
        await Future.delayed(const Duration(seconds: 2));
        _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
        return; // 重複したQRコードはこれ以上処理しない
      } else {
        // 重複ではない場合、通常通り処理と保存に進む
        await _processCombinedQrCode(combinedQrCode);
        _qrResults.clear(); // 処理後、検出された断片をクリア
      }
    }
    // _qrResults.length が 1 の場合は、次のQRコードを待つため何もしない
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
        print('馬券が保存されました: ${qrDataToSave.qrCode}'); // 既存のプリント文

        savedListKey.currentState?.loadData(); // 保存済みリストをリロード
      } else {
        // parseHorseracingTicketQr がQRキーを返さないがエラーもない場合
        parsedData = {'エラー': '解析結果にQRデータが含まれていません。', '詳細': '不明な解析結果'};
        print('DEBUG: Parsing completed but no QR data found in parsedData: $parsedData');
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      print('DEBUG: Error during QR code parsing: $e');
    }

    onProcessingComplete(parsedData); // 処理完了をコールバックで通知 (これは結果画面への遷移用なので維持)
  }
}
