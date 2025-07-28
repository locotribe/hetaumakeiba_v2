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
        // ▼▼▼ ボタンを削除し、将来のコンテンツ用のプレースホルダーに変更 ▼▼▼
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'ここにコンテンツが表示されます\n（例：今週の注目レース、レースカレンダーなど）',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // ▲▲▲ ここまで変更 ▲▲▲
      ],
    );
  }
}
