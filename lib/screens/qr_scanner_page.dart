// lib/screens/qr_scanner_page.dart

import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'dart:ui' as ui; // CustomPainterでRect.fromLTWHを正確に使うために必要

// 新しく作成したカスタム背景ウィジェットをインポート
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final List<String> _qrResults = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  // MobileScannerController を State に持たせる
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  @override
  void dispose() {
    _scannerController.dispose(); // Controllerのdisposeを忘れずに
    super.dispose();
  }

  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;
      if (_qrResults.contains(rawValue)) continue;

      setState(() {
        _qrResults.add(rawValue);
      });

      if (_qrResults.length == 2) {
        _processTwoQRs(_qrResults[0], _qrResults[1]);
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
        await _dbHelper.insertQrData(qrDataToSave);
        print('QRコードデータが保存されました: ${qrDataToSave.qrCode}');
      }
    } catch (_) {
      try {
        parsedData = parseHorseracingTicketQr(alt);
        if (parsedData['QR'] != null) {
          final qrDataToSave = QrData(
            qrCode: parsedData['QR'] as String,
            timestamp: DateTime.now(),
          );
          await _dbHelper.insertQrData(qrDataToSave);
          print('QRコードデータが保存されました: ${qrDataToSave.qrCode}');
        }
      } catch (e) {
        parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      }
    }

    Navigator.of(context).pop(parsedData);
  }

  @override
  Widget build(BuildContext context) {
    // Scaffoldの背景色設定はCustomBackgroundウィジェット内で行うため、ここでは削除します。
    return Scaffold(
      // backgroundColor: const Color.fromRGBO(231, 234, 234, 1.0), // この行を削除しました
      appBar: AppBar(
        title: const Text('QRコードスキャナー'),
        backgroundColor: Colors.transparent, // AppBarの背景を透明に
        elevation: 0, // 影をなくす
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          // カメラ領域の高さ (画面全体の約70%)
          final cameraHeight = screenHeight * 0.7; // (16:9を意識しつつ全体の70%の高さに)
          // カメラ領域の幅 (アスペクト比16:9を保つ)
          final cameraWidth = cameraHeight * (16 / 9);

          // カメラ領域が画面幅より広い場合は、画面幅に合わせる
          final actualCameraWidth = (cameraWidth > screenWidth) ? screenWidth : cameraWidth;
          final actualCameraHeight = actualCameraWidth * (9 / 16); // 16:9

          // カメラ領域の上部オフセット (画面の上から30%)
          final cameraTopOffset = screenHeight * 0.3;

          // スキャンエリアのサイズ (カメラ領域の幅の約80%を使用)
          final scanAreaSize = actualCameraWidth * 0.8;

          return Stack(
            children: [
              // --- 背景のストライプと特定領域の塗りつぶし ---
              Positioned.fill(
                // BackgroundPainterをCustomBackgroundウィジェットに置き換え
                child: CustomBackground(
                  overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0), // 全体の背景色
                  stripeColor: const Color.fromRGBO(219, 234, 234, 0.6), // R:219 G:234 B:234, 60%半透明
                  fillColor: const Color.fromRGBO(172, 234, 231, 1.0), // R:172 G:234 B:231
                ),
              ),

              // --- カメラプレビュー (16:9で上から30%に配置) ---
              Positioned(
                top: cameraTopOffset,
                left: (screenWidth - actualCameraWidth) / 2, // 中央揃え
                width: actualCameraWidth,
                height: actualCameraHeight,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRect( // カメラプレビューがはみ出さないようにクリップ
                    child: MobileScanner(
                      controller: _scannerController, // Stateのcontrollerを使用
                      onDetect: _onDetect,
                    ),
                  ),
                ),
              ),

              // --- 中央の半透明角丸四角、テキスト ---
              // カメラ領域の上に重ねるために、Positionedでカメラと同じ位置に配置
              Positioned(
                top: cameraTopOffset,
                left: (screenWidth - actualCameraWidth) / 2,
                width: actualCameraWidth,
                height: actualCameraHeight,
                child: Center(
                  child: SizedBox( // ContainerをSizedBoxに変更してサイズを固定
                    width: scanAreaSize,
                    height: scanAreaSize,
                    child: Stack(
                      children: [
                        // 半透明30%の角丸四角
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.3), // White with 30% opacity
                            borderRadius: BorderRadius.circular(16.0), // 角丸
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
              // --- 下部の読み取り状況表示は削除済み ---
            ],
          );
        },
      ),
    );
  }
}

// --- BackgroundPainterクラスはlib/widgets/custom_background.dartに移動したため、ここから削除しました ---