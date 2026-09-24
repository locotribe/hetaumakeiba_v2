// lib/logic/training_evaluation.dart

import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

// [追加] 調教タイム個別データ移植Step1: 調教1本の独自評価（基準差・意図・鬼脚・ラップ傾き）を純粋関数化。
// 調教タイムタブ（training_time_chart_tab.dart）の private メソッドと同じ判定を、UI非依存で提供する (v.2026.9.25+26092501)

/// 基準タイム定数（調教タイムタブの現行値と同一）。
class TrainingBaseTimes {
  static const double hanro4fMiho = 54.5;
  static const double hanro4fRitto = 53.5;
  static const double wood6fMiho = 83.0;
  static const double wood6fRitto = 82.0;
  static const double wood5fMiho = 67.0;
  static const double wood5fRitto = 66.0;
  static const double wood4fMiho = 52.0;
  static const double wood4fRitto = 51.0;
  static const double oniashiMiho = 11.3;
  static const double oniashiRitto = 11.4;

  const TrainingBaseTimes._();
}

/// ラップ傾きのしきい値（秒）。
const double kLapTrendEpsilon = 0.05;

/// 追い切りの意図（ウッドのみ）。
enum TrainingIntentKind { light, practical, sharp, standard }

/// 意図の種別とラベル。
class TrainingIntent {
  final TrainingIntentKind kind;
  final String label;

  const TrainingIntent(this.kind, this.label);
}

/// 1本の調教の独自評価をまとめたもの。
class TrainingEvaluation {
  final TrainingTimeModel model;

  /// 基準の時計があるコース（坂路・ウッド）か。
  final bool comparable;

  /// 累計の先頭（全体タイム）。無ければ null。
  final double? total;

  /// 基準差（全体 − 基準）。無ければ null。負＝速い。
  final double? baseDiff;

  /// 追い切りの意図（ウッドのみ）。無ければ null。
  final TrainingIntent? intent;

  /// 鬼脚（ラスト1Fがしきい値以下）。
  final bool oniashi;

  const TrainingEvaluation({
    required this.model,
    required this.comparable,
    required this.total,
    required this.baseDiff,
    required this.intent,
    required this.oniashi,
  });
}

bool _isMiho(TrainingTimeModel t) => t.location.contains('美浦');

bool _isHanro(TrainingTimeModel t) => t.trackType.contains('坂路');

bool _isWood(TrainingTimeModel t) =>
    t.trackType.contains('ウッド') || t.trackType.contains('W');

/// 累計タイム（坂路は4F〜1F、ウッドは6F〜1F、0より大きい値のみ）。
List<double> trainingCumulatives(TrainingTimeModel t) {
  final c = <double>[];
  if (_isHanro(t)) {
    if (t.f4 != null && t.f4! > 0) c.add(t.f4!);
    if (t.f3 != null && t.f3! > 0) c.add(t.f3!);
    if (t.f2 != null && t.f2! > 0) c.add(t.f2!);
    if (t.f1 != null && t.f1! > 0) c.add(t.f1!);
  } else {
    if (t.f6 != null && t.f6! > 0) c.add(t.f6!);
    if (t.f5 != null && t.f5! > 0) c.add(t.f5!);
    if (t.f4 != null && t.f4! > 0) c.add(t.f4!);
    if (t.f3 != null && t.f3! > 0) c.add(t.f3!);
    if (t.f2 != null && t.f2! > 0) c.add(t.f2!);
    if (t.f1 != null && t.f1! > 0) c.add(t.f1!);
  }
  return c;
}

/// ラップ（累計の隣り合う差。最後のマスは1Fそのもの）。
List<double> trainingSplits(TrainingTimeModel t) {
  final c = trainingCumulatives(t);
  final splits = <double>[];
  for (int i = 0; i < c.length - 1; i++) {
    splits.add(c[i] - c[i + 1]);
  }
  if (c.isNotEmpty) splits.add(c.last);
  return splits;
}

