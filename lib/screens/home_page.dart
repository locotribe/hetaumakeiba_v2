// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';

class HomePage extends StatelessWidget {
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const HomePage({super.key, required this.savedListKey});

  @override
  Widget build(BuildContext context) {
    // ScaffoldとFABを削除し、コンテンツ部分のみを返す
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
            stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
            fillColor: Color.fromRGBO(172, 234, 231, 1.0),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // このボタンは現在ナビゲーションバーと機能が重複するため、
              // 将来的には別の機能（例：お知らせ、使い方ガイドなど）に置き換えるか、削除することを推奨します。
              // ここではUIの確認のため一旦残します。
              ElevatedButton.icon(
                onPressed: () {
                  // ボタンの動作は現状維持（ただし、BottomNavigationBarがあるため冗長）
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SavedTicketsListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 28),
                label: const Text(
                  '購入履歴（リスト表示）',
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
            ],
          ),
        ),
      ],
    );
  }
}
