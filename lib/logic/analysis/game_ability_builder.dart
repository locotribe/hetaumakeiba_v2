// lib/logic/analysis/game_ability_builder.dart
// [追加] 展開シミュゲーム式移植Step1: アプリの指標(スピード指数・前に行く力・末脚・スタミナ指数・騎手の3着内率)から、
// ゲーム式エンジンの能力値を作る純粋ロジック。設計は memory/展開シミュ_ゲーム式移植_設計書.md の5章・7-1 (v.2026.10.27+26102701)

import 'dart:math' as math;

import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';

/// 1頭ぶんの元の値。分からない値は null。
class GameAbilitySource {
  /// スピード指数(直近5走の重み付き平均。HorseSpeedIndex.recentAvgIndex)
  final double? speedIndex;

  /// スピード指数の信頼度(0.0〜1.0。HorseSpeedIndex.confidence)
  final double? speedIndexConfidence;

  /// 前に行く力の率(0.0=先頭〜1.0=最後方。HorseEarlyPosition.rate)
  final double? earlyRate;

  /// 割引き後の末脚(秒。HorseFinishKick.kickSeconds)
  final double? kickSeconds;

  /// スタミナ指数(0.0〜1.0。HorseSimulationParams.staminaIndex)
  final double? staminaIndex;

  /// 騎手の3着内率(0.0〜1.0。JockeyStats.overallStats.showRate ÷ 100)
  final double? jockeyShowRate;

  /// [追加] 展開シミュ改良Step2(案B): 適性の点数(GameAptitude.scoresOf。レースの中で平均を引いた値。正 = 有利) (v.2026.10.28+26102802)
  final double? aptitudeScore;

  /// [追加] 展開シミュ改良Step2(斤量): 今回の斤量(kg) (v.2026.10.28+26102802)
  final double? carriedWeight;

  /// [追加] 展開シミュ改良Step2(斤量): 直近5走(芝・ダートだけ)の斤量の平均(kg。GameAptitudeRaw.pastCarriedWeight) (v.2026.10.28+26102802)
  final double? pastCarriedWeight;

  const GameAbilitySource({
    this.speedIndex,
    this.speedIndexConfidence,
    this.earlyRate,
    this.kickSeconds,
    this.staminaIndex,
    this.jockeyShowRate,
    // [追加] 展開シミュ改良Step2 (v.2026.10.28+26102802)
    this.aptitudeScore,
    this.carriedWeight,
    this.pastCarriedWeight,
  });
}

/// [追加] 展開シミュ改良Step2: 能力値の作り方の調整(案B の適性の点数・斤量のスキル、案A のスタミナ・揺らぎ)。
/// [off] は今までと同じ結果。設計は memory/展開シミュ_改良案_考察.md の案A・案B・斤量 (v.2026.10.28+26102802)
class GameAbilityTuning {
  /// 適性の点数1あたりの、終盤の速度加算(m/s)。原型の apt_k
  final double aptitudeStrength;

  /// 斤量のスキル: 最も重い馬との差 1kg あたりの秒(2000mあたり。距離に比例)。原型の wc_sec
  final double weightSecondsPerKg;

  /// true なら、過去走の斤量の補正もする(直近5走の斤量の平均の、レースの中の平均との差を戻す。原型の wc_norm)
  final bool weightPastNormalize;

  /// スタミナに全馬一律に足す値(原型の stamina_add)
  final double staminaAdd;

  /// 当日の出来の、終盤の速度加算の揺らぎの標準偏差(m/s。原型の speed_sd)
  final double speedNoiseSd;

  const GameAbilityTuning({
    this.aptitudeStrength = 0.0,
    this.weightSecondsPerKg = 0.0,
    this.weightPastNormalize = false,
    this.staminaAdd = 0.0,
    this.speedNoiseSd = GameAbilityBuilder.speedNoiseSd,
  });

  /// 今までと同じ(どれも効かせない)
  static const GameAbilityTuning off = GameAbilityTuning();

  /// 原型で決めた仮の値(芝)。適性の強さ0.8、斤量0.2秒/kg+過去走の補正、スタミナ+150、揺らぎ0.25。改良Step4 で決め直す
  static const GameAbilityTuning provisionalTurf = GameAbilityTuning(
    aptitudeStrength: 0.8,
    weightSecondsPerKg: 0.2,
    weightPastNormalize: true,
    staminaAdd: 150.0,
    speedNoiseSd: 0.25,
  );

  /// 原型で決めた仮の値(ダート)。適性の強さ1.6、ほかは芝と同じ
  static const GameAbilityTuning provisionalDirt = GameAbilityTuning(
    aptitudeStrength: 1.6,
    weightSecondsPerKg: 0.2,
    weightPastNormalize: true,
    staminaAdd: 150.0,
    speedNoiseSd: 0.25,
  );

