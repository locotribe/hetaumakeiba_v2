// lib/utils/memo_csv_util.dart

// [追加] CSVメモ入出力改善: 予想メモ/回顧メモCSVのファイル名を組み立てる共通処理 (v.2026.9.24+26092401)

/// ファイル名に使えない文字を取り除く。
/// 禁止文字（\ / : * ? " < > |）と制御文字・改行・タブを削除し、前後空白を除く。
String sanitizeForFileName(String input) {
  final removed = input.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '');
  return removed.trim();
}

/// 予想メモ/回顧メモCSVのファイル名を「レースID_日付_レース名_種別.csv」で作る。
/// [raceDate] は和文（例: 2025年5月24日）をそのまま使う（禁止文字だけ除去）。
/// [raceName] は禁止文字を除いたうえで、長すぎる場合は40文字で切る。
/// 空になった要素は詰めてアンダースコアが連続しないようにする。
String buildMemoCsvFileName({
  required String raceId,
  required String raceDate,
  required String raceName,
  required String suffix,
}) {
  final date = sanitizeForFileName(raceDate);
  var name = sanitizeForFileName(raceName);
  if (name.length > 40) {
    name = name.substring(0, 40);
  }
  final parts = <String>[
    raceId.trim(),
    date,
    name,
    suffix,
  ].where((e) => e.isNotEmpty).toList();
  return '${parts.join('_')}.csv';
}

// [追加] T8: 取り込む予想メモCSVの表記揺れを吸収する純粋関数 (v.2026.9.27+26092713)
//
// Gemini等が出力するCSVは、改行がLFのみ・行末にMarkdown由来の空白・
// 先頭に「# 見出し」やコードフェンス(```)が付く、といったクセがある。
// これらを吸収し、予想メモCSVのヘッダー行以降のみを LF 区切りで返す。
//  - 先頭のUTF-8 BOMを除去
//  - 改行コードを LF(\n) に正規化（CRLF/CR にも対応）
//  - ヘッダー行（各セルを trim して一致判定）より前の行（見出し・フェンス・空行）を捨てる
//  - 以降の行のうち ``` で始まる行（コードフェンス）と末尾の空行を捨てる
// ヘッダー行が見つからない場合は LF 正規化済みの全文をそのまま返し、
// 取り込み側の厳格なヘッダー判定に委ねる（回顧メモCSV・旧形式はそこで弾かれる）。
String normalizeImportedPredictionCsv(String input) {
  const headerLine =
      'raceId,horseId,horseNumber,horseName,predictionMemo';

  var s = input;
  if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
    s = s.substring(1); // BOM除去
  }
  s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n'); // 改行正規化

  final lines = s.split('\n');
  var headerIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    final cells = lines[i].split(',').map((e) => e.trim()).toList();
    if (cells.join(',') == headerLine) {
      headerIdx = i;
      break;
    }
  }
  if (headerIdx < 0) {
    return s;
  }

  final body = <String>[];
  for (var i = headerIdx; i < lines.length; i++) {
    if (lines[i].trim().startsWith('```')) continue; // コードフェンス除去
    body.add(lines[i]);
  }
  while (body.isNotEmpty && body.last.trim().isEmpty) {
    body.removeLast(); // 末尾の空行除去
  }
  return body.join('\n');
}
