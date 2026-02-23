// lib/screens/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';

import 'package:hetaumakeiba_v2/widgets/qr_scanner_view.dart';
import 'package:hetaumakeiba_v2/services/qr_camera_service.dart'; // カメラ制御
import 'package:hetaumakeiba_v2/logic/qr_code_processor.dart'; // QRデータ処理ロジック

class QRScannerPage extends StatefulWidget {
  final String scanMethod;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const QRScannerPage({
    super.key,
    this.scanMethod = 'unknown',
    required this.savedListKey,
  });

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  late QrCameraService _cameraService;
  late QrCodeProcessor _qrProcessor;

  bool _isShowingWarningForUI = false;
  String? _currentWarningMessage;
  bool _isProcessingQrCode = false; // QRコード処理中かどうか (デバウンス用)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameraService = QrCameraService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cameraService.startScanner();
      }
    });

    _qrProcessor = QrCodeProcessor(
      onWarningStatusChanged: (status, message) {
        setState(() {
          _isShowingWarningForUI = status;
          _currentWarningMessage = message;
          // 警告表示中は _isProcessingQrCode を true に保つ
          _isProcessingQrCode = status;
        });
      },
      // カメラ制御は QrCameraService に一任
      onScannerControl: (shouldStart) {
        if (shouldStart) {
          // 警告も処理もしていなければ再開
          if (!_isShowingWarningForUI && !_isProcessingQrCode) {
            _cameraService.startScanner();
          }
        } else {
          _cameraService.stopScanner();
        }
      },
      onProcessingComplete: (parsedData) async { // async を追加
        // 画面遷移前にスキャナーを停止
        _cameraService.stopScanner();

        // 画面遷移前に短い遅延を導入 (MobileScannerControllerのリソース解放のため)
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          setState(() {
            _isProcessingQrCode = false; // 処理完了
            _isShowingWarningForUI = false; // 念のため警告も解除
            _currentWarningMessage = null;
          });
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultPage(
                parsedResult: parsedData,
                savedListKey: widget.savedListKey,
              ),
            ),
          );
        }
      },
      savedListKey: widget.savedListKey,
    );

    _cameraService.setOnDetectCallback((capture) async {
      // QRコード処理中に新たな検出イベントを無視 (デバウンス)
      if (_isProcessingQrCode) {
        return;
      }

      if (capture.barcodes.isNotEmpty && capture.barcodes[0].rawValue != null) {
        setState(() {
          _isProcessingQrCode = true; // 処理開始
        });
        await _qrProcessor.processQrCodeDetection(capture.barcodes[0].rawValue);

        if (!_isShowingWarningForUI) {
          setState(() {
            _isProcessingQrCode = false;
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraService.stopScanner();
    } else if (state == AppLifecycleState.resumed) {
      // 警告も処理もしていなければ再開
      if (!_isShowingWarningForUI && !_isProcessingQrCode) {
        _cameraService.startScanner();
      }
    }
  }

  @override
  void dispose() {
    _cameraService.dispose(); // MobileScannerControllerをdisposeする
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRコードスキャナー'),
      ),
      body: QrScannerView(
        scannerController: _cameraService.controller,
        onDetect: _cameraService.handleDetection,
        isShowingDuplicateMessage: _isShowingWarningForUI,
        warningMessage: _currentWarningMessage,
      ),
    );
  }
}