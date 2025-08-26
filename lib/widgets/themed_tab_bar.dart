import 'package:flutter/material.dart';

class ThemedTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;

  // アプリ全体で使いたいTabBarの背景色をここで定義
  static const Color _backgroundColor = Color(0xFF303030); // 例: ダークグレー

  const ThemedTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    // ContainerでTabBarをラップし、定義した背景色を適用する
    return Container(
      color: _backgroundColor,
      child: TabBar(
        controller: controller,
        tabs: tabs,
        isScrollable: isScrollable,
      ),
    );
  }

  // TabBarをAppBarのbottomで使う場合に必要な設定
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}