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
  final List<String> _qrResults = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late MobileScannerController _scannerController;

  bool _isShowingDuplicateMessage = false; // 重複メッセージ表示状態
  bool _isScannerActive = false; // スキャナーがアクティブかどうかを追跡

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAndStartScanner();
  }

  void _initializeAndStartScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
    );
    // UIが完全に描画された後にスキャナーを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isScannerActive) {
        _scannerController.start().then((_) {
          if (mounted) {
            setState(() {
              _isScannerActive = true;
            });
          }
        }).catchError((error) {
          print('Error starting scanner: $error');
          // エラーメッセージを表示するなどの処理
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanner(); // コントローラーを停止
    _scannerController.dispose(); // コントローラーを破棄
    super.dispose();
  }

  void _stopScanner() {
    if (_isScannerActive) {
      _scannerController.stop();
      if (mounted) {
        setState(() {
          _isScannerActive = false;
        });
      }
    }
  }

  void _startScanner() {
    if (mounted && !_isScannerActive) {
      _scannerController.start().then((_) {
        if (mounted) {
          setState(() {
            _isScannerActive = true;
          });
        }
      }).catchError((error) {
        print('Error starting scanner: $error');
        // エラーメッセージを表示するなどの処理
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startScanner();
    } else if (state == AppLifecycleState.paused) {
      _stopScanner();
    }
  }

  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  void _onDetect(BarcodeCapture capture) async {
    // メッセージ表示中は新たな検出を無視
    if (_isShowingDuplicateMessage) {
      return;
    }

    final List<String> detectedRawValues = capture.barcodes
        .map((b) => b.rawValue)
        .where((rv) => rv != null && rv.isNotEmpty)
        .cast<String>()
        .toList();

    for (final rawValue in detectedRawValues) {
      if (_qrResults.contains(rawValue)) {
        continue;
      }

      print('DEBUG: rawValue from scanner: $rawValue');

      final bool existsSingle = await _dbHelper.qrCodeExists(rawValue); // rawValue単体でのチェック
      if (existsSingle) {
        print('DEBUG: Duplicate single QR code detected (rawValue): $rawValue');
        setState(() {
          _isShowingDuplicateMessage = true;
        });
        _stopScanner();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isShowingDuplicateMessage = false;
            });
            _startScanner();
          }
        });
        return; // 重複したQRコードはこれ以上処理しない
      }

      _qrResults.add(rawValue);

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

        print('DEBUG: Combined QR string for duplicate check: $combinedQrCode');

        final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode); // 結合済み文字列でチェック
        if (existsCombined) {
          // 重複が見つかった場合
          print('DEBUG: Duplicate QR code detected (combined): $combinedQrCode');
          setState(() {
            _isShowingDuplicateMessage = true;
            _qrResults.clear(); // 検出された断片をクリアして、次のスキャンに備える
          });
          _stopScanner(); // スキャナーを一時停止

          // 2秒後にメッセージを消してスキャナーを再開
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isShowingDuplicateMessage = false;
              });
              _startScanner(); // スキャナーを再開
            }
          });
          return; // 重複したQRコードはこれ以上処理しない
        } else {
          // 重複ではない場合、通常通り処理と保存に進む
          _stopScanner(); // スキャナーを完全に停止して結果ページへ
          await _processTwoQRs(combinedQrCode); // await を追加
          _qrResults.clear(); // 処理後、検出された断片をクリア
          return; // 処理を終える
        }
      }
    }
  }

  Future<void> _processTwoQRs(String qrCode) async {
    Map<String, dynamic> parsedData;

    try {
      parsedData = parseHorseracingTicketQr(qrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
        );
        print('DEBUG: 馬券データが保存されました: ${qrDataToSave.qrCode}');
        await _dbHelper.insertQrData(qrDataToSave);
        print('馬券データが保存されました: ${qrDataToSave.qrCode}');

        widget.savedListKey.currentState?.loadData(); // 保存済みリストをリロード
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
    }

    // ResultPageへ遷移
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultPage(parsedResult: parsedData)),
      ).then((_) {
        // ResultPageから戻ってきたらスキャナーを再開
        _startScanner();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder( // Scaffoldを削除し、LayoutBuilderを直接返す
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
    );
  }
}
