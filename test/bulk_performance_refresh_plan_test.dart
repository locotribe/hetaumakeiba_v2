// test/bulk_performance_refresh_plan_test.dart

// [一時] 陣営の本気度指数 実施順2: 一括取り直しの対象の並べ方・集計の単体テスト。一時ボタンと一緒に削除する (v.2026.10.2+26100204)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/bulk_performance_refresh_plan.dart';

BulkRefreshTarget _t(String horseId, [String horseName = '']) {
  return BulkRefreshTarget(horseId: horseId, horseName: horseName);
}

List<String> _ids(List<BulkRefreshTarget> targets) {
  return targets.map((t) => t.horseId).toList();
}

void main() {
  group('remainingBulkRefreshTargets', () {
    test('処理済みの馬を除き、並び順を保つ', () {
      final all = [_t('3'), _t('1'), _t('2')];
      expect(_ids(remainingBulkRefreshTargets(all, {'1'})), ['3', '2']);
    });

    test('処理済みが無ければ全頭をそのままの順で返す', () {
      final all = [_t('3'), _t('1'), _t('2')];
      expect(_ids(remainingBulkRefreshTargets(all, <String>{})), ['3', '1', '2']);
    });

    test('重複と空の馬IDを除く', () {
      final all = [_t('1'), _t(''), _t('1'), _t('2')];
      expect(_ids(remainingBulkRefreshTargets(all, <String>{})), ['1', '2']);
    });

    test('全頭処理済みなら空', () {
      final all = [_t('1'), _t('2')];
      expect(remainingBulkRefreshTargets(all, {'1', '2'}), isEmpty);
    });
  });

  group('estimatedBulkRefreshMinutes', () {
    test('0頭以下は0分', () {
      expect(estimatedBulkRefreshMinutes(0), 0);
      expect(estimatedBulkRefreshMinutes(-1), 0);
    });

    test('1頭2秒で分に切り上げる', () {
      expect(estimatedBulkRefreshMinutes(1), 1);
      expect(estimatedBulkRefreshMinutes(30), 1);
      expect(estimatedBulkRefreshMinutes(31), 2);
      expect(estimatedBulkRefreshMinutes(571), 20);
    });
  });

  group('BulkRefreshTally', () {
    test('成功すると連続失敗が0に戻る', () {
      final tally = BulkRefreshTally();
      for (var i = 0; i < 4; i++) {
        tally.recordFailure(_t('f$i'));
      }
      tally.recordSuccess();
      expect(tally.consecutiveFailures, 0);
      expect(tally.shouldAutoStop, isFalse);
      expect(tally.successCount, 1);
      expect(tally.failed.length, 4);
      expect(tally.processedCount, 5);
    });

    test('5頭続けて失敗すると自動停止になる', () {
      final tally = BulkRefreshTally();
      for (var i = 0; i < 4; i++) {
        tally.recordFailure(_t('f$i'));
      }
      expect(tally.shouldAutoStop, isFalse);
      tally.recordFailure(_t('f4'));
      expect(tally.shouldAutoStop, isTrue);
    });
  });

  group('BulkRefreshTarget.label', () {
    test('馬名があれば「馬名（馬ID）」', () {
      expect(_t('2021101234', 'テストホース').label, 'テストホース（2021101234）');
    });

    test('馬名が空なら馬IDだけ', () {
      expect(_t('2021101234').label, '2021101234');
    });
  });
}
