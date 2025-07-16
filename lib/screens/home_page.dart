// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート
import 'package:hetaumakeiba_v2/screens/scan_selection_page.dart'; // スキャン選択ページをインポート
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // 保存済みリストページをインポート

class HomePage extends StatelessWidget {
  // SavedTicketsListPageState のキーを受け取るように変更
  // これにより、他のページから保存済みリストのデータをリロードできるようになります。
  final GlobalKey<SavedTicketsListPageState> savedListKey;

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
            mainAxisAlignment: MainAxisAlignment.center, // ボタンを中央に配置
            children: [
              // アプリ名
              const Text(
                'へたうま競馬', // アプリ名
                style: TextStyle(
                  fontSize: 32, // フォントサイズ
                  fontWeight: FontWeight.bold, // フォントの太さ
                  color: Colors.black87, // テキストの色
                ),
              ),
              const SizedBox(height: 50), // ボタンとの間隔

              // スキャンボタン
              ElevatedButton.icon(
                onPressed: () {
                  // スキャン選択ページへ遷移
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ScanSelectionPage(savedListKey: savedListKey), // savedListKey を渡す
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  '馬券をスキャンする',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 3,
                ),
              ),
              const SizedBox(height: 20), // ボタン間のスペース

              // 保存済み馬券一覧ボタン
              ElevatedButton.icon(
                onPressed: () {
                  // 保存済み馬券一覧ページへ遷移
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SavedTicketsListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt, size: 28),
                label: const Text(
                  '保存済み馬券を見る',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
