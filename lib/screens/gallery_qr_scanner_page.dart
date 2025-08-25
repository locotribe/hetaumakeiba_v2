// lib/screens/gallery_qr_scanner_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';

// 新しく分離したギャラリーQRデータ処理ロジックをインポート
import 'package:hetaumakeiba_v2/logic/gallery_qr_code_processor.dart';

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

  late GalleryQrCodeProcessor _galleryQrProcessor; // 新しいプロセッサのインスタンス

  @override
  void initState() {
    super.initState();
    final DatabaseHelper dbHelper = DatabaseHelper(); // プロセッサに渡すためのインスタンス

    _galleryQrProcessor = GalleryQrCodeProcessor(
      dbHelper: dbHelper,
      onWarningStatusChanged: (status, message) {
        setState(() {
          _errorMessage = message; // メッセージをUIに表示
          _isProcessing = status; // 警告表示中は処理中とみなす
        });
        if (!status) { // 警告が解除されたら、処理中フラグを解除
          setState(() {
            _isProcessing = false;
          });
        }
      },
      onProcessingComplete: (parsedData) {
        setState(() {
          _isProcessing = false; // 処理完了
        });
        if (mounted) {
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

    // ページ表示時に自動でギャラリーを開く
    _pickImageAndScanQr();
  }

  @override
  void dispose() {
    // MobileScannerController は GalleryQrCodeProcessor 内で管理されるため、ここではdisposeしない
    super.dispose();
  }

  Future<void> _pickImageAndScanQr() async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true; // 処理開始
    });

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imagePath = pickedFile.path;
      setState(() {
        _imageFile = File(imagePath);
      });
      // 新しいプロセッサに画像パスを渡して処理を依頼
      await _galleryQrProcessor.processImageQrCode(imagePath);
    } else {
      setState(() {
        _isProcessing = false; // 画像選択がキャンセルされたら処理を終了
      });
      if (mounted) {
        Navigator.of(context).pop(); // 画像選択がキャンセルされた場合、前の画面に戻る
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ギャラリーから登録'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imageFile != null)
                    Container(
                      width: 250,
                      height: 250,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              spreadRadius: 2,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickImageAndScanQr,
                    icon: _isProcessing
                        ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                        : const Icon(Icons.photo_library, size: 28),
                    label: Text(
                      _isProcessing ? '処理中...' : 'ギャラリーから画像を選択',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: _isProcessing ? Colors.grey : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      elevation: _isProcessing ? 0 : 3,
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, left: 16, right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 15,
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
