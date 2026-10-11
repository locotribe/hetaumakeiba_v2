// lib/logic/ai_export/ai_prize_summary.dart

// [追加] AI分析データ 天気・コース追加 Step2: 過去成績の賞金列（netkeiba・万円・重賞は付加賞込み）から通算獲得賞金を数える純粋ロジック。金額の読み取りは earned_prize_calculator.dart の parsePrizeInThousandYen を使う。収得賞金（クラス判定用）とは別の値。DB・画面・通信には触れない (v.2026.10.11+26101102)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 通算獲得賞金の集計結果。
class AiPrizeSummary {
  /// 賞金の合計（千円）。賞金のある走が1つも無ければ null
  final int? totalThousandYen;

  /// 賞金のある走の数
  final int runsWithPrize;

  /// 過去成績の件数（取消・除外を含む）
  final int totalRuns;

  const AiPrizeSummary({
    required this.totalThousandYen,
    required this.runsWithPrize,
    required this.totalRuns,
  });
}

/// 過去成績の賞金列を合計する。空・読めない・0以下の賞金は数えない。
AiPrizeSummary summarizeAiPrize(List<HorseRaceRecord> records) {
  int total = 0;
  int runsWithPrize = 0;
  for (final record in records) {
    final value = parsePrizeInThousandYen(record.prizeMoney);
    if (value == null || value <= 0) continue;
    total += value;
    runsWithPrize++;
  }
  return AiPrizeSummary(
    totalThousandYen: runsWithPrize == 0 ? null : total,
    runsWithPrize: runsWithPrize,
    totalRuns: records.length,
  );
}

/// 千円の整数を、万円の小数1桁・3桁区切りの文字列にする（15801 → '1,580.1'）。null は '-'。
String formatAiPrizeMan(int? thousandYen) {
  if (thousandYen == null) return '-';
  final negative = thousandYen < 0;
  final absolute = thousandYen.abs();
  final whole = absolute ~/ kThousandYenPerMan;
  final tenth = absolute % kThousandYenPerMan;
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer.$tenth';
}
