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
