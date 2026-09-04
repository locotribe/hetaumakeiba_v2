// test/scraping_progress_banner_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_progress_banner.dart';

void main() {
  // ScrapingManagerはシングルトンのため、各テストの前に必ずキューをリセットする。
  setUp(() {
    ScrapingManager().clearQueue();
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
  });
}
