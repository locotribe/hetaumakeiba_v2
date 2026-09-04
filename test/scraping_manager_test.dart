// test/scraping_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';

void main() {
  // ScrapingManagerはシングルトンのため、各テストの前後でキューとカウンタを必ずリセットする。
  setUp(() {
    ScrapingManager().clearQueue();
  });

  tearDown(() {
    ScrapingManager().clearQueue();
  });

  group('ScrapingManager', () {
    test('同一keyで2回addRequestすると、後発は現在実行中のタスクと重複するため無視される', () async {
      int count = 0;
      ScrapingManager().addRequest('t1', () async {
        count++;
      }, key: 'dup-key');
      // 1件目は同期的にキューへ積まれて即実行開始されるため、
      // 2件目のaddRequest時点で1件目は「現在実行中」として重複判定される
      ScrapingManager().addRequest('t2', () async {
        count++;
      }, key: 'dup-key');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(count, 1);

      // 後続テストへ影響を残さないよう、1件目のキュー処理間隔が明けるのを待つ
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    });

    test('異なるkeyなら2件ともキューに積まれ、いずれ両方実行される', () async {
      final executed = <String>[];
      ScrapingManager().addRequest('t1', () async {
        executed.add('a');
      }, key: 'key-a');
      ScrapingManager().addRequest('t2', () async {
        executed.add('b');
      }, key: 'key-b');

      // t1実行→間隔待ち→t2実行、の分がすべて終わるまで待つ
      await Future<void>.delayed(const Duration(milliseconds: 3300));
      expect(executed, ['a', 'b']);
    });

    test('keyを省略した場合は従来どおり重複して積まれ、両方実行される', () async {
      final executed = <String>[];
      ScrapingManager().addRequest('t1', () async {
        executed.add('x');
      });
      ScrapingManager().addRequest('t2', () async {
        executed.add('x');
      });

      await Future<void>.delayed(const Duration(milliseconds: 3300));
      expect(executed, ['x', 'x']);
    });

    test('clearQueue()後にカウンタがリセットされる', () async {
      final statuses = <ScrapingStatus>[];
      final sub = ScrapingManager().statusStream.listen(statuses.add);

      ScrapingManager().addRequest('reset-t1', () async {}, key: 'reset-a');
      ScrapingManager().addRequest('reset-t2', () async {}, key: 'reset-b');
      // reset-t2をキューに積んだ直後にclearQueueすることで、
      // 実行中のreset-t1には影響を与えずキューとカウンタだけをリセットする
      ScrapingManager().clearQueue();

      // reset-t1の処理間隔が明けてキューが空になり、カウンタが0へ戻るのを待つ
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      ScrapingManager().addRequest('reset-t3', () async {}, key: 'reset-c');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final t3Status = statuses.lastWhere((s) => s.currentTaskName == 'reset-t3');
      // clearQueueでリセットされていなければ3のままになってしまうはずの値が1であること
      expect(t3Status.totalCount, 1);

      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    });
  });
}
