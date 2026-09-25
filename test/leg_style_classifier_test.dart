// test/leg_style_classifier_test.dart
// [追加] 脚質共通判定関数の単体テスト (v.2026.9.26+26092602)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_classifier.dart';

void main() {
  group('lastCornerPosition', () {
    test('通常の4コーナー文字列は末尾の順位を返す', () {
      expect(lastCornerPosition('3-3-2-1'), 1);
      expect(lastCornerPosition('5-4'), 4);
      expect(lastCornerPosition('10-11'), 11);
    });
    test('末尾が非数値なら手前の数値トークンを返す', () {
      expect(lastCornerPosition('3-2-*'), 2);
    });
    test('取れない場合は null', () {
      expect(lastCornerPosition(null), isNull);
      expect(lastCornerPosition(''), isNull);
      expect(lastCornerPosition('--'), isNull);
      expect(lastCornerPosition('abc'), isNull);
    });
  });

  group('classifyLegStyle 逃げ特例（少頭数対策）', () {
    test('最終コーナー1位は頭数に関わらず逃げ', () {
      expect(classifyLegStyle('1', 5), legStyleNige);
      expect(classifyLegStyle('2-1', 6), legStyleNige);
      expect(classifyLegStyle('3-2-1', 18), legStyleNige);
    });
  });

  group('classifyLegStyle 率ベース（16頭立て）', () {
    test('率の各帯に正しく落ちる', () {
      expect(classifyLegStyle('2-2-2-2', 16), legStyleNige);
      expect(classifyLegStyle('6-6-6-6', 16), legStyleSenko);
      expect(classifyLegStyle('7-7-7-7', 16), legStyleSashi);
      expect(classifyLegStyle('13-13-13-13', 16), legStyleOikomi);
    });
  });

  group('classifyLegStyle 境界値', () {
    test('率がちょうど0.40は先行、0.80は差し', () {
      expect(classifyLegStyle('2', 5), legStyleSenko);
      expect(classifyLegStyle('4', 5), legStyleSashi);
      expect(classifyLegStyle('5', 5), legStyleOikomi);
    });
  });

  group('classifyLegStyle 不明', () {
    test('順位が取れない/頭数0以下は不明', () {
      expect(classifyLegStyle(null, 16), legStyleUnknown);
      expect(classifyLegStyle('', 16), legStyleUnknown);
      expect(classifyLegStyle('abc', 16), legStyleUnknown);
      expect(classifyLegStyle('3-2-1', 0), legStyleUnknown);
      expect(classifyLegStyle('3-2-1', -1), legStyleUnknown);
    });
  });
}
