// test/leg_style_classifier_test.dart
// [修正] 脚質共通判定関数の単体テスト。TARGET3グループ方式＋道中先頭=逃げ に更新 (v.2026.9.26+26092606)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_classifier.dart';

void main() {
  group('parseCornerPositions / lastCornerPosition', () {
    test('数値の並びに解析（非数値は除外）', () {
      expect(parseCornerPositions('3-3-2-1'), [3, 3, 2, 1]);
      expect(parseCornerPositions('5-4'), [5, 4]);
      expect(parseCornerPositions('3-2-*'), [3, 2]);
      expect(parseCornerPositions(''), isEmpty);
      expect(parseCornerPositions(null), isEmpty);
    });
    test('最終コーナー順位', () {
      expect(lastCornerPosition('3-3-2-1'), 1);
      expect(lastCornerPosition('10-11'), 11);
      expect(lastCornerPosition('abc'), isNull);
    });
  });

  group('逃げ（道中で先頭）', () {
    test('道中で1位なら逃げ', () {
      expect(classifyLegStyle('1-1-1-1', 16), legStyleNige);
      expect(classifyLegStyle('1-2-3-5', 16), legStyleNige); // 1角先頭
      expect(classifyLegStyle('1', 5), legStyleNige); // 1コーナーのみ先頭
    });
    test('道中後方→最後だけ先頭は逃げにしない（第1グループ=先行）', () {
      expect(classifyLegStyle('8-7-6-1', 16), legStyleSenko);
    });
  });

  group('TARGET3グループ方式（16頭: 先行<=5 / 差し<=10 / 追込>=11）', () {
    test('各グループに落ちる', () {
      expect(classifyLegStyle('5-5-5-5', 16), legStyleSenko);
      expect(classifyLegStyle('6-6-6-6', 16), legStyleSashi);
      expect(classifyLegStyle('10-10-10-10', 16), legStyleSashi);
      expect(classifyLegStyle('11-11-11-11', 16), legStyleOikomi);
    });
  });

  group('少頭数（6頭: 先行<=2 / 差し<=4 / 追込>=5）', () {
    test('境界', () {
      expect(classifyLegStyle('2-2', 6), legStyleSenko);
      expect(classifyLegStyle('4-4', 6), legStyleSashi);
      expect(classifyLegStyle('5-5', 6), legStyleOikomi);
    });
  });

  group('不明', () {
    test('順位が取れない/頭数0以下は不明', () {
      expect(classifyLegStyle(null, 16), legStyleUnknown);
      expect(classifyLegStyle('', 16), legStyleUnknown);
      expect(classifyLegStyle('abc', 16), legStyleUnknown);
      expect(classifyLegStyle('3-2-1', 0), legStyleUnknown);
    });
  });
}
