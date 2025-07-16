// lib/screens/gallery_qr_scanner_page.dart

import 'dart:io'; // dart:io を先頭の方に移動
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // MobileScannerController と BarcodeCapture をインポート
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart'; // DatabaseHelper をインポート
import 'package:hetaumakeiba_v2/models/qr_data_model.dart'; // QrData をインポート

// import 'package:google_mlkit_commons/google_mlkit_commons.dart'; // 不要なので削除済み

class GalleryQrScannerPage extends StatefulWidget {
  final String scanMethod;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const GalleryQrScannerPage({
    super.key,
    this.scanMethod = 'unknown',
    required this.savedListKey,
  });

  @override
  State<GalleryQrScannerPage> createState() => _GalleryQrScannerPageState();
}

class _GalleryQrScannerPageState extends State<GalleryQrScannerPage> {
  File? _imageFile;
  String? _errorMessage;
  bool _isProcessing = false;
  // MobileScannerController のインスタンスを生成
  final MobileScannerController _scannerController = MobileScannerController(
    // detectionSpeed は画像解析時には直接影響しないかもしれませんが、
    // カメラプレビューと同じ設定を保持しておくことも一般的です。
    // 必要に応じて formats などを指定できます。
    // formats: [BarcodeFormat.qrCode], // QRコードのみを対象にする場合
  );
  final DatabaseHelper _dbHelper = DatabaseHelper(); // DatabaseHelper のインスタンスを作成

  @override
  void initState() {
    super.initState();
    // ページ表示時に自動でギャラリーを開く
    _pickImageAndScanQr();
  }

  @override
  void dispose() {
    // Controllerを破棄
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndScanQr() async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imagePath = pickedFile.path;
      setState(() {
        _imageFile = File(imagePath);
      });
      await _scanQrCodeFromImagePath(imagePath); // パスを渡すように変更
    } else {
      setState(() {
        _isProcessing = false;
      });
      // _showError('画像が選択されませんでした。'); // 必要であればメッセージ表示
      if (mounted) {
        Navigator.of(context).pop(); // 画像選択がキャンセルされた場合、前の画面に戻る
      }
    }
  }

  Future<void> _scanQrCodeFromImagePath(String imagePath) async {
    try {
      // MobileScannerControllerのインスタンスメソッド analyzeImage を使用
      final BarcodeCapture? barcodeCapture = await _scannerController.analyzeImage(imagePath);

      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        // 最初のバーコードのrawValueを取得
        final qrCodeData = barcodeCapture.barcodes.first.rawValue;
        if (qrCodeData != null && qrCodeData.isNotEmpty) {
          // 修正箇所: isQrCodeDuplicate を qrCodeExists に変更
          final bool isDuplicate = await _dbHelper.qrCodeExists(qrCodeData);

          if (isDuplicate) {
            _showError('この馬券はすでに読み込みました。');
          } else {
            // 重複していない場合、データを保存して結果ページへ遷移
            final qrData = QrData(qrCode: qrCodeData, timestamp: DateTime.now());
            await _dbHelper.insertQrData(qrData);
            widget.savedListKey.currentState?.loadData(); // 保存済みリストをリロード

            final parsedData = parseHorseracingTicketQr(qrCodeData);
            if (mounted) {
              Navigator.of(context).pushReplacement( // pushReplacement に変更して、ResultPageから直接戻れるようにする
                MaterialPageRoute(builder: (_) => ResultPage(
                  parsedResult: parsedData,
                  savedListKey: widget.savedListKey, // savedListKey を渡す
                )),
              );
            }
          }
        } else {
          _showError('QRコードのデータが読み取れませんでした。画像を確認してください。');
        }
      } else {
        _showError('画像からQRコードを検出できませんでした。別の画像を試してください。');
      }
    } on PlatformException catch (e) { // analyzeImage は PlatformException をスローすることがある
      _showError('QRコードの読み取り中にプラットフォームエラーが発生しました: ${e.message}');
      print("PlatformException during QR scan: ${e.code} - ${e.message}");
    } catch (e) {
      _showError('QRコードの読み取り中に予期せぬエラーが発生しました: $e');
      print("Unexpected error during QR scan: $e");
    } finally {
      if (mounted) { //非同期処理後に setState を呼ぶ場合は mounted チェック
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent, // 少し色味を変更
          duration: const Duration(seconds: 3), // 表示時間を少し長く
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Scaffoldを追加してAppBarを表示
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ギャラリーから登録'),
        // 戻るボタンは自動で表示されます
      ),
      body: Stack( // 修正箇所: StackをScaffoldのbodyの直下に移動
        children: [
          Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          Center(
            child: Padding( // 全体に少しパディングを追加
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imageFile != null)
                    Container(
                      width: 250, // 少し大きく
                      height: 250, // 少し大きく
                      margin: const EdgeInsets.only(bottom: 24), // マージン調整
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey, width: 2), // 枠線の見た目変更
                          borderRadius: BorderRadius.circular(12), // 角丸調整
                          boxShadow: [ // 影を追加
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10), // 内側の画像の角丸
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.contain, // 画像全体が見えるように contain に変更
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickImageAndScanQr,
                    icon: _isProcessing
                        ? Container( // ローディングインジケータ
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                        : const Icon(Icons.photo_library, size: 28), // アイコンサイズ調整
                    label: Text(
                      _isProcessing ? '処理中...' : 'ギャラリーから画像を選択',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // 角丸調整
                      backgroundColor: _isProcessing ? Colors.grey : Colors.blueAccent, // 処理中の色変更
                      foregroundColor: Colors.white,
                      elevation: _isProcessing ? 0 : 3, // 処理中の影を消す
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, left: 16, right: 16), // パディング調整
                      child: Container( // エラーメッセージの背景
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red, // 元の赤色を維持
                            fontSize: 15, // 少し小さく
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
