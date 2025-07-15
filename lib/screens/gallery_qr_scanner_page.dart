// lib/screens/gallery_qr_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート
import 'dart:ui' as ui; // BackdropFilterのために必要 (今回は使用しないが、念のため残す)
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート
import 'package:hetaumakeiba_v2/screens/result_page.dart'; // ResultPageをインポート

class GalleryQrScannerPage extends StatefulWidget {
  final String scanMethod; // スキャン方法を受け取るためのプロパティ
  final GlobalKey<SavedTicketsListPageState> savedListKey; // Keyを受け取る

  const GalleryQrScannerPage({
    super.key,
    this.scanMethod = 'unknown',
    required this.savedListKey,
  });

  @override
  State<GalleryQrScannerPage> createState() => _GalleryQrScannerPageState();
}

class _GalleryQrScannerPageState extends State<GalleryQrScannerPage> {
  // ダミーのQRコード解析処理
  void _processDummyQrCode() {
    final dummyParsedData = {
      'エラー': 'ギャラリー機能は未実装です',
      '詳細': 'ダミーデータです。実際のQRコードは検出されていません。',
      'QR': 'DUMMY_QR_CODE_FROM_GALLERY',
      '年': '2024',
      '回': '1',
      '日': '1',
      '開催場': '東京',
      'レース': '1R',
      '方式': '通常',
      '購入内容': [
        {'式別': '単勝', '馬番': [1], '購入金額': 100},
      ],
      '発売所': 'JRA東京',
    };

    // ResultPageへ遷移
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultPage(parsedResult: dummyParsedData)),
      ).then((_) {
        // ResultPageから戻ってきたらSavedListをリロード
        widget.savedListKey.currentState?.loadData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack( // Scaffoldを削除し、Stackを直接返す
      children: [
        Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
            stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
            fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ギャラリーからの読み込み機能は\n今後実装予定です。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _processDummyQrCode,
                child: const Text('ダミーデータでResultPageへ'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