  /// アプリで使う値。改良Step2〜3 は仕組みを入れるだけなので、芝・ダートとも [off](改良Step4 で効かせる)
  static GameAbilityTuning of({required bool isDirt}) => off;
}

class GameAbilityBuilder {
  GameAbilityBuilder._();

  /// スピード指数の平均の馬の、終盤の速度加算(m/s)。ゲームのスピード800に当たる
  static final double speedBase = 0.002 * math.sqrt(500.0 * 800.0);

  /// スピード指数1点あたりの速度加算(m/s)。実測で決めた値
  static const double speedPerIndexPoint = 0.06;

  /// 画面のスピードで、スピード指数1点あたりの値
  static const double speedDisplayPerPoint = 25.0;

  /// スピード指数がどの馬にも無いときの平均
  static const double defaultSpeedIndex = 60.0;

  /// 値が無いときの既定値
  static const double defaultEarlyRate = 0.5;
  static const double defaultStaminaIndex = 0.35;
  static const double defaultKickSeconds = 0.0;
  static const double defaultJockeyShowRate = 0.2;

  /// 当日の出来の揺らぎ(標準偏差)
  static const double speedNoiseSd = 0.5;
  static const double styleNoiseSd = 0.5;
  static const double formNoiseSd = 0.15;

  /// [追加] 展開シミュ改良Step2(斤量): 実際の秒 ÷ エンジンの秒(斤量の秒をエンジンの時間に直すのに使う) (v.2026.10.28+26102802)
  static const double weightTimeScale = 1.2;

  /// 出走馬全員の元の値から能力値を作る(馬の順は入力と同じ)。
  /// [修正] 展開シミュ改良Step2: [tuning] で適性の点数・斤量のスキル・スタミナ・揺らぎを調整する。斤量のスキルには [distance](m)が要る。
  /// 既定([GameAbilityTuning.off])は今までと同じ (v.2026.10.28+26102802)
  static List<GameHorseAbility> build(
    List<GameAbilitySource> sources, {
    GameAbilityTuning tuning = GameAbilityTuning.off,
    double? distance,
  }) {
    // [追加] 展開シミュ改良Step2(斤量): 軽い馬ほど得する秒(実際の秒。最も重い馬との差)と、過去走の斤量の補正の秒。
    // 斤量が分からない馬は0。原型 hook_apt.py の wc_sec・wc_norm と同じ (v.2026.10.28+26102802)
    final weightGains = List<double>.filled(sources.length, 0.0);
    final hasWeightSkill = tuning.weightSecondsPerKg != 0.0 && distance != null;
    if (hasWeightSkill) {
      double? maxWc;
      double pastSum = 0.0;
      int pastN = 0;
      for (final s in sources) {
        final w = s.carriedWeight;
        if (w != null && (maxWc == null || w > maxWc)) maxWc = w;
        final p = s.pastCarriedWeight;
        if (p != null) {
          pastSum += p;
          pastN++;
        }
      }
      final pastMean = pastN > 0 ? pastSum / pastN : null;
      final k = tuning.weightSecondsPerKg;
      for (int i = 0; i < sources.length; i++) {
        final w = sources[i].carriedWeight;
        double g = (w != null && maxWc != null)
            ? k * (maxWc - w) * distance / 2000.0
            : 0.0;
        final p = sources[i].pastCarriedWeight;
        if (tuning.weightPastNormalize && p != null && pastMean != null) {
          g = g + k * (p - pastMean) * distance / 2000.0;
        }
        weightGains[i] = g;
      }
    }

    double sum = 0.0;
    int count = 0;
    for (final s in sources) {
      if (s.speedIndex != null) {
        sum += s.speedIndex!;
        count++;
      }
    }
    final mean = count > 0 ? sum / count : defaultSpeedIndex;

    final out = <GameHorseAbility>[];
    // [修正] 展開シミュ改良Step2: 馬の番号が要るので、for の形を変えた (v.2026.10.28+26102802)
    for (int i = 0; i < sources.length; i++) {
      final s = sources[i];
      final conf = (s.speedIndex != null && s.speedIndexConfidence != null)
          ? s.speedIndexConfidence!
          : 0.0;
      final siEff =
          mean + (s.speedIndex != null ? (s.speedIndex! - mean) * conf : 0.0);
      final rate = s.earlyRate ?? defaultEarlyRate;
      final st = s.staminaIndex ?? defaultStaminaIndex;
      final kick = s.kickSeconds ?? defaultKickSeconds;
      final jt = s.jockeyShowRate ?? defaultJockeyShowRate;
      // [追加] 展開シミュ改良Step2: 終盤の速度加算に、適性の点数(案B) → 斤量のスキルの順で足す(原型 hook_apt.py と同じ順) (v.2026.10.28+26102802)
      double speedAdd = speedBase + speedPerIndexPoint * (siEff - mean);
      if (tuning.aptitudeStrength != 0.0) {
        speedAdd = speedAdd + tuning.aptitudeStrength * (s.aptitudeScore ?? 0.0);
      }
      if (hasWeightSkill) {
        // 実際の秒をエンジンの秒にし、終盤(距離の3分の1)の速さの差にする
        final vb = 22.0 - distance / 1000.0;
        speedAdd +=
            vb * vb * (weightGains[i] / weightTimeScale) / (distance / 3.0);
      }
      // [追加] 展開シミュ改良Step2(案A): スタミナを全馬一律に足す (v.2026.10.28+26102802)
      double stamina = math.max(1.0, -200.0 + 600.0 * st);
      if (tuning.staminaAdd != 0.0) {
        stamina = math.max(1.0, stamina + tuning.staminaAdd);
      }
      // [追加] 展開シミュ改良Step2(案A): 揺らぎの大きさは、揺らぎの倍率に [GameAbilityTuning.speedNoiseSd] ÷ [speedNoiseSd] をかけて変える (v.2026.10.28+26102802)
      double noiseScale = 1.0 + (1.0 - conf);
      if (tuning.speedNoiseSd != speedNoiseSd) {
        noiseScale = noiseScale * (tuning.speedNoiseSd / speedNoiseSd);
      }
      out.add(GameHorseAbility(
        // [修正] 展開シミュ改良Step2: speedAdd・stamina・noiseScale は上で作った値 (v.2026.10.28+26102802)
        speedAdd: speedAdd,
        stamina: stamina,
        power: (800.0 + 800.0 * (0.5 - rate)).clamp(200.0, 1600.0).toDouble(),
        guts: (600.0 + 600.0 * kick).clamp(100.0, 2000.0).toDouble(),
        wit: (600.0 + 4000.0 * (jt - 0.2)).clamp(150.0, 1600.0).toDouble(),
        style: styleOfRate(rate),
        noiseScale: noiseScale,
        speedDisplay: 800.0 + speedDisplayPerPoint * (siEff - mean),
      ));
    }
    return out;
  }

