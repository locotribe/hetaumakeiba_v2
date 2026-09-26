import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/citation_sanitizer.dart';

void main() {
  group('stripCitations', () {
    test('直前の半角空白ごとインライン引用を除去する', () {
      expect(stripCitations('想定ペースはハイペース [cite: 2]。'), '想定ペースはハイペース。');
    });
    test('空白なしの引用も除去する', () {
      expect(stripCitations('上位の存在[cite: 2]。'), '上位の存在。');
    });
    test('複数IDの引用も除去する', () {
      expect(stripCitations('軸馬：6、15[cite: 2, 3]'), '軸馬：6、15');
    });
    test('cite_start / cite_end も除去する', () {
      expect(stripCitations('[cite_start]本命の◎[cite_end]'), '本命の◎');
    });
    test('改行は保持し、行頭の引用だけ除去する', () {
      expect(stripCitations('A\n[cite: 2]B'), 'A\nB');
    });
    test('引用がなければそのまま返す', () {
      expect(stripCitations('普通のメモ。'), '普通のメモ。');
    });
  });
}