/// 累計の先頭がどのハロンかで基準の時計を返す。無ければ null。
double? dynamicBaseTime(TrainingTimeModel t) {
  final c = trainingCumulatives(t);
  if (c.isEmpty) return null;
  final isMiho = _isMiho(t);
  final firstVal = c.first;
  if (_isHanro(t)) {
    if (t.f4 != null && t.f4! > 0 && firstVal == t.f4) {
      return isMiho ? TrainingBaseTimes.hanro4fMiho : TrainingBaseTimes.hanro4fRitto;
    }
  } else {
    if (t.f6 != null && t.f6! > 0 && firstVal == t.f6) {
      return isMiho ? TrainingBaseTimes.wood6fMiho : TrainingBaseTimes.wood6fRitto;
    }
    if (t.f5 != null && t.f5! > 0 && firstVal == t.f5) {
      return isMiho ? TrainingBaseTimes.wood5fMiho : TrainingBaseTimes.wood5fRitto;
    }
    if (t.f4 != null && t.f4! > 0 && firstVal == t.f4) {
      return isMiho ? TrainingBaseTimes.wood4fMiho : TrainingBaseTimes.wood4fRitto;
    }
  }
  return null;
}

/// 基準差（全体 − 基準）。基準が無ければ null。負＝基準より速い。
double? baseDiff(TrainingTimeModel t) {
  final base = dynamicBaseTime(t);
  final c = trainingCumulatives(t);
  if (base == null || c.isEmpty) return null;
  return c.first - base;
}

/// 基準の時計があるコース（坂路・ウッド）か。
bool isComparableCourse(TrainingTimeModel t) =>
    t.trackType == '坂路' || t.trackType == 'ウッド';

/// 追い切りの意図（ウッドのみ）。無ければ null。
TrainingIntent? trainingIntent(TrainingTimeModel t) {
  final c = trainingCumulatives(t);
  if (c.isEmpty) return null;
  if (!_isWood(t)) return null;
  final isMiho = _isMiho(t);
  final firstVal = c.first;
  final isF4Only = (t.f6 == null || t.f6 == 0) &&
      (t.f5 == null || t.f5 == 0) &&
      (t.f4 != null && t.f4! > 0 && firstVal == t.f4);
  final isF5Over = (t.f6 != null && t.f6! > 0 && firstVal == t.f6) ||
      (t.f5 != null && t.f5! > 0 && firstVal == t.f5);
  if (!isMiho && isF4Only) {
    return const TrainingIntent(TrainingIntentKind.light, '軽め調整(反応確認)');
  }
  if (!isMiho && isF5Over) {
    return const TrainingIntent(TrainingIntentKind.practical, '実戦的追い(スタミナ)');
  }
  if (isMiho && isF4Only) {
    return const TrainingIntent(TrainingIntentKind.sharp, '終い特化(キレ確認)');
  }
  if (isMiho && isF5Over) {
    return const TrainingIntent(TrainingIntentKind.standard, '標準的追い(総合力)');
  }
  return null;
}

/// 鬼脚（ラスト1Fがしきい値以下）。美浦 ≤ 11.3 / 栗東 ≤ 11.4。
bool isOniashi(TrainingTimeModel t) {
  final f1 = t.f1;
  if (f1 == null || f1 <= 0) return false;
  return _isMiho(t)
      ? f1 <= TrainingBaseTimes.oniashiMiho
      : f1 <= TrainingBaseTimes.oniashiRitto;
}

/// 各ラップ→次ラップの傾き。要素 i は splits[i] から splits[i+1] への変化。
/// -1 = 加速（速くなる）/ 0 = 横ばい / +1 = 減速（遅くなる）。しきい値 ±[kLapTrendEpsilon]。
List<int> lapTrends(TrainingTimeModel t) {
  final s = trainingSplits(t);
  final trends = <int>[];
  for (int i = 0; i < s.length - 1; i++) {
    final diff = s[i + 1] - s[i];
    if (diff < -kLapTrendEpsilon) {
      trends.add(-1);
    } else if (diff > kLapTrendEpsilon) {
      trends.add(1);
    } else {
      trends.add(0);
    }
  }
  return trends;
}

/// 突き合わせ後の1件から独自評価をまとめて作る。
TrainingEvaluation buildTrainingEvaluation(MergedTrainingEntry entry) {
  final t = toTrainingTimeModel(entry);
  final c = trainingCumulatives(t);
  final comparable = isComparableCourse(t);
  return TrainingEvaluation(
    model: t,
    comparable: comparable,
    total: c.isEmpty ? null : c.first,
    baseDiff: comparable ? baseDiff(t) : null,
    intent: comparable ? trainingIntent(t) : null,
    oniashi: isOniashi(t),
  );
}
