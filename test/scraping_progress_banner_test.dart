// test/scraping_progress_banner_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_banner_route_observer.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_progress_banner.dart';

void main() {
  // ScrapingManagerはシングルトンのため、各テストの前に必ずキューをリセットする。
  // [追加] Phase 4-F: ScrapingBannerRouteObserver.stackDepthもstaticなため、
  // テスト間で値が残らないようリセットする (v.2026.9.5+26090505)
  setUp(() {
    ScrapingManager().clearQueue();
    ScrapingBannerRouteObserver.stackDepth.value = 0;
  });

  group('ScrapingProgressBanner', () {
    testWidgets('スクレイピングが実行されていない場合は何も表示されない', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ScrapingProgressBanner()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('タスク実行中はCircularProgressIndicatorとタスク名が表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ScrapingProgressBanner()));
      await tester.pump();

      final completer = Completer<void>();
      ScrapingManager().addRequest('テストタスク', () => completer.future, key: 'banner-test-1');
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('テストタスク'), findsOneWidget);

      // 後続テストへタイマーを残さないよう、完了・間隔待ちまで進めてキューを空にする
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('totalCountが設定されている場合は(done/total)形式で表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ScrapingProgressBanner()));
      await tester.pump();

      final completer1 = Completer<void>();
      ScrapingManager().addRequest('task1', () => completer1.future, key: 'banner-test-2a');
      await tester.pump();

      // task2はtask1が完了するまでキュー内で待機する（この時点でtotalCount=2になる）
      ScrapingManager().addRequest('task2', () async {}, key: 'banner-test-2b');

      completer1.complete();
      await tester.pump();
      // task1完了後の間隔待ちを消化し、task2の処理開始イベントを受け取る
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.textContaining('(1/2)'), findsOneWidget);

      // task2完了・間隔待ちまで進めてキューを空にし、後続テストへ影響を残さない
      await tester.pump(const Duration(milliseconds: 1600));
    });

    // [追加] Phase 4-F: ボトムナビゲーションバー分の下端パディング付け替えの検証 (v.2026.9.5+26090505)
    testWidgets('stackDepthが1かつ幅450px以下のときkBottomNavigationBarHeightが加算される', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ScrapingBannerRouteObserver.stackDepth.value = 1;

      await tester.pumpWidget(const MaterialApp(home: ScrapingProgressBanner()));
      await tester.pump();

      final completer = Completer<void>();
      ScrapingManager().addRequest('t', () => completer.future, key: 'banner-test-3');
      await tester.pump();
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container));
      final padding = container.padding as EdgeInsets;
      expect(padding.bottom, greaterThanOrEqualTo(kBottomNavigationBarHeight));

      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('stackDepthが2のときはkBottomNavigationBarHeightが加算されない', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ScrapingBannerRouteObserver.stackDepth.value = 2;

      await tester.pumpWidget(const MaterialApp(home: ScrapingProgressBanner()));
      await tester.pump();

      final completer = Completer<void>();
      ScrapingManager().addRequest('t', () => completer.future, key: 'banner-test-4');
      await tester.pump();
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container));
      final padding = container.padding as EdgeInsets;
      expect(padding.bottom, lessThan(kBottomNavigationBarHeight));

      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
    });
  });
}
