// lib/screens/gallery_qr_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート

class GalleryQrScannerPage extends StatelessWidget {
  const GalleryQrScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ギャラリーから読み込み'), // AppBarのタイトル
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // テーマから背景色を取得
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor, // テーマから前景色を取得
      ),
      body: Stack(
        children: [
          // カスタム背景を画面いっぱいに配置
          Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0), // 全体の背景色
              stripeColor: const Color.fromRGBO(219, 234, 234, 0.6), // ストライプの色
              fillColor: const Color.fromRGBO(172, 234, 231, 1.0), // 塗りつぶしの色
            ),
          ),
          // 機能が未実装であることを示すテキストを中央に表示
          const Center(
            child: Text(
              'ギャラリーからの読み込み機能は\n今後実装予定です。', // 未実装メッセージ
              textAlign: TextAlign.center, // テキストを中央揃え
              style: TextStyle(fontSize: 20, color: Colors.black54), // フォントサイズと色
            ),
          ),
        ],
      ),
    );
  }
}