  /// 前に行く力の率(0.0=先頭〜1.0=最後方)を、脚質の連続値(0.0=逃げ〜3.0=追込)にする。
  static double styleOfRate(double rate) {
    const xs = [0.0, 0.12, 0.35, 0.65, 0.9, 1.0];
    const ys = [0.0, 0.0, 1.0, 2.0, 3.0, 3.0];
    final r = rate.clamp(0.0, 1.0).toDouble();
    for (int k = 0; k < xs.length - 1; k++) {
      if (r <= xs[k + 1]) {
        final w = xs[k + 1] > xs[k] ? (r - xs[k]) / (xs[k + 1] - xs[k]) : 0.0;
        return ys[k] + (ys[k + 1] - ys[k]) * w;
      }
    }
    return ys.last;
  }

  /// 標準正規乱数(ボックス＝ミュラー法)。乱数を2つ使う。
  static double normal(GameRaceRandom random) {
    final u1 = 1.0 - random.nextDouble();
    final u2 = random.nextDouble();
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
  }

  /// 1回ぶんの当日の出来を加える。馬の順に、速度・脚質・スタミナ・根性・パワーの順で乱数を引く。
  static List<GameHorseAbility> applyFormNoise(
    List<GameHorseAbility> abilities,
    GameRaceRandom random,
  ) {
    final out = <GameHorseAbility>[];
    for (final a in abilities) {
      final speedAdd =
          a.speedAdd + normal(random) * speedNoiseSd * a.noiseScale;
      final style =
          (a.style + normal(random) * styleNoiseSd).clamp(0.0, 3.0).toDouble();
      final stamina = (a.stamina * math.exp(normal(random) * formNoiseSd))
          .clamp(100.0, 2500.0)
          .toDouble();
      final guts = (a.guts * math.exp(normal(random) * formNoiseSd))
          .clamp(100.0, 2500.0)
          .toDouble();
      final power = (a.power * math.exp(normal(random) * formNoiseSd))
          .clamp(100.0, 2500.0)
          .toDouble();
      out.add(a.copyWith(
        speedAdd: speedAdd,
        style: style,
        stamina: stamina,
        guts: guts,
        power: power,
      ));
    }
    return out;
  }

  /// 能力値のランク(G〜S)。設計書7-1の固定の区切り。
  static String rankOf(double value) {
    if (value >= 1000) return 'S';
    if (value >= 900) return 'A';
    if (value >= 800) return 'B';
    if (value >= 700) return 'C';
    if (value >= 600) return 'D';
    if (value >= 450) return 'E';
    if (value >= 300) return 'F';
    return 'G';
  }
}