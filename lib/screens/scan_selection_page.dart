// lib/screens/scan_selection_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart'; // カメラQRスキャナーページをインポート
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart'; // ギャラリーQRスキャナーページをインポート
import 'package:hetaumakeiba_v2/screens/result_page.dart'; // 解析結果ページをインポート

class ScanSelectionPage extends StatefulWidget {
  const ScanSelectionPage({super.key});

  @override
  State<ScanSelectionPage> createState() => _ScanSelectionPageState();
}

class _ScanSelectionPageState extends State<ScanSelectionPage> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // カスタム背景を画面いっぱいに配置
        Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0), // 全体の背景色
            stripeColor: const Color.fromRGBO(219, 234, 234, 0.6), // ストライプの色
            fillColor: const Color.fromRGBO(172, 234, 231, 1.0), // 塗りつぶしの色
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // ボタンを中央に配置
            children: [
              ElevatedButton(
                onPressed: () async {
                  // カメラで馬券をスキャンするページへ遷移し、結果を待つ
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerPage()),
                  );
                  // スキャン結果があればResultPageへ遷移
                  if (result != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ResultPage(parsedResult: result)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // パディング
                  textStyle: const TextStyle(fontSize: 18), // テキストスタイル
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 角丸
                ),
                child: const Text('カメラで馬券をスキャンする'), // ボタンテキスト
              ),
              const SizedBox(height: 20), // ボタン間のスペース
              ElevatedButton(
                onPressed: () async {
                  // ギャラリーから馬券を読み込むページへ遷移し、結果を待つ
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(builder: (_) => const GalleryQrScannerPage()),
                  );
                  // スキャン結果があればResultPageへ遷移
                  if (result != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ResultPage(parsedResult: result)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // パディング
                  textStyle: const TextStyle(fontSize: 18), // テキストスタイル
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 角丸
                  backgroundColor: Colors.blueGrey, // ボタンの色を差別化
                ),
                child: const Text('ギャラリーから馬券を読み込む'), // ボタンテキスト
              ),
            ],
          ),
        ),
      ],
    );
  }
}
