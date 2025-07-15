// lib/screens/gallery_qr_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート

class GalleryQrScannerPage extends StatelessWidget {
  final String scanMethod; // スキャン方法を受け取るためのプロパティ

  const GalleryQrScannerPage({super.key, this.scanMethod = 'unknown'}); // デフォルト値を設定

  @override
  Widget build(BuildContext context) {
    // ScaffoldとAppBarを削除し、直接コンテンツを返すように変更
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
        // 機能が未実装であることを示すテキストを中央に表示
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ギャラリーからの読み込み機能は\n今後実装予定です。', // 未実装メッセージ
                textAlign: TextAlign.center, // テキストを中央揃え
                style: TextStyle(fontSize: 20, color: Colors.black54), // フォントサイズと色
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // ここでダミーデータを返してResultPageに遷移させる（テスト用）
                  // 実際にはギャラリーから画像を選択し、QRコードを検出して解析するロジックが入る
                  final dummyParsedData = {
                    'エラー': 'ギャラリー機能は未実装です',
                    '詳細': 'ダミーデータです。実際のQRコードは検出されていません。',
                    'QR': 'DUMMY_QR_CODE_FROM_GALLERY', // ダミーのQRコード文字列
                  };
                  Navigator.of(context).pop({
                    'parsedData': dummyParsedData,
                    'scanMethod': scanMethod, // ここを widget.scanMethod から scanMethod に修正
                  });
                },
                child: const Text('ダミーデータでResultPageへ'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
