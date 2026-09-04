// lib/widgets/scraping_banner_route_observer.dart

// [追加] Phase 4-F: 進捗バナーが画面下部でボトムナビゲーションバーと重ならないよう
// 避けるべきかどうかの判定に、ナビゲーションスタックの深さを使う (v.2026.9.5+26090505)

import 'package:flutter/material.dart';

/// ナビゲーションスタックの深さを追跡するNavigatorObserver。
/// バナーがボトムナビゲーションバーを避けるかどうかの判定に使う。
/// 深さ1＝ホームルート（MainScaffold）が最前面。
class ScrapingBannerRouteObserver extends NavigatorObserver {
  static final ValueNotifier<int> stackDepth = ValueNotifier<int>(0);

  // [追加] Phase 4-F: ValueNotifierの更新はナビゲーション中のビルドと衝突しうるため、
  // 必ずaddPostFrameCallbackの中で行う (v.2026.9.5+26090505)
  static void _increment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stackDepth.value = stackDepth.value + 1;
    });
  }

  static void _decrement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final next = stackDepth.value - 1;
      stackDepth.value = next < 0 ? 0 : next;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _increment();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _decrement();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _decrement();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // 置き換えでは深さは変化させない。
  }
}
