// lib/screens/qr_scanner_page.dart の変更点

import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart'; // 追加
import 'package:hetaumakeiba_v2/models/qr_data_model.dart'; // 追加

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final List<String> _qrResults = [];
  // DatabaseHelperのインスタンスを取得
  final DatabaseHelper _dbHelper = DatabaseHelper(); // 追加

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

  void _processTwoQRs(String first, String second) async { // async を追加
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
      // QRコードデータと解析結果が正常な場合にのみ保存
      if (parsedData['QR'] != null) {
        // ここでQRコードデータを保存
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String, // 解析されたQRコード文字列
          timestamp: DateTime.now(),
        );
        await _dbHelper.insertQrData(qrDataToSave); // データベースに保存
        print('QRコードデータが保存されました: ${qrDataToSave.qrCode}'); // デバッグ用
      }
    } catch (_) {
      try {
        parsedData = parseHorseracingTicketQr(alt);
        // QRコードデータと解析結果が正常な場合にのみ保存
        if (parsedData['QR'] != null) {
          // ここでQRコードデータを保存
          final qrDataToSave = QrData(
            qrCode: parsedData['QR'] as String, // 解析されたQRコード文字列
            timestamp: DateTime.now(),
          );
          await _dbHelper.insertQrData(qrDataToSave); // データベースに保存
          print('QRコードデータが保存されました: ${qrDataToSave.qrCode}'); // デバッグ用
        }
      } catch (e) {
        parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      }
    }

    Navigator.of(context).pop(parsedData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRコードスキャナー')),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
            ),
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '${_qrResults.length} / 2 個のQRコードを読み取りました',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}