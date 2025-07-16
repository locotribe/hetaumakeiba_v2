// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart'; // QRScannerPage をインポート
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart'; // GalleryQrScannerPage をインポート

class HomePage extends StatelessWidget {
  // _savedListKey を受け取るためのフィールドを追加
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  // コンストラクタに savedListKey を追加
  const HomePage({super.key, required this.savedListKey});

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
            mainAxisAlignment: MainAxisAlignment.center, // 中央に配置
            children: [
              const Text(
                'へたうま競馬', // アプリ名
                style: TextStyle(
                  fontSize: 32, // フォントサイズ
                  fontWeight: FontWeight.bold, // フォントの太さ
                  color: Colors.black87, // テキストの色
                ),
              ),
              const SizedBox(height: 50), // テキストとボタンの間のスペース

              // QRスキャナーボタン
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: false).push(
                    MaterialPageRoute(
                      builder: (_) => QRScannerPage(
                        scanMethod: 'camera',
                        savedListKey: savedListKey, // savedListKey を渡す
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // パディング
                  textStyle: const TextStyle(fontSize: 18), // テキストスタイル
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 角丸
                ),
                child: const Text('カメラで馬券をスキャンする'),
              ),
              const SizedBox(height: 20), // ボタン間のスペース

              // ギャラリーからスキャンボタン
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: false).push(
                    MaterialPageRoute(
                      builder: (_) => GalleryQrScannerPage(
                        scanMethod: 'gallery',
                        savedListKey: savedListKey, // savedListKey を渡す
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // パディング
                  textStyle: const TextStyle(fontSize: 18), // テキストスタイル
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 角丸
                  backgroundColor: Colors.blueGrey, // ボタンの色を差別化
                ),
                child: const Text('ギャラリーから馬券を読み込む'),
              ),
              const SizedBox(height: 20), // ボタン間のスペース

              // 取得済み一覧ボタン
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: false).push(
                    MaterialPageRoute(
                      builder: (_) => SavedTicketsListPage(), // SavedTicketsListPage は savedListKey を直接受け取らないため、ここでは渡しません
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // パディング
                  textStyle: const TextStyle(fontSize: 18), // テキストスタイル
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 角丸
                  backgroundColor: Colors.green, // ボタンの色を差別化
                ),
                child: const Text('取得済み一覧を見る'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
