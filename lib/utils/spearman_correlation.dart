// lib/utils/spearman_correlation.dart

// [追加] フェーズ6 バックテスト・ハーネス §8-3: tie(並走・同着)を含む2系列間の
// スピアマン順位相関を「順位変換後のピアソン相関(tie対応スピアマン)」で自前算出する。
// 外部依存を増やさずdart:mathのみで実装する (v.2026.9.4)

import 'dart:math' as math;

/// [ranksA] と [ranksB] は同じ長さの「順位」列（tieは平均順位で表現してよい）。
/// ρ = Σ((r_i-r̄)(s_i-s̄)) / sqrt(Σ(r_i-r̄)² · Σ(s_i-s̄)²)
/// 要素数2未満、またはどちらか一方の分散が0(全員同順位)の場合はnullを返す。
double? tieAdjustedSpearman(List<double> ranksA, List<double> ranksB) {
  assert(ranksA.length == ranksB.length);
  final n = ranksA.length;
  if (n < 2) return null;

  final meanA = ranksA.reduce((a, b) => a + b) / n;
  final meanB = ranksB.reduce((a, b) => a + b) / n;

  double numerator = 0.0;
  double denomA = 0.0;
  double denomB = 0.0;
  for (int i = 0; i < n; i++) {
    final da = ranksA[i] - meanA;
    final db = ranksB[i] - meanB;
    numerator += da * db;
    denomA += da * da;
    denomB += db * db;
  }

  if (denomA == 0.0 || denomB == 0.0) return null;
  return numerator / math.sqrt(denomA * denomB);
}
