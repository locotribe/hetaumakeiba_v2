// lib/screens/qr_scanner_page.dart

import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'dart:ui' as ui; // CustomPainterでRect.fromLTWHを正確に使うために必要

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
    // Scaffoldの背景色を設定
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F3), // 全体の背景色
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
                child: CustomPaint(
                  painter: BackgroundPainter(
                    stripeColor: const Color(0x99CBEAD8), // 半透明60%のストライプ (0x99 = 0.6の透過度)
                    fillColor: const Color(0xFFADEBE6), // 左から20%-30%の領域を塗る色
                  ),
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

              // --- 中央の半透明角丸四角、テキスト (白いラインは削除) ---
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
                            color: Colors.white.withOpacity(0.3),
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

              // --- 下部の読み取り状況表示 ---
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: Colors.black.withOpacity(0.6), // 以前のまま
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${_qrResults.length} / 2 個のQRコードを読み取りました',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
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

// --- CornerLinesPainterクラスは不要になったため削除 ---

// --- BackgroundPainterクラス (変更なし) ---
class BackgroundPainter extends CustomPainter {
  final Color stripeColor;
  final Color fillColor;

  BackgroundPainter({required this.stripeColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 縦ストライプの描画
    final stripePaint = Paint()..color = stripeColor;
    const double stripeWidth = 2.0; // ストライプの幅
    const double stripeSpacing = 10.0; // ストライプの間隔 (stripeWidth + space)

    for (double x = 0; x < size.width; x += stripeSpacing) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeWidth, size.height), stripePaint);
    }

    // 左から20%〜30%の領域を塗る
    final fillPaint = Paint()..color = fillColor;
    final double startX = size.width * 0.20;
    final double endX = size.width * 0.30;
    canvas.drawRect(Rect.fromLTWH(startX, 0, endX - startX, size.height), fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is BackgroundPainter &&
        (oldDelegate.stripeColor != stripeColor || oldDelegate.fillColor != fillColor);
  }
}