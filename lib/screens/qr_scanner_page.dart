// lib/screens/qr_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final List<String> _qrResults = [];

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

  void _processTwoQRs(String first, String second) {
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
    } catch (_) {
      try {
        parsedData = parseHorseracingTicketQr(alt);
      } catch (e) {
        parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
      }
    }

    Navigator.of(context).pop(parsedData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRコードを読み取る')),
      body: MobileScanner(
        fit: BoxFit.cover,
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
        ),
        onDetect: _onDetect,
      ),
    );
  }
}