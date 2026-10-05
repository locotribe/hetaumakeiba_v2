// test/track_condition_active_filter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/track_condition_active_filter.dart';

// [追加] 開催中の会場の絞り込み（最新測定日が全会場の最新から4日以内）の検証 (v.2026.10.6+26100602)
void main() {
  group('selectActiveCourseNames', () {
    test('JRAのページに残った非開催会場（札幌 9/6）は除き、東京・京都（10/4）だけ残す', () {
      final result = selectActiveCourseNames(
        ['東京', '京都', '札幌'],
        {'東京': '2026-10-04', '京都': '2026-10-04', '札幌': '2026-09-06'},
      );
      expect(result, ['東京', '京都']);
    });

    test('変則開催で最終日が1日ずれても（阪神 9/21・中山 9/22）両方残す', () {
      final result = selectActiveCourseNames(
        ['中山', '阪神'],
        {'中山': '2026-09-22', '阪神': '2026-09-21'},
      );
      expect(result, ['中山', '阪神']);
    });

    test('差がちょうど4日なら残し、5日なら除く', () {
      expect(
        selectActiveCourseNames(
          ['東京', '福島'],
          {'東京': '2026-11-28', '福島': '2026-11-24'},
        ),
        ['東京', '福島'],
      );
      expect(
        selectActiveCourseNames(
          ['東京', '福島'],
          {'東京': '2026-11-28', '福島': '2026-11-23'},
        ),
        ['東京'],
      );
    });

    test('候補の並び順を保つ', () {
      final result = selectActiveCourseNames(
        ['京都', '東京'],
        {'東京': '2026-10-04', '京都': '2026-10-03'},
      );
      expect(result, ['京都', '東京']);
    });

    test('最新測定日が無い・読めない会場は除き、全部無ければ空', () {
      expect(
        selectActiveCourseNames(['東京', '京都'], {'東京': '2026-10-04'}),
        ['東京'],
      );
      expect(selectActiveCourseNames(['東京'], {'東京': '不明'}), isEmpty);
      expect(selectActiveCourseNames([], {}), isEmpty);
    });
  });
}
