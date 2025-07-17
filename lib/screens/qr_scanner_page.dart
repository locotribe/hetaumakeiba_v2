// lib/screens/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // MobileScannerControllerのために必要 (ただし、UIからは分離)
import 'package:hetaumakeiba_v2/db/database_helper.dart'; // ロジックで必要
import 'package:hetaumakeiba_v2/screens/result_page.dart'; // ロジックで必要
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // ロジックで必要

// 新しく分離したモジュールをインポート
import 'package:hetaumakeiba_v2/widgets/qr_scanner_view.dart'; // UI表示
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
  // 新しくインスタンスを持つモジュール
  late QrCameraService _cameraService;
  late QrCodeProcessor _qrProcessor;
  late DatabaseHelper _dbHelper; // QrCodeProcessorに渡すため保持

  // QrScannerViewに渡すための状態変数
  bool _isShowingDuplicateMessageForUI = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // DatabaseHelperのインスタンス化
    _dbHelper = DatabaseHelper();

    // QrCameraServiceの初期化
    _cameraService = QrCameraService();
    // UIが完全に描画された後にスキャナーを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cameraService.startScanner();
      }
    });

    // QrCodeProcessorの初期化
    _qrProcessor = QrCodeProcessor(
      dbHelper: _dbHelper,
      onDuplicateStatusChanged: (status) {
        // QrCodeProcessorから重複メッセージの状態が変更されたことを受け取る
        setState(() {
          _isShowingDuplicateMessageForUI = status;
        });
      },
      onProcessingComplete: (parsedData) {
        // QrCodeProcessorから処理完了の通知を受け取り、画面遷移を行う
        // 遷移前にスキャナーを確実に停止
        _cameraService.stopScanner();
        if (mounted) {
          // pushReplacement を使用して、現在のQRScannerPageを破棄し、ResultPageに置き換えます。
          // これにより、ResultPageから「続けてカメラでスキャンする」で戻ってきたときに、
          // 新しいQRScannerPageが initState から開始され、カメラが確実に起動します。
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

    // QrCameraServiceに検出時のコールバックを設定
    _cameraService.setOnDetectCallback((capture) {
      // 検出されたバーコードが空でなく、かつ最初のバーコードのrawValueがnullでない場合のみ処理
      if (capture.barcodes.isNotEmpty && capture.barcodes[0].rawValue != null) {
        _qrProcessor.processQrCodeDetection(capture.barcodes[0].rawValue);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // カメラサービスの状態をアプリのライフサイクルに同期
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraService.stopScanner();
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.startScanner();
    }
  }

  @override
  void dispose() {
    _cameraService.dispose(); // カメラコントローラーの解放
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 以下のメソッドと状態変数は、lib/logic/qr_code_processor.dart に移動されたため、削除します。
  // final List<String> _qrResults = [];
  // bool _isShowingDuplicateMessage = false; // QrCodeProcessor内で管理されるため削除

  // int _countSequence(String s) {
  //   const sequence = "0123456789";
  //   return RegExp(sequence).allMatches(s).length;
  // }

  // void _onDetect(BarcodeCapture capture) async {
  //   // このロジックは QrCodeProcessor.processQrCodeDetection に移動されました
  // }

  // Future<void> _processTwoQRs(String qrCode) async {
  //   // このロジックは QrCodeProcessor._processCombinedQrCode に移動されました
  // }

  @override
  Widget build(BuildContext context) {
    // UIの大部分をQrScannerViewに委譲
    return Scaffold(
      appBar: AppBar( // AppBarを追加
        title: const Text('QRコードスキャナー'), // タイトルのみ
      ),
      body: QrScannerView(
        scannerController: _cameraService.controller, // カメラサービスのコントローラーを渡す
        onDetect: _cameraService.handleDetection, // カメラサービスからの検出を処理
        isShowingDuplicateMessage: _isShowingDuplicateMessageForUI, // 重複メッセージの状態を渡す
      ),
    );
  }
}
