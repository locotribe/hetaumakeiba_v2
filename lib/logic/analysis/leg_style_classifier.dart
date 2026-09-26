// lib/logic/analysis/leg_style_classifier.dart
// [修正] 脚質判定の共通関数（唯一の真実）。TARGETの3グループ方式(頭数÷3・1グループ最大5頭)＋「道中で先頭=逃げ」に統一。統計集計と馬別プロフィールの基底4分類をここへ集約。マクリ/自在は基底に含めない (v.2026.9.26+26092606)

/// 脚質の基底カテゴリ（4分類）と不明値。
const String legStyleNige = '逃げ';
const String legStyleSenko = '先行';
const String legStyleSashi = '差し';
const String legStyleOikomi = '追込';
const String legStyleUnknown = '不明';

/// コーナー通過順の文字列を数値の並びに解析する（非数値トークンは除外）。
/// 例: '3-3-2-1' -> [3,3,2,1] / '5-4' -> [5,4] / '3-2-*' -> [3,2]。
List<int> parseCornerPositions(String? cornerStr) {
  if (cornerStr == null) return const [];
  final trimmed = cornerStr.trim();
  if (trimmed.isEmpty) return const [];
  final result = <int>[];
  for (final part in trimmed.split('-')) {
    final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) continue;
    final v = int.tryParse(digits);
    if (v != null && v > 0) result.add(v);
  }
  return result;
}

/// コーナー通過順の文字列から最終コーナーの順位を取り出す（取れなければ null）。
int? lastCornerPosition(String? cornerStr) {
  final corners = parseCornerPositions(cornerStr);
  return corners.isEmpty ? null : corners.last;
}

/// 1レース分の脚質を4分類で返す（マクリ/自在を含まない基底判定）。
/// - 逃げ: 最終コーナーを除くいずれかのコーナーで1位（道中で先頭）。
///   コーナーが1つしかない場合は、そのコーナーで1位なら逃げ。
/// - 上記以外は最終コーナー位置を TARGET の3グループ方式で分類する。
///   groupSize = ceil(頭数 / 3)（ただし最大5頭）。
///   第1グループ(<=groupSize)=先行 / 第2グループ(<=groupSize*2)=差し / 第3グループ=追込。
/// - コーナー順位が取れない、または頭数が0以下の場合は「不明」。
String classifyLegStyle(String? cornerStr, int fieldSize) {
  final corners = parseCornerPositions(cornerStr);
  if (corners.isEmpty || fieldSize <= 0) return legStyleUnknown;

  // 逃げ: 道中(最終コーナー以外)で先頭。コーナーが1つのみならそのコーナーで先頭。
  final ledInRace = corners.length >= 2
      ? corners.sublist(0, corners.length - 1).contains(1)
      : corners.first == 1;
  if (ledInRace) return legStyleNige;

  final last = corners.last;

  // TARGETの3グループ方式（頭数÷3・1グループ最大5頭）
  final third = (fieldSize / 3).ceil();
  final groupSize = third > 5 ? 5 : third;
  if (last <= groupSize) return legStyleSenko; // 第1グループ = 先行
  if (last <= groupSize * 2) return legStyleSashi; // 第2グループ = 差し
  return legStyleOikomi; // 第3グループ = 追込
}
