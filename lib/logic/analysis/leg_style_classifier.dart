// lib/logic/analysis/leg_style_classifier.dart
// [追加] 脚質判定の共通関数（唯一の真実）。統計集計と馬別プロフィールの基底4分類をここへ集約する。マクリ/自在は基底に含めず、馬別プロフィール側で被せる (v.2026.9.26+26092602)

/// 脚質の基底カテゴリ（4分類）と不明値。
const String legStyleNige = '逃げ';
const String legStyleSenko = '先行';
const String legStyleSashi = '差し';
const String legStyleOikomi = '追込';
const String legStyleUnknown = '不明';

/// コーナー通過順の文字列から最終コーナーの順位を取り出す。
/// '-' 区切りの末尾から見て、最初に数字を含むトークンを最終コーナー順位とする。
/// 例: '3-3-2-1' -> 1 / '5-4' -> 4 / '10-11' -> 11 / 取れなければ null。
int? lastCornerPosition(String? cornerStr) {
  if (cornerStr == null) return null;
  final trimmed = cornerStr.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('-');
  for (int i = parts.length - 1; i >= 0; i--) {
    final digits = parts[i].replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) continue;
    final v = int.tryParse(digits);
    if (v != null && v > 0) return v;
  }
  return null;
}

/// 1レース分の脚質を4分類で返す（マクリ/自在を含まない基底判定）。
/// - 特例: 最終コーナー1位は頭数に関わらず「逃げ」。
/// - それ以外は率(最終コーナー位置 / 頭数): <=0.15 逃げ / <=0.40 先行 / <=0.80 差し / それ以外 追込。
/// - 順位が取れない、または頭数が0以下の場合は「不明」。
String classifyLegStyle(String? cornerStr, int fieldSize) {
  final pos = lastCornerPosition(cornerStr);
  if (pos == null || fieldSize <= 0) return legStyleUnknown;
  if (pos == 1) return legStyleNige; // 特例: 最終コーナー1位は無条件で逃げ
  final rate = pos / fieldSize;
  if (rate <= 0.15) return legStyleNige;
  if (rate <= 0.40) return legStyleSenko;
  if (rate <= 0.80) return legStyleSashi;
  return legStyleOikomi;
}
