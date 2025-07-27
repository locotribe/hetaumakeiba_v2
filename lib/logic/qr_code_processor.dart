// lib/logic/qr_code_processor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart'; // .h から .dart に修正
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart'; // スクレイピングサービスをインポート
import 'package:hetaumakeiba_v2/utils/url_generator.dart'; // URL生成サービスをインポート


class QrCodeProcessor {
  final DatabaseHelper _dbHelper;
  final Function(bool status, String? message) onWarningStatusChanged;
  final Function(bool) onScannerControl; // スキャナーの制御用コールバック (true: start, false: stop)
  final Function(Map<String, dynamic> parsedData) onProcessingComplete; // 処理完了後の画面遷移を要求するコールバック
  final GlobalKey<SavedTicketsListPageState> savedListKey; // SavedTicketsListPageの更新用

  final List<String> _qrResults = []; // 検出されたQRコード断片の一時保存用

  bool _isShowingDuplicateMessageInternal = false;

  QrCodeProcessor({
    required DatabaseHelper dbHelper,
    required this.onWarningStatusChanged,
    required this.onScannerControl,
    required this.onProcessingComplete,
    required this.savedListKey,
  }) : _dbHelper = dbHelper;

  // 警告メッセージ表示状態を更新し、コールバック経由で外部に伝える
  void _setWarningStatus(bool status, String? message) {
    if (_isShowingDuplicateMessageInternal != status) {
      _isShowingDuplicateMessageInternal = status;
      onWarningStatusChanged(status, message); // メッセージも渡す
    }
  }

