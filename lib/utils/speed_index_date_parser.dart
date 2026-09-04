// lib/utils/speed_index_date_parser.dart

// [追加] フェーズ6 バックテスト・ハーネス: shutuba_table_page.dart / race_simulation_tab.dart
// に個別定義されていた_parseRaceDateForSpeedIndexを共有ユーティリティへ抽出（挙動は不変）。
// バックテストのasOf算出でも同一ロジックを使うため (v.2026.9.4)

/// raceDate文字列(例: '2026年7月30日(木)')から年月日を抽出してDateTimeを生成する
/// (スピード指数のconfidence算出用)。weather_analyzer.dartの既存パターンに倣い、
/// 区切り文字の表記ゆれ(年月日/スラッシュ等)を吸収するRegExpで抽出する。
/// 変換不能な場合はnullを返す。
DateTime? parseRaceDateForSpeedIndex(String raceDateStr) {
  final match =
      RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raceDateStr);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
