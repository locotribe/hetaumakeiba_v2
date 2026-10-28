// lib/logic/analysis/game_race_tuning.dart
// [追加] 展開シミュ改良Step3: レースごとのエンジンの設定の調整(案C の内の馬場・砂かぶり・傷み、案D のペースを当てる式・回ごとの散らし)。
// ペースを当てる式は原型の caseD_pace.py(eval_out/caseD_pace.json)、参照実装は paceref.py・course_rail2.py。
// 設計は memory/展開シミュ_改良案_考察.md の案C・案D (v.2026.10.28+26102803)

import 'dart:math' as math;

import 'package:hetaumakeiba_v2/logic/analysis/game_ability_builder.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_course_rail.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';

/// 案D: 出走馬の顔ぶれから「いつものペースからのずれ」(先頭の1000m通過の秒。正 = 遅い)を当てる。
class GamePacePredictor {
  GamePacePredictor._();

  /// 式の項(足す順)
  static const List<String> featureKeys = [
    'nFront',
    'nFront2',
    'earlyMin',
    'earlyMean',
    'speedIndexMean',
    'kickMean',
    'staminaMean',
    'count',
  ];

  /// 芝の係数(原型の eval_out/caseD_pace.json「芝」。校正の期間で決めた値。改良Step4 で決め直す)
  static const Map<String, double> coefTurf = {
    'const': 3.0399578271901126,
    'nFront': -0.019807022487125295,
    'nFront2': -0.0031021875215049123,
    'earlyMin': 0.6034136394169025,
    'earlyMean': -0.08878038180928668,
    'speedIndexMean': -0.032977038013725986,
    'kickMean': 1.6941926467451145,
    'staminaMean': -0.2519572455239082,
    'count': -0.04998851479802262,
  };

  /// ダートの係数(同「ダ」)
  static const Map<String, double> coefDirt = {
    'const': 2.777343513206387,
    'nFront': 0.026014413427729605,
    'nFront2': -0.04386350440321627,
    'earlyMin': 0.1531190640219435,
    'earlyMean': -0.4139668826736297,
    'speedIndexMean': -0.025152009333440698,
    'kickMean': 1.056882137495669,
    'staminaMean': -0.5614447979432508,
    'count': -0.068731867029277,
  };

  /// 前に行く馬とみなす、前に行く力の率(0=先頭〜1=最後方)の上限
  static const double frontRate = 0.15;
  static const double frontRate2 = 0.3;

  /// 1000m通過の秒のずれをペース倍率に直すときの基準の秒と乗数(Step4b のスライダーと同じ換算)
  static const double baseSeconds = 60.0;
  static const double power = 1.3;

  static double? _mean(Iterable<double?> xs) {
    double s = 0.0;
    int n = 0;
    for (final x in xs) {
      if (x != null) {
        s += x;
        n++;
      }
    }
    return n > 0 ? s / n : null;
  }

  /// 式の項。値の無い馬は数えない。どの馬にも値が無い項は null
  static Map<String, double?> featuresOf(List<GameAbilitySource> sources) {
    final er = [
      for (final s in sources)
        if (s.earlyRate != null) s.earlyRate!
    ];
    double? erMin;
    for (final x in er) {
      if (erMin == null || x < erMin) erMin = x;
    }
    return {
      'nFront': er.where((x) => x <= frontRate).length.toDouble(),
      'nFront2': er.where((x) => x <= frontRate2).length.toDouble(),
      'earlyMin': erMin,
      'earlyMean': _mean(sources.map((s) => s.earlyRate)),
      'speedIndexMean': _mean(sources.map((s) => s.speedIndex)),
      'kickMean': _mean(sources.map((s) => s.kickSeconds)),
      'staminaMean': _mean(sources.map((s) => s.staminaIndex)),
      'count': sources.length.toDouble(),
    };
  }

