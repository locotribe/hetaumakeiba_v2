// lib/screens/qr_scanner_page.dart

import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'dart:ui' as ui; // BackdropFilterのために必要 (今回は使用しないが、念のため残す)

// CustomBackgroundウィジェットをインポート
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
// ResultPageをインポート
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート

class QRScannerPage extends StatefulWidget {
  final String scanMethod; // スキャン方法を受け取るためのプロパティ
  final GlobalKey<SavedTicketsListPageState> savedListKey; // Keyを受け取る

  const QRScannerPage({
    super.key,
    this.scanMethod = 'unknown',
    required this.savedListKey, // コンストラクタに追加
  });

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  // MobileScannerController の初期化方法を修正
  // torchEnabledとfacingはMobileScannerControllerのコンストラクタで設定可能
  MobileScannerController cameraController = MobileScannerController(
    torchEnabled: false, // 初期状態でフラッシュをオフに設定
    facing: CameraFacing.back, // 初期状態で背面カメラを使用
  );
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isProcessing = false; // QRコード処理中のフラグ
  bool _isShowingDuplicateMessage = false; // 重複メッセージ表示中のフラグ
  String? _lastScannedQrCode; // 最後にスキャンしたQRコードを保持

  // 検出されたQRコードの断片を一時的に保持するリスト
  final List<String> _qrResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ライフサイクルオブザーバーを追加
    // スキャナーをすぐに開始
    _startScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ライフサイクルオブザーバーを削除
    cameraController.dispose(); // カメラコントローラーを破棄
    super.dispose();
  }

  // スキャナーを開始するヘルパーメソッド
  void _startScanner() {
    if (!mounted) return; // ウィジェットがマウントされていない場合は何もしない
    if (!cameraController.value.isInitialized) {
      // コントローラーが初期化されていない場合は初期化を試みる
      cameraController.start().then((_) {
        if (mounted) setState(() {}); // UIを更新してカメラの状態を反映
      }).catchError((e) {
        print('スキャナー開始エラー: $e');
        // エラーハンドリング
      });
    } else {
      // 既に初期化されている場合は再開
      cameraController.start().then((_) {
        if (mounted) setState(() {}); // UIを更新してカメラの状態を反映
      }).catchError((e) {
        print('スキャナー再開エラー: $e');
        // エラーハンドリング
      });
    }
  }

  // スキャナーを停止するヘルパーメソッド
  void _stopScanner() {
    if (!mounted) return; // ウィジェットがマウントされていない場合は何もしない
    if (cameraController.value.isInitialized) {
      cameraController.stop().then((_) {
        if (mounted) setState(() {}); // UIを更新してカメラの状態を反映
      }).catchError((e) {
        print('スキャナー停止エラー: $e');
        // エラーハンドリング
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリのライフサイクル状態が変更されたときにカメラを制御
    if (!cameraController.value.isInitialized) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
      // アプリがフォアグラウンドに戻ったときにカメラを再開
        _startScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      // アプリがバックグラウンドに移動したときにカメラを停止
        _stopScanner();
        break;
    }
  }

  // QRコードが検出されたときに呼び出されるメソッド
  void _onQrCodeDetect(BarcodeCapture capture) async {
    if (_isProcessing) return; // 処理中の場合はスキップ

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? qrCode = barcodes.first.rawValue; // 最初のQRコードを取得

      if (qrCode != null && qrCode.isNotEmpty) {
        // 処理を開始する前にスキャナーを一時停止
        _stopScanner();

        setState(() {
          _isProcessing = true; // 処理中フラグを立てる
          _lastScannedQrCode = qrCode; // 最後にスキャンしたQRコードを更新
        });

        // データベースでQRコードの重複をチェック
        // 修正箇所: isQrCodeDuplicate を qrCodeExists に変更
        final isDuplicate = await _dbHelper.qrCodeExists(qrCode);

        if (isDuplicate) {
          // 重複している場合、メッセージを表示してスキャナーを再開
          setState(() {
            _isShowingDuplicateMessage = true;
            _isProcessing = false; // 処理中フラグを解除
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isShowingDuplicateMessage = false;
              });
              _startScanner(); // スキャナーを再開
              _qrResults.clear(); // 重複メッセージ表示後、QR結果リストをクリア
            }
          });
        } else {
          // 重複していない場合、データを保存して結果ページへ遷移
          final qrData = QrData(qrCode: qrCode, timestamp: DateTime.now());
          await _dbHelper.insertQrData(qrData);

          // SavedTicketsListPage のデータをリロード
          widget.savedListKey.currentState?.loadData();

          try {
            final parsedResult = parseHorseracingTicketQr(qrCode);
            // ResultPage に savedListKey を渡す
            // 修正箇所: pushReplacement を使用して、現在のスキャナーページを結果ページに置き換える
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ResultPage(
                  parsedResult: parsedResult,
                  savedListKey: widget.savedListKey, // savedListKey を渡す
                ),
              ),
            ).then((_) {
              // ResultPage から戻ってきたときにスキャナーを再開し、処理中フラグを解除
              // pushReplacement を使った場合、この .then() は呼ばれない可能性が高い
              // ResultPage のボタンから直接スキャナーページに戻るようにする
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedQrCode = null; // 最後にスキャンしたQRコードをリセット
                  _qrResults.clear(); // 処理後、QR結果リストをクリア
                });
              }
            });
          } catch (e) {
            // 解析エラーが発生した場合
            print('QRコード解析エラー: $e');
            // エラーメッセージを表示するなど
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _lastScannedQrCode = null; // 最後にスキャンしたQRコードをリセット
                _qrResults.clear(); // エラー発生後、QR結果リストをクリア
              });
              _startScanner(); // エラー発生後もスキャナーを再開
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Scaffoldを追加してAppBarを表示
      backgroundColor: Colors.transparent, // 背景を透過
      appBar: AppBar(
        title: const Text('QRコードスキャナー'),
        actions: [
          // フラッシュボタン
          IconButton(
            color: Colors.white,
            // 修正箇所: ValueListenableBuilder を削除し、直接 cameraController のプロパティを参照
            icon: Icon(
              cameraController.torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: cameraController.torchEnabled ? Colors.yellow : Colors.grey,
            ),
            iconSize: 32.0,
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() {}); // UIを更新
            },
          ),
          // カメラ切り替えボタン
          IconButton(
            color: Colors.white,
            // 修正箇所: ValueListenableBuilder を削除し、直接 cameraController のプロパティを参照
            icon: Icon(
              cameraController.facing == CameraFacing.front ? Icons.camera_front : Icons.camera_rear,
            ),
            iconSize: 32.0,
            onPressed: () async {
              await cameraController.switchCamera();
              setState(() {}); // UIを更新
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // カスタム背景を画面いっぱいに配置
          Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          // カメラプレビュー
          MobileScanner(
            controller: cameraController,
            onDetect: _onQrCodeDetect,
          ),
          // スキャンガイドとメッセージのオーバーレイ
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(16.0),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 60,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'QRコードをスキャンしてください',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
      ),
    );
  }
}
