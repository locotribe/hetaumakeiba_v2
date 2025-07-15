// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景ウィジェットをインポート

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
        // アプリ名を中央に表示
        const Center(
          child: Text(
            'へたうま競馬', // アプリ名
            style: TextStyle(
              fontSize: 32, // フォントサイズ
              fontWeight: FontWeight.bold, // フォントの太さ
              color: Colors.black87, // テキストの色
            ),
          ),
        ),
      ],
    );
  }
}