  // QRコードの断片内の数字列の長さを数える (デバッグ用および isValidTicketQrSegment で間接的に使用)
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
    if (segment.length < 5) return false; // 5桁未満なら後半部分ではない
    final lastFiveDigits = segment.substring(segment.length - 5);
    // JRAの仕様が変わらない限り今のところ60ｘｘｘとなっている
    return RegExp(r'^60\d{3}$').hasMatch(lastFiveDigits);
  }

  // QRコード検出時のメイン処理
  Future<void> processQrCodeDetection(String? rawValue) async {
    // 警告表示中または処理中の場合は、新たな検出を無視
    if (rawValue == null || rawValue.isEmpty || _isShowingDuplicateMessageInternal) {
      print('DEBUG: processQrCodeDetection: Invalid rawValue or duplicate message active. rawValue: $rawValue, _isShowingDuplicateMessageInternal: $_isShowingDuplicateMessageInternal');
      return;
    }

    // rawValue単体での重複チェック (これは常に最初に行う)
    final bool existsSingle = await _dbHelper.qrCodeExists(rawValue);
    if (existsSingle) {
      onScannerControl(false); // 警告表示前にスキャナー停止
      print('DEBUG: Scanner stopped for single duplicate warning: $rawValue');
      print('DEBUG: Duplicate single QR code detected (rawValue): $rawValue');
      _setWarningStatus(true, 'この馬券はすでに読み込みました'); // 警告メッセージを指定
      await Future.delayed(const Duration(seconds: 2));
      _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
      onScannerControl(true); // スキャナーを再開
      print('DEBUG: Scanner resumed after single duplicate warning.');
      return; // 重複したQRコードはこれ以上処理しない
    }

    // #1: QRコードの内容が馬券の断片として有効か事前チェック (数字以外や桁数不正)
    if (!_isValidTicketQrSegment(rawValue)) {
      onScannerControl(false); // 警告表示前にスキャナー停止
      print('DEBUG: Scanner stopped for invalid QR segment warning: $rawValue');
      print('DEBUG: Not a valid ticket QR segment: $rawValue');
      _setWarningStatus(true, 'これは馬券ではありません'); // 警告メッセージを指定
      _qrResults.clear(); // 無効なQRコードを検出した場合はクリア
      await Future.delayed(const Duration(seconds: 3)); // 警告表示時間
      _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
      onScannerControl(true); // スキャナーを再開
      print('DEBUG: Scanner resumed after invalid QR segment warning.');
      return;
    }

    // 新しいロジック: 既に1つ目のQRコードが検出されているかチェックし、異なるQRコードを探す
    if (_qrResults.isNotEmpty) {
      // 既に1つ目のQRコードがロックされている場合
      if (_qrResults[0] == rawValue) {
        // 検出されたQRコードが既にロックされているものと同じ場合、何もしない（スキップ）
        print('DEBUG: Detected same QR code again: $rawValue. Skipping.');
        return;
      }
      // 異なるQRコードが検出されたので、リストに追加
      _qrResults.add(rawValue);
      print('DEBUG: Added different rawValue to _qrResults. Current length: ${_qrResults.length}');
    } else {
      // 最初のQRコードをロック
      _qrResults.add(rawValue);
      print('DEBUG: First rawValue locked. Current length: ${_qrResults.length}');
      // 最初のQRコードが検出されただけなので、スキャナーは停止せず、次のQRコードを待つ
      return; // ここで処理を終了し、2つ目のQRコードの検出を待つ
    }

    // #2: 3つ以上のQRコード断片が検出された場合の処理
    // このロジックは、上記で既に2つ追加された後に、さらに別のQRコードが検出された場合を想定
    if (_qrResults.length > 2) {
      onScannerControl(false); // 警告表示前にスキャナー停止
      print('DEBUG: Scanner stopped for multiple QR warning.');
      print('DEBUG: More than 2 valid QR codes detected. Clearing results.');
      _setWarningStatus(true, '一枚の馬券だけスキャンしてください'); // 警告メッセージを指定
      _qrResults.clear(); // すべての検出された断片をクリア
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true); // スキャナーを再開
      print('DEBUG: Scanner resumed after multiple QR warning.');
      return;
    }

    // ここに到達するのは _qrResults.length == 2 の場合のみ
    // 2つの異なるQRコードの断片が揃った場合のみ処理
    if (_qrResults.length == 2) {
      // 2つのQRコードが揃ったので、ここでスキャナーを停止
      onScannerControl(false);
      print('DEBUG: Scanner stopped as two QR parts are detected and processing begins.');

      String qr1 = _qrResults[0];
      String qr2 = _qrResults[1];

      // 新しい前後判定ロジック: 60XXXパターンを優先
      bool isQr1Back = _isBackPart(qr1);
      bool isQr2Back = _isBackPart(qr2);

      String combinedQrCode;
      String frontPart;
      String backPart;

      if (isQr1Back && !isQr2Back) { // QR1が後半、QR2が前半
        frontPart = qr2;
        backPart = qr1;
        print('DEBUG: Determined QR2 is front, QR1 is back based on 60XXX pattern.');
      } else if (!isQr1Back && isQr2Back) { // QR2が後半、QR1が前半
        frontPart = qr1;
        backPart = qr2;
        print('DEBUG: Determined QR1 is front, QR2 is back based on 60XXX pattern.');
      } else if (isQr1Back && isQr2Back) { // 両方とも後半部分
        onScannerControl(false);
        print('DEBUG: Scanner stopped for both back halves warning.');
        _setWarningStatus(true, '両方のQRコードが馬券の後半部分のようです。');
        _qrResults.clear();
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onScannerControl(true);
        print('DEBUG: Scanner resumed after both back halves warning.');
        return;
      } else { // どちらも後半部分ではない（両方前半部分、または不正な組み合わせ）
        onScannerControl(false);
        print('DEBUG: Scanner stopped for both front halves warning.');
        _setWarningStatus(true, '両方のQRコードが馬券の前半部分のようです。');
        _qrResults.clear();
        await Future.delayed(const Duration(seconds: 3));
        _setWarningStatus(false, null);
        onScannerControl(true);
        print('DEBUG: Scanner resumed after both front halves warning.');
        return;
      }

      combinedQrCode = frontPart + backPart;
      print('DEBUG: Combined QR string for duplicate check: $combinedQrCode');

      final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
      if (existsCombined) {
        print('DEBUG: Duplicate QR code detected (combined): $combinedQrCode');
        _setWarningStatus(true, 'この馬券はすでに読み込みました'); // 警告メッセージを指定
        _qrResults.clear(); // 検出された断片をクリア
        await Future.delayed(const Duration(seconds: 2));
        _setWarningStatus(false, null); // 警告解除時はメッセージをnullに
        onScannerControl(true); // スキャナーを再開
        print('DEBUG: Scanner resumed after combined duplicate warning.');
        return; // 重複したQRコードはこれ以上処理しない
      }

      // 正常処理
      await _processCombinedQrCode(combinedQrCode);
      _qrResults.clear(); // 処理後、検出された断片をクリア
      // ここではスキャナーを再開しない。onProcessingCompleteが呼ばれて画面遷移するから
      print('DEBUG: Combined QR code processed. Navigating to ResultPage.');
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
          parsedDataJson: json.encode(parsedData),
        );
        print('DEBUG: 馬券が保存されました: ${qrDataToSave.qrCode}');
        await _dbHelper.insertQrData(qrDataToSave);
        print('馬券が保存されました: ${qrDataToSave.qrCode}'); // 既存のプリント文

        savedListKey.currentState?.loadData(); // 保存済みリストをリロード

        // ★★★ ここから追加：レースデータをスクレイピングしてDBに保存する処理 ★★★
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
            race: race,
          );
          final String? raceId = ScraperService.getRaceIdFromUrl(raceUrl);

          if (raceId != null) {
            final existingRaceResult = await _dbHelper.getRaceResult(raceId);
            if (existingRaceResult == null) {
              print('DEBUG: レースデータがDBに存在しないため、スクレイピングを開始します: $raceUrl');
              final raceResult = await ScraperService.scrapeRaceDetails(raceUrl);
              await _dbHelper.insertOrUpdateRaceResult(raceResult);
              print('DEBUG: レースデータをスクレイピングしてDBに保存しました: ${raceResult.raceId}');
            } else {
              print('DEBUG: レースデータは既にDBに存在します: ${existingRaceResult.raceId}');
            }
          } else {
            print('DEBUG: レースIDが生成できませんでした。スクレイピングをスキップします。');
          }
        } catch (e) {
          print('ERROR: レースデータのスクレイピングまたは保存中にエラーが発生しました: $e');
          // ここでエラーが発生しても、馬券データは保存されているため、処理を続行
        }
        // ★★★ ここまで追加 ★★★

      } else {
        // parseHorseracingTicketQr がQRキーを返さないがエラーもない場合
        parsedData = {'エラー': '解析結果にQRデータが含まれていません。', '詳細': '不明な解析結果'};
        print('DEBUG: Parsing completed but no QR data found in parsedData: $parsedData');
      }
    } catch (e) {
      // 解析に失敗した場合も警告を表示し、スキャナーを再開する
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      print('DEBUG: Error during QR code parsing: $e');
      _setWarningStatus(true, '馬券の解析に失敗しました'); // 解析失敗警告
      _qrResults.clear(); // リストをクリア
      await Future.delayed(const Duration(seconds: 3));
      _setWarningStatus(false, null);
      onScannerControl(true); // スキャナーを再開
      print('DEBUG: Scanner resumed after parsing error warning.');
      return; // 画面遷移せずに処理を終了
    }

    // 処理完了をコールバックで通知。このコールバック内でスキャナー停止と画面遷移が行われる
    onProcessingComplete(parsedData);
  }
}
