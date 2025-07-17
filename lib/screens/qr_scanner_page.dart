// lib/screens/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
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
  late DatabaseHelper _dbHelper;

  bool _isShowingWarningForUI = false;
  String? _currentWarningMessage;
  bool _isProcessingQrCode = false; // QRコード処理中かどうか (デバウンス用)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _dbHelper = DatabaseHelper();
    _cameraService = QrCameraService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cameraService.startScanner();
        print('DEBUG: Scanner started on initial PostFrameCallback.');
      }
    });

    _qrProcessor = QrCodeProcessor(
      dbHelper: _dbHelper,
      onWarningStatusChanged: (status, message) {
        setState(() {
          _isShowingWarningForUI = status;
          _currentWarningMessage = message;
          // 警告表示中は _isProcessingQrCode を true に保つ
          _isProcessingQrCode = status;
        });
        print('DEBUG: onWarningStatusChanged: _isShowingWarningForUI: $_isShowingWarningForUI, _isProcessingQrCode: $_isProcessingQrCode');
      },
      // カメラ制御は QrCameraService に一任
      onScannerControl: (shouldStart) {
        if (shouldStart) {
          // 警告も処理もしていなければ再開
          if (!_isShowingWarningForUI && !_isProcessingQrCode) {
            _cameraService.startScanner();
            print('DEBUG: Scanner started from QRScannerPage via onScannerControl.');
          } else {
            print('DEBUG: Scanner not started via onScannerControl, warning or processing is active.');
          }
        } else {
          _cameraService.stopScanner();
          print('DEBUG: Scanner stopped from QRScannerPage via onScannerControl.');
        }
      },
      onProcessingComplete: (parsedData) async { // async を追加
        // 画面遷移前にスキャナーを停止
        _cameraService.stopScanner();
        print('DEBUG: Scanner stopped before navigating to ResultPage.');

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
        print('DEBUG: Skipping detection, _isProcessingQrCode is true.');
        return;
      }

      if (capture.barcodes.isNotEmpty && capture.barcodes[0].rawValue != null) {
        setState(() {
          _isProcessingQrCode = true; // 処理開始
        });
        print('DEBUG: _isProcessingQrCode set to true before calling processQrCodeDetection.');
        await _qrProcessor.processQrCodeDetection(capture.barcodes[0].rawValue);

        // processQrCodeDetection が完了したら _isProcessingQrCode を false に戻す
        // ただし、警告表示中の場合は _isProcessingQrCode は true のまま維持される
        // onProcessingComplete が呼ばれて画面遷移する場合も、そこで false になるのでここでは不要
        // ここは、processQrCodeDetection が警告も遷移もせず単に return した（例: _qrResults.length == 1）場合に
        // _isProcessingQrCode をリセットするためのもの。
        if (!_isShowingWarningForUI) {
          setState(() {
            _isProcessingQrCode = false;
          });
          print('DEBUG: _isProcessingQrCode set to false after detection processing (no warning active).');
        } else {
          print('DEBUG: _isProcessingQrCode remains true because warning is active, will be reset by onWarningStatusChanged.');
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraService.stopScanner();
      print('DEBUG: Scanner stopped due to app lifecycle (inactive/paused).');
    } else if (state == AppLifecycleState.resumed) {
      // 警告も処理もしていなければ再開
      if (!_isShowingWarningForUI && !_isProcessingQrCode) {
        _cameraService.startScanner();
        print('DEBUG: Scanner resumed due to app lifecycle (resumed).');
      } else {
        print('DEBUG: Scanner not resumed due to app lifecycle, warning or processing is active.');
      }
    }
  }

  @override
  void dispose() {
    _cameraService.dispose(); // MobileScannerControllerをdisposeする
    print('DEBUG: Scanner controller disposed in QRScannerPage dispose.');
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
