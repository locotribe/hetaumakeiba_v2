// test/spearman_correlation_test.dart

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/utils/spearman_correlation.dart';

void main() {
  group('tieAdjustedSpearman', () {
    test('完全一致(tieなし)は ρ=1.0 になる', () {
      final rho = tieAdjustedSpearman(
          [1.0, 2.0, 3.0, 4.0, 5.0], [1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(rho, closeTo(1.0, 1e-9));
    });

    test('完全逆順(tieなし)は ρ=-1.0 になる', () {
      final rho = tieAdjustedSpearman(
          [1.0, 2.0, 3.0, 4.0, 5.0], [5.0, 4.0, 3.0, 2.0, 1.0]);
      expect(rho, closeTo(-1.0, 1e-9));
    });

    test('tie(並走)を含む既知の順位ペアでρの既知値を検証する', () {
      // simRanks: 2位と3位が並走(tie)で平均順位2.5をそれぞれ持つケース
      final rho = tieAdjustedSpearman(
        [1.0, 2.5, 2.5, 4.0],
        [1.0, 2.0, 3.0, 4.0],
      );
      // 手計算: dA=[-1.5,0,0,1.5], dB=[-1.5,-0.5,0.5,1.5]
      // numerator=4.5, denomA=4.5, denomB=5.0 → ρ=4.5/sqrt(22.5)
      expect(rho, closeTo(4.5 / math.sqrt(22.5), 1e-9));
    });

    test('全員同順位(分散0)の場合は null を返す', () {
      final rho = tieAdjustedSpearman([2.0, 2.0, 2.0], [1.0, 2.0, 3.0]);
      expect(rho, isNull);
    });

    test('要素数2未満は null を返す', () {
      expect(tieAdjustedSpearman([1.0], [1.0]), isNull);
      expect(tieAdjustedSpearman([], []), isNull);
    });
  });
}
