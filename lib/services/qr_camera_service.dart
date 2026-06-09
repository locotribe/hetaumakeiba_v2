// lib/services/qr_camera_service.dart

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrCameraService {
  late MobileScannerController _scannerController;
  bool _isScannerActive = false;
  Function(BarcodeCapture)? _onDetectCallback;

  MobileScannerController get controller => _scannerController;
  bool get isScannerActive => _isScannerActive;

  QrCameraService() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  void setOnDetectCallback(Function(BarcodeCapture) callback) {
    _onDetectCallback = callback;
  }

  // MobileScannerのonDetectに直接渡すためのメソッド
  void handleDetection(BarcodeCapture capture) {
    _onDetectCallback?.call(capture);
  }

  Future<void> startScanner() async {
    if (!_isScannerActive) {
      try {
        await _scannerController.start();
        _isScannerActive = true;
        debugPrint('Scanner started');
      } catch (e) {
        debugPrint('Error starting scanner: $e');
      }
    }
  }

  Future<void> stopScanner() async {
    if (_isScannerActive) {
      try {
        await _scannerController.stop();
        _isScannerActive = false;
        debugPrint('Scanner stopped');
      } catch (e) {
        debugPrint('Error stopping scanner: $e');
      }
    }
  }

  void dispose() {
    _scannerController.dispose();
    debugPrint('Scanner controller disposed');
  }
}