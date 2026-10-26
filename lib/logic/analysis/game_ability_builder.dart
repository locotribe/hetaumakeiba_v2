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

  const GameAbilitySource({
    this.speedIndex,
    this.speedIndexConfidence,
    this.earlyRate,
    this.kickSeconds,
    this.staminaIndex,
    this.jockeyShowRate,
  });
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

  /// 出走馬全員の元の値から能力値を作る(馬の順は入力と同じ)。
  static List<GameHorseAbility> build(List<GameAbilitySource> sources) {
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
    for (final s in sources) {
      final conf = (s.speedIndex != null && s.speedIndexConfidence != null)
          ? s.speedIndexConfidence!
          : 0.0;
      final siEff =
          mean + (s.speedIndex != null ? (s.speedIndex! - mean) * conf : 0.0);
      final rate = s.earlyRate ?? defaultEarlyRate;
      final st = s.staminaIndex ?? defaultStaminaIndex;
      final kick = s.kickSeconds ?? defaultKickSeconds;
      final jt = s.jockeyShowRate ?? defaultJockeyShowRate;
      out.add(GameHorseAbility(
        speedAdd: speedBase + speedPerIndexPoint * (siEff - mean),
        stamina: math.max(1.0, -200.0 + 600.0 * st),
        power: (800.0 + 800.0 * (0.5 - rate)).clamp(200.0, 1600.0).toDouble(),
        guts: (600.0 + 600.0 * kick).clamp(100.0, 2000.0).toDouble(),
        wit: (600.0 + 4000.0 * (jt - 0.2)).clamp(150.0, 1600.0).toDouble(),
        style: styleOfRate(rate),
        noiseScale: 1.0 + (1.0 - conf),
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