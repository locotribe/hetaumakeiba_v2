// lib/logic/analysis/lift_match_score.dart

// [追加] 総合シンクロ率と血統クロス Step1: 結果分析の総合シンクロ率で使う、ローテ・血統の点数（複勝率の倍率×50、100点で頭打ち）と表示の文字を出す部品。DBやネットには触らない (v.2026.10.16+26101614)

import 'package:hetaumakeiba_v2/logic/analysis/factor_candidate_selector.dart';
import 'package:hetaumakeiba_v2/logic/analysis/past_race_lift.dart';

/// 例が少ない・分からないときの点数（中立）。
const double kNeutralLiftScore = 50.0;

/// 倍率1.00倍あたりの点数。
const double kLiftScorePerLift = 50.0;

/// 点数の上限。
const double kMaxLiftScore = 100.0;

/// 点数に使う倍率の指標（複勝率の倍率）。
const String kLiftScoreMetric = FactorMetric.show;

/// 血統の点数の、父の重み（父3:母父1）。
const double kSireScoreWeight = 3.0;

/// 血統の点数の、母父の重み（父3:母父1）。
const double kDamSireScoreWeight = 1.0;

/// 倍率を点数にする。倍率×50 を 0〜100点に収める。
double liftToMatchScore(double lift) {
  final score = lift * kLiftScorePerLift;
  if (score < 0) return 0.0;
  if (score > kMaxLiftScore) return kMaxLiftScore;
  return score;
}

/// 区分（路線・父・母父）1つでの点数。
class LiftMatchScore {
  /// 点数（0〜100）
  final double score;

  /// 点数に使った倍率（複勝率の倍率）。中立（50点）にしたときは null
  final double? lift;

  /// 今回の馬の区分。区分が決まらない馬は null
  final PastRaceLiftRow? row;

  const LiftMatchScore({
    required this.score,
    required this.lift,
    required this.row,
  });

  /// 倍率の文字（例 '1.42倍'）。
  /// 倍率が無いとき、区分が決まらなければ [unknownText]、区分はあるが過去の例が少なければ '例なし'。
  String liftText({String unknownText = '不明'}) {
    final value = lift;
    if (value != null) return '${value.toStringAsFixed(2)}倍';
    return row == null ? unknownText : '例なし';
  }
}

/// [table] での [horseId] の点数。
///
/// - 区分が決まらない（前走・血統が分からない）馬、区分の過去の出走が [kLiftRowMinTotal] 頭未満の馬、
///   過去の出走全体の複勝率が0（数えた出走が無い）ときは 50点（中立）で、倍率は null。
/// - それ以外は、区分の複勝率の倍率×50（100点で頭打ち）。
LiftMatchScore liftMatchScoreOf(PastRaceLiftTable table, String horseId) {
  final row = table.rowOf(horseId);
  if (row == null ||
      row.total < kLiftRowMinTotal ||
      table.baseline.rate(kLiftScoreMetric) <= 0) {
    return LiftMatchScore(score: kNeutralLiftScore, lift: null, row: row);
  }
  final lift = table.liftsOf(row)[kLiftScoreMetric] ?? 0.0;
  return LiftMatchScore(score: liftToMatchScore(lift), lift: lift, row: row);
}

/// 血統（父と母父）の点数。
class PedigreeMatchScore {
  /// 点数（父3:母父1 で合わせたもの。0〜100）
  final double score;

  /// 父の点数
  final LiftMatchScore sire;

  /// 母父の点数
  final LiftMatchScore damSire;

  const PedigreeMatchScore({
    required this.score,
    required this.sire,
    required this.damSire,
  });

  /// 表示の文字（例 '父1.42倍・母父0.80倍'）。父も母父も区分が決まらない（血統が無い）ときは 'データなし'。
  String get diagText {
    if (sire.row == null && damSire.row == null) return 'データなし';
    return '父${sire.liftText()}・母父${damSire.liftText()}';
  }
}

/// [horseId] の血統の点数。父の表 [sireTable] と母父の表 [damSireTable] の点数を 父3:母父1 で合わせる。
PedigreeMatchScore pedigreeMatchScoreOf({
  required PastRaceLiftTable sireTable,
  required PastRaceLiftTable damSireTable,
  required String horseId,
}) {
  final sire = liftMatchScoreOf(sireTable, horseId);
  final damSire = liftMatchScoreOf(damSireTable, horseId);
  final score = (sire.score * kSireScoreWeight +
          damSire.score * kDamSireScoreWeight) /
      (kSireScoreWeight + kDamSireScoreWeight);
  return PedigreeMatchScore(score: score, sire: sire, damSire: damSire);
}

/// 複勝率がいちばん高い区分の表示名（過去の出走が [kLiftRowMinTotal] 頭以上で率が0より大きい区分から選ぶ）。無ければ [none]。
String bestLiftRowLabel(PastRaceLiftTable table, {String none = 'なし'}) {
  final rows = table.topRows(metric: kLiftScoreMetric, take: 1);
  return rows.isEmpty ? none : rows.first.label;
}
