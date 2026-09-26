// [追加] T8: AI出力に混入する引用記号を取り込み時に除去する純粋関数 (v.2026.9.27+26092713)
//
// Gemini などが付ける角括弧付き出典表記（例: [cite: 2] / [cite: 2, 3] /
// [cite_start] / [cite_end]）を、直前の半角空白・タブごと取り除く。
// メモ本文を汚さないための取り込み用サニタイザ。DB/I/Oなし・純粋関数。
// 改行は消さない（先行空白は [ \t] のみを対象にし、行結合しないようにする）。
final RegExp _citationPattern = RegExp(r'[ \t]*\[cite[^\]]*\]');

/// 入力文字列から [cite ...] 形式の出典表記をすべて取り除いて返す。
String stripCitations(String input) {
  return input.replaceAll(_citationPattern, '');
}
