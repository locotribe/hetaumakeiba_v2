// lib/screens/scan_selection_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart'; // カメラQRスキャナーページをインポート
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart'; // ギャラリーQRスキャナーページをインポート
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート

class ScanSelectionPage extends StatefulWidget {
  final GlobalKey<SavedTicketsListPageState> savedListKey; // Keyを受け取る

  const ScanSelectionPage({super.key, required this.savedListKey}); // コンストラクタに追加

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
        // 修正箇所: Scaffoldを追加してAppBarを表示
        Scaffold(
          backgroundColor: Colors.transparent, // 背景を透過
          appBar: AppBar(
            title: const Text('スキャン方法選択'),
            // 戻るボタンは自動で表示されます
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // ボタンを中央に配置
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // カメラで馬券をスキャンするページへ遷移
                    // スキャン方法と savedListKey を渡す
                    Navigator.of(context).push( // rootNavigator: false は不要
                      MaterialPageRoute(builder: (_) => QRScannerPage(
                        scanMethod: 'camera',
                        savedListKey: widget.savedListKey, // Keyを渡す
                      )),
                    );
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
                    // ギャラリーから馬券を読み込むページへ遷移
                    // スキャン方法と savedListKey を渡す
                    Navigator.of(context).push( // rootNavigator: false は不要
                      MaterialPageRoute(builder: (_) => GalleryQrScannerPage(
                        scanMethod: 'gallery',
                        savedListKey: widget.savedListKey, // Keyを渡す
                      )),
                    );
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
        ),
      ],
    );
  }
}
