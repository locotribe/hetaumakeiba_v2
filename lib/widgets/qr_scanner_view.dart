// lib/widgets/qr_scanner_view.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

class QrScannerView extends StatefulWidget {
  final MobileScannerController scannerController;
  final Function(BarcodeCapture) onDetect;
  final bool isShowingDuplicateMessage;
  final String? warningMessage; // 新しく追加するプロパティ

  const QrScannerView({
    super.key,
    required this.scannerController,
    required this.onDetect,
    required this.isShowingDuplicateMessage,
    this.warningMessage, // コンストラクタにも追加
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;

        final cameraHeight = screenHeight * 0.8;
        final cameraWidth = cameraHeight * (8 / 5);

        final actualCameraWidth = (cameraWidth > screenWidth) ? screenWidth : cameraWidth;
        final actualCameraHeight = actualCameraWidth * (5 / 8);

        final cameraTopOffset = screenHeight * 0.3;

        final scanAreaSize = actualCameraWidth * 0.8;

        return Stack(
          children: [
            // 背景のストライプと特定領域の塗りつぶし
            Positioned.fill(
              child: CustomBackground(
                overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
                stripeColor: const Color.fromRGBO(219, 234, 234, 0.3),
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
                aspectRatio: 8 / 5,
                child: ClipRect(
                  child: MobileScanner(
                    controller: widget.scannerController,
                    onDetect: widget.onDetect,
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

            // 重複メッセージ表示UI (警告メッセージを表示するように変更)
            if (widget.isShowingDuplicateMessage)
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
                      child: Text( // const を削除して動的なテキストを許可
                        widget.warningMessage ?? 'この馬券はすでに読み込みました', // warningMessage があればそれを表示、なければデフォルト
                        style: const TextStyle( // TextStyle は const のまま
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
    );
  }
}