  /// いつものペースからのずれ(秒。正 = 遅い)。項が1つでも作れなければ null
  static double? deviationOf(List<GameAbilitySource> sources,
      {required bool isDirt}) {
    final f = featuresOf(sources);
    final c = isDirt ? coefDirt : coefTurf;
    double s = c['const']!;
    for (final k in featureKeys) {
      final v = f[k];
      if (v == null) return null;
      s += c[k]! * v;
    }
    return s;
  }

  /// 先頭の1000m通過を [deviationSeconds] 秒ずらすペース倍率
  static double paceMultOf(double baseMult, double deviationSeconds) =>
      baseMult *
      math
          .pow(baseSeconds / (baseSeconds + deviationSeconds), power)
          .toDouble();
}

/// レースごとのエンジンの設定の調整。[off] は今までと同じ結果。
class GameRaceTuning {
  /// 内ラチ付近の進みにくさ(m/s。負 = 内が良い)。GameRaceConfig.innerBias
  final double innerBias;

  /// 砂かぶり(m/s)。GameRaceConfig.kickback
  final double kickback;

  /// true なら、使用コースから作った内の馬場の傷み(GameCourseRail)を入れる
  final bool useWear;

  /// 傷んだ内を避ける境目(秒/200m)。GameRaceConfig.wearAvoid
  final double? wearAvoid;

  /// GameRaceConfig.wearAvoidOut
  final bool wearAvoidOut;

  /// 案D: 当てたペースのずれをどれだけ入れるか(1 で当てた値のまま、0 で入れない)
  final double pacePredictStrength;

  /// 案D: 回ごとに先頭の1000m通過を散らす標準偏差(秒)。0 で散らさない
  final double paceScatterSd;

  const GameRaceTuning({
    this.innerBias = 0.0,
    this.kickback = 0.0,
    this.useWear = false,
    this.wearAvoid,
    this.wearAvoidOut = false,
    this.pacePredictStrength = 0.0,
    this.paceScatterSd = 0.0,
  });

  /// 今までと同じ(どれも効かせない)
  static const GameRaceTuning off = GameRaceTuning();

  /// 原型で決めた仮の値(芝)。内が少し良い −0.05 m/s、傷み(0.04秒/200m より傷んだ所は避ける)、ペースを当てる、散らし1秒。改良Step4 で決め直す
  static const GameRaceTuning provisionalTurf = GameRaceTuning(
    innerBias: -0.05,
    useWear: true,
    wearAvoid: 0.04,
    pacePredictStrength: 1.0,
    paceScatterSd: 1.0,
  );

  /// 原型で決めた仮の値(ダート)。砂かぶり 0.3 m/s、ペースを当てる、散らし1秒
  static const GameRaceTuning provisionalDirt = GameRaceTuning(
    kickback: 0.3,
    pacePredictStrength: 1.0,
    paceScatterSd: 1.0,
  );

  /// アプリで使う値。改良Step3 は仕組みを入れるだけなので、芝・ダートとも [off](改良Step4 で効かせる)
  static GameRaceTuning of({required bool isDirt}) => off;

  /// [base] に、このレースの調整を入れた設定。[rail] は使用コースと傷み、[paceDeviation] は当てたペースのずれ(秒)
  GameRaceConfig apply(
    GameRaceConfig base, {
    GameCourseRailInfo? rail,
    double? paceDeviation,
  }) {
    var c = base;
    if (innerBias != 0.0) c = c.copyWith(innerBias: innerBias);
    if (kickback != 0.0) c = c.copyWith(kickback: kickback);
    if (useWear && rail != null) {
      c = c.copyWith(
        wearThresholds: rail.wearThresholds,
        wearThresholdsCurve: rail.wearThresholdsCurve,
        wearAvoid: wearAvoid,
        wearAvoidOut: wearAvoidOut,
      );
    }
    if (pacePredictStrength != 0.0 && paceDeviation != null) {
      c = c.copyWith(
          paceMult: GamePacePredictor.paceMultOf(
              c.paceMult, pacePredictStrength * paceDeviation));
    }
    return c;
  }
}