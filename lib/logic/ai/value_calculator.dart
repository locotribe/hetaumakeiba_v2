// lib/logic/ai/value_calculator.dart

class ValueCalculator {
  /// 全出走馬のスコアとオッズから「期待値」を算出します。
  static double calculateExpectedValue(
      double overallScore, double odds, double totalScoreOfAllHorses) {
    if (totalScoreOfAllHorses == 0 || odds == 0) {
      return -1.0; // 計算不能の場合は-1を返す
    }

    // 1. 総合適性スコアを正規化し、アプリ独自の「真の勝率」を算出
    final trueWinRate = overallScore / totalScoreOfAllHorses;

    // 2. 期待値を算出
    // (真の勝率 × 単勝オッズ) - 1
    final expectedValue = (trueWinRate * odds) - 1.0;

    return expectedValue;
  }
}