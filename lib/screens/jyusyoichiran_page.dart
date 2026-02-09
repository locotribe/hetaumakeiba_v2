import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

class JyusyoIchiranPage extends StatelessWidget {
  const JyusyoIchiranPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景設定（元のデザインを維持）
        const Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
            stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
            fillColor: Color.fromRGBO(172, 234, 231, 1.0),
          ),
        ),
        // コンテンツ部分（機能のみ削除してテキストを表示）
        const Center(
          child: Text(
            'ここに重賞一覧が表示されます',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}