// lib/screens/qr_scanner_page.dart

import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'dart:ui' as ui;

// CustomBackgroundウィジェットをインポート
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final List<String> _qrResults = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _isShowingDuplicateMessage = false; // 重複メッセージ表示状態

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isShowingDuplicateMessage) {
      // メッセージ表示中は新たな検出を無視
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;
      if (_qrResults.contains(rawValue)) continue;

      // DEBUG: rawValue を出力
      print('DEBUG: rawValue from scanner: $rawValue');

      // _qrResults に追加する前に重複チェックを行う (rawValue単体でのチェック)
      final bool existsSingle = await _dbHelper.qrCodeExists(rawValue); // rawValue単体でのチェック
      if (existsSingle) {
        print('DEBUG: Duplicate single QR code detected (rawValue): $rawValue');
        setState(() {
          _isShowingDuplicateMessage = true;
        });
        _scannerController.stop();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isShowingDuplicateMessage = false;
            });
            _scannerController.start();
          }
        });
        return; // 重複したQRコードはこれ以上処理しない
      }

      setState(() {
        _qrResults.add(rawValue);
      });

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

        // DEBUG: 重複チェックに使用する結合済みQRコードを出力
        print('DEBUG: Combined QR string for duplicate check: $combinedQrCode');

        final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode); // 結合済み文字列でチェック
        if (existsCombined) {
          // 重複が見つかった場合
          print('DEBUG: Duplicate QR code detected (combined): $combinedQrCode');
          setState(() {
            _isShowingDuplicateMessage = true;
            _qrResults.clear(); // 検出された断片をクリアして、次のスキャンに備える
          });
          _scannerController.stop(); // スキャナーを一時停止

          // 2秒後にメッセージを消してスキャナーを再開
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isShowingDuplicateMessage = false;
              });
              _scannerController.start(); // スキャナーを再開
            }
          });
          return; // 重複したQRコードはこれ以上処理しない
        } else {
          // 重複ではない場合、通常通り処理と保存に進む
          _scannerController.stop(); // スキャナーを完全に停止して結果ページへ
          _processTwoQRs(_qrResults[0], _qrResults[1]); // 元の断片を渡して解析・保存
          _qrResults.clear(); // 処理後、検出された断片をクリア
          return; // 処理を終える
        }
      }
    }
  }

  void _processTwoQRs(String first, String second) async {
    Map<String, dynamic> parsedData;
    String preferred, alt;
    int count1 = _countSequence(first), count2 = _countSequence(second);

    if (count1 > count2) {
      preferred = second + first;
      alt = first + second;
    } else {
      preferred = first + second;
      alt = second + first;
    }

    try {
      parsedData = parseHorseracingTicketQr(preferred);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
        );
        // DEBUG: 保存されるQRコードを出力
        print('DEBUG: 馬券データが保存されました: ${qrDataToSave.qrCode}');
        await _dbHelper.insertQrData(qrDataToSave);
        print('馬券データが保存されました: ${qrDataToSave.qrCode}');
      }
    } catch (_) {
      try {
        parsedData = parseHorseracingTicketQr(alt);
        if (parsedData['QR'] != null) {
          final qrDataToSave = QrData(
            qrCode: parsedData['QR'] as String,
            timestamp: DateTime.now(),
          );
          // DEBUG: 保存されるQRコードを出力
          print('DEBUG: 馬券データが保存されました (alt): ${qrDataToSave.qrCode}');
          await _dbHelper.insertQrData(qrDataToSave);
          print('馬券データが保存されました: ${qrDataToSave.qrCode}');
        }
      } catch (e) {
        parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      }
    }

    // 解析結果をResultPageに渡すためにポップ
    Navigator.of(context).pop(parsedData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('馬券スキャナー'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          final cameraHeight = screenHeight * 0.7;
          final cameraWidth = cameraHeight * (16 / 9);

          final actualCameraWidth = (cameraWidth > screenWidth) ? screenWidth : cameraWidth;
          final actualCameraHeight = actualCameraWidth * (9 / 16);

          final cameraTopOffset = screenHeight * 0.3;

          final scanAreaSize = actualCameraWidth * 0.8;

          return Stack(
            children: [
              // 背景のストライプと特定領域の塗りつぶし
              Positioned.fill(
                child: CustomBackground(
                  overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
                  stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
                  fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
                ),
              ),

              // カメラプレビュー (16:9で上から30%に配置)
              Positioned(
                top: cameraTopOffset,
                left: (screenWidth - actualCameraWidth) / 2,
                width: actualCameraWidth,
                height: actualCameraHeight,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRect(
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
              ),

              // 中央の半透明角丸四角、テキスト
              Positioned(
                top: cameraTopOffset,
                left: (screenWidth - actualCameraWidth) / 2,
                width: actualCameraWidth,
                height: actualCameraHeight,
                child: Center(
                  child: SizedBox(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    child: Stack(
                      children: [
                        // 半透明30%の角丸四角
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.3),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        // 中央のテキスト
                        const Center(
                          child: Text(
                            '馬券を読み込んでください',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 重複メッセージ表示UI
              if (_isShowingDuplicateMessage)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: const Text(
                          'この馬券はすでに読み込みました',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
