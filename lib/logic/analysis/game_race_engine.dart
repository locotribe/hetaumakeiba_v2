// lib/logic/analysis/game_race_engine.dart
// [追加] 展開シミュゲーム式移植Step1: ウマ娘のレース計算式を移植した展開シミュのエンジン(1レース・1回ぶん)。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の3章・4章。DB / I/O / UI に触れない純粋ロジック (v.2026.10.27+26102701)

import 'dart:math' as math;

/// 1頭ぶんの能力値(ゲームの単位)。
class GameHorseAbility {
  /// 終盤の速度加算(m/s)。ゲームの √(500×スピード)×0.002 に当たる
  final double speedAdd;

  /// スタミナ(最大HPの上乗せに使う)
  final double stamina;

  /// パワー(加速に使う)
  final double power;

  /// 根性(スパートの速度・終盤のHP消費・最低速度に使う)
  final double guts;

  /// 賢さ(掛かり・ポジションキープ・スパートの判断・区間ごとの乱数に使う)
  final double wit;

  /// 脚質(連続値)。0.0=逃げ、1.0=先行、2.0=差し、3.0=追込
  final double style;

  /// 当日の出来の揺らぎの大きさの倍率(スピード指数の信頼度が低いほど大きい)
  final double noiseScale;

  /// 画面に出すスピードの値(0〜1200程度。ゲームのスピードの見た目に合わせた値)
  final double speedDisplay;

  const GameHorseAbility({
    required this.speedAdd,
    required this.stamina,
    required this.power,
    required this.guts,
    required this.wit,
    required this.style,
    required this.noiseScale,
    required this.speedDisplay,
  });

  GameHorseAbility copyWith({
    double? speedAdd,
    double? stamina,
    double? power,
    double? guts,
    double? style,
  }) {
    return GameHorseAbility(
      speedAdd: speedAdd ?? this.speedAdd,
      stamina: stamina ?? this.stamina,
      power: power ?? this.power,
      guts: guts ?? this.guts,
      wit: wit,
      style: style ?? this.style,
      noiseScale: noiseScale,
      speedDisplay: speedDisplay,
    );
  }
}

/// エンジンが使う乱数。0.0以上1.0未満の値を返す。
abstract class GameRaceRandom {
  double nextDouble();
}

/// 決まった種から同じ並びを返す乱数(線形合同法・32ビット)。単体テストと再現に使う。
class GameRaceLcgRandom implements GameRaceRandom {
  int _state;

  GameRaceLcgRandom(int seed) : _state = seed & 0xFFFFFFFF;

  @override
  double nextDouble() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state / 4294967296.0;
  }
}

/// dart:math の Random を使う乱数。アプリでの実行に使う。
class GameRaceDartRandom implements GameRaceRandom {
  final math.Random _random;

  GameRaceDartRandom([int? seed]) : _random = math.Random(seed);

  @override
  double nextDouble() => _random.nextDouble();
}

/// 馬場(芝・ダート)ごとの校正値と、計算の入り切り。
class GameRaceConfig {
  /// 序盤・中盤の速度の倍率(ペース)。1000m通過のスライダーでも動かす
  final double paceMult;

  /// 終盤の脚質係数への加算(逃げ・先行・差し・追込の順)
  final List<double> lateAdj;

  /// スパート倍率(ゲームは1.05)
  final double spurtMult;

  /// HP消費の係数(ゲームは20)
  final double hpConsK;

  /// 馬場状態によるHP消費の倍率(良・稍重=1.0)
  final double groundHp;

  /// 区間ごとの賢さの乱数を入れるか
  final bool witRandom;

  /// 掛かりを入れるか
  final bool rushed;

  /// ポジションキープを入れるか
  final bool positionKeep;

  /// スパートの候補を賢さの確率で選ぶか(false なら最も速い候補を選ぶ)
  final bool spurtAccept;

  const GameRaceConfig({
    required this.paceMult,
    required this.lateAdj,
    this.spurtMult = 1.0,
    this.hpConsK = 20.0,
    this.groundHp = 1.0,
    this.witRandom = true,
    this.rushed = true,
    this.positionKeep = true,
    this.spurtAccept = true,
  });

  /// 芝の校正値(設計書4章)
  static const GameRaceConfig turf = GameRaceConfig(
    paceMult: 1.03,
    lateAdj: [0.03, 0.01, -0.01, -0.03],
  );

  /// ダートの校正値(設計書4章)
  static const GameRaceConfig dirt = GameRaceConfig(
    paceMult: 1.09,
    lateAdj: [0.03, 0.01, -0.01, -0.03],
  );

  GameRaceConfig copyWith({
    double? paceMult,
    double? groundHp,
    bool? witRandom,
    bool? rushed,
    bool? positionKeep,
    bool? spurtAccept,
  }) {
    return GameRaceConfig(
      paceMult: paceMult ?? this.paceMult,
      lateAdj: lateAdj,
      spurtMult: spurtMult,
      hpConsK: hpConsK,
      groundHp: groundHp ?? this.groundHp,
      witRandom: witRandom ?? this.witRandom,
      rushed: rushed ?? this.rushed,
      positionKeep: positionKeep ?? this.positionKeep,
      spurtAccept: spurtAccept ?? this.spurtAccept,
    );
  }
}

/// 位置の記録1点(ゲームの時間・スタートからの距離)。
class GameRacePoint {
  final double time;
  final double distance;

  const GameRacePoint(this.time, this.distance);
}

/// 1回ぶんの結果。時間はゲームの単位(実時間への換算は呼び出し側)。
class GameRaceRunResult {
  /// ゴールした時刻。時間切れでゴールしなかった馬は null
  final List<double?> finishTimes;

  /// スタートから1000m地点を通過した時刻
  final List<double?> time1000;

  /// ゴール600m手前を通過した時刻
  final List<double?> time600;

  /// 位置の記録(スタート、一定フレームごと、ゴール)
  final List<List<GameRacePoint>> traces;

  const GameRaceRunResult({
    required this.finishTimes,
    required this.time1000,
    required this.time600,
    required this.traces,
  });
}

class GameRaceEngine {
  GameRaceEngine._();

  /// 1秒あたりの更新回数
  static const int fps = 15;

  /// 1回の更新の時間(秒)
  static const double dt = 1.0 / fps;

  /// 脚質ごとの速度係数(序盤・中盤・終盤)。逃げ・先行・差し・追込の順
  static const List<List<double>> speedCoef = [
    [1.000, 0.980, 0.962],
    [0.978, 0.991, 0.975],
    [0.938, 0.998, 0.994],
    [0.931, 1.000, 1.000],
  ];

  /// 脚質ごとの加速係数(序盤・中盤・終盤)
  static const List<List<double>> accelCoef = [
    [1.000, 1.000, 0.996],
    [0.985, 1.000, 0.996],
    [0.975, 1.000, 1.000],
    [0.945, 1.000, 0.997],
  ];

  /// 脚質ごとのHP係数
  static const List<double> hpCoef = [0.95, 0.89, 1.00, 0.995];

  /// 目標速度より速いときの減速(序盤・中盤・終盤、m/s²)
  static const List<double> decel = [-1.2, -0.8, -1.0];

  /// ポジションキープの適正な離れの下限・上限(m)。先行の下限以外は距離係数を掛ける
  static const List<double> pkLow = [0.0, 3.0, 6.5, 7.5];
  static const List<double> pkHigh = [0.0, 5.0, 7.0, 8.0];

  /// ポジションキープのモードごとの速度倍率(通常・ペースアップ・ペースダウン・スピードアップ・追い抜き)
  static const List<double> pkMult = [1.0, 1.04, 0.915, 1.04, 1.05];

  static double _log10(double x) => math.log(x) / math.ln10;

  /// 脚質(連続値)から係数の行を補間する。[adj] は終盤の列への加算
  static List<double> _interpRow(
      List<List<double>> table, double style, List<double>? adj) {
    final s = style.clamp(0.0, 3.0).toDouble();
    final lo = s.floor();
    final hi = math.min(lo + 1, 3);
    final w = s - lo;
    final out = <double>[];
    for (int k = 0; k < 3; k++) {
      double a = table[lo][k];
      double b = table[hi][k];
      if (adj != null && k == 2) {
        a += adj[lo];
        b += adj[hi];
      }
      out.add(a * (1 - w) + b * w);
    }
    return out;
  }

  static double _interpHp(double style) {
    final s = style.clamp(0.0, 3.0).toDouble();
    final lo = s.floor();
    final hi = math.min(lo + 1, 3);
    final w = s - lo;
    return hpCoef[lo] * (1 - w) + hpCoef[hi] * w;
  }

  /// 脚質(連続値)を4区分(0=逃げ〜3=追込)にする。
  static int styleClass(double style) {
    return (style.clamp(0.0, 3.0).toDouble() + 0.5).floor();
  }

  /// 1回走らせる。[distance] はレースの距離(m)。
  /// 乱数は「発走前(馬ごとに 出遅れ・掛かるか・掛かる区間・区間内の位置・賢さの乱数24個)」
  /// 「毎フレーム(掛かりの解除 → ポジションキープ → スパートの候補選び、それぞれ馬番の順)」の順に引く。
  static GameRaceRunResult simulate({
    required double distance,
    required List<GameHorseAbility> horses,
    required GameRaceConfig config,
    required GameRaceRandom random,
    int traceEveryFrames = 15,
  }) {
    final d = distance;
    final n = horses.length;
    final vb = 22.0 - d / 1000.0;
    final secLen = d / 24.0;
    final cf = 0.0008 * (d - 1000) + 1.0;

    final ac = <List<double>>[];
    final sd = <int>[];
    final maxHp = <double>[];
    final gutsMod = <double>[];
    final minSpeed = <double>[];
    final base = <List<double>>[];
    final spurtMax = <double>[];
    final accelBase = <double>[];
    final pkLo = <double>[];
    final pkHi = <double>[];
    final witMax = <double>[];
    final rushP = <double>[];
    final pA = <double>[];
    final pB = <double>[];
    for (final h in horses) {
      final c = _interpRow(speedCoef, h.style, config.lateAdj);
      ac.add(_interpRow(accelCoef, h.style, null));
      final cls = styleClass(h.style);
      sd.add(cls);
      maxHp.add(0.8 * _interpHp(h.style) * h.stamina + d);
      final g = h.guts;
      gutsMod.add(1.0 + 200.0 / math.sqrt(600.0 * g));
      minSpeed.add(0.85 * vb + math.sqrt(200.0 * g) * 0.001);
      base.add([
        vb * c[0] * config.paceMult,
        vb * c[1] * config.paceMult,
        vb * c[2] + h.speedAdd,
      ]);
      spurtMax.add((vb * c[2] + 0.01 * vb) * config.spurtMult +
          h.speedAdd +
          math.pow(450.0 * g, 0.597).toDouble() * 0.0001);
      accelBase.add(0.0006 * math.sqrt(500.0 * h.power));
      pkLo.add(cls == 1 ? pkLow[cls] : pkLow[cls] * cf);
      pkHi.add(pkHigh[cls] * cf);
      final w = h.wit;
      witMax.add(w / 5500.0 * _log10(w * 0.1) / 100.0);
      final q = 6.5 / _log10(0.1 * w + 1.0);
      rushP.add(q * q / 100.0);
      pA.add((20.0 * _log10(0.1 * w) / 100.0).clamp(0.0, 1.0).toDouble());
      pB.add((15.0 * _log10(0.1 * w) / 100.0).clamp(0.0, 1.0).toDouble());
    }
    int frontStyle = 3;
    for (final s in sd) {
      if (s < frontStyle) frontStyle = s;
    }

    // 発走前の乱数
    final delay = <double>[];
    final willRush = <bool>[];
    final rushPos = <double>[];
    final witRand = <List<double>>[];
    for (int i = 0; i < n; i++) {
      delay.add(random.nextDouble() * 0.1);
      final u = random.nextDouble();
      willRush.add(config.rushed && u < rushP[i]);
      final k = 1 + (random.nextDouble() * 8.0).floor();
      rushPos.add((k + random.nextDouble()) * secLen);
      final row = <double>[];
      for (int s = 0; s < 24; s++) {
        final w = random.nextDouble();
        row.add(config.witRandom ? witMax[i] - 0.0065 + 0.0065 * w : 0.0);
      }
      witRand.add(row);
    }

    final pos = List<double>.filled(n, 0.0);
    final v = List<double>.filled(n, 3.0);
    final hp = List<double>.from(maxHp);
    final started = List<bool>.filled(n, false);
    final dash = List<bool>.filled(n, true);
    final finished = List<bool>.filled(n, false);
    final finish = List<double?>.filled(n, null);
    final t1000 = List<double?>.filled(n, null);
    final t600 = List<double?>.filled(n, null);
    final rushing = List<bool>.filled(n, false);
    final rushT = List<double>.filled(n, 0.0);
    final rushDone = List<bool>.filled(n, false);
    final mode = List<int>.filled(n, 0);
    final pkEnd = List<double>.filled(n, 0.0);
    final pkNext = List<double>.filled(n, 0.0);
    final spurtSet = List<bool>.filled(n, false);
    final spurtV = List<double>.filled(n, 0.0);
    final spurtFrom = List<double>.filled(n, double.infinity);
    final traces = List<List<GameRacePoint>>.generate(
        n, (_) => [const GameRacePoint(0.0, 0.0)]);
    final sec = List<int>.filled(n, 0);
    final phase = List<int>.filled(n, 0);
    final mult = List<double>.filled(n, 1.0);
    final order = List<int>.generate(n, (i) => i);

    final tMax = d / (vb * 0.6) + 30.0;
    int frame = 0;
    double t = 0.0;
    while (t < tMax && finished.contains(false)) {
      frame++;
      t = frame * dt;
      for (int i = 0; i < n; i++) {
        if (!started[i] && t >= delay[i]) started[i] = true;
        sec[i] = math.min((pos[i] / secLen).floor(), 23);
        phase[i] = sec[i] < 4 ? 0 : (sec[i] < 16 ? 1 : 2);
      }

      // 1) 掛かり
      if (config.rushed) {
        for (int i = 0; i < n; i++) {
          if (willRush[i] &&
              !rushing[i] &&
              !rushDone[i] &&
              pos[i] >= rushPos[i]) {
            rushing[i] = true;
            rushT[i] = 0.0;
          }
          if (rushing[i]) {
            rushT[i] += dt;
            final chk =
                (rushT[i] / 3.0).floor() > ((rushT[i] - dt) / 3.0).floor();
            bool end = rushT[i] >= 12.0;
            if (chk && !end) {
              end = random.nextDouble() < 0.55;
            }
            if (end) {
              rushing[i] = false;
              rushDone[i] = true;
            }
          }
        }
      }

      // 2) ポジションキープ(フレーム開始時の位置で判定)
      for (int i = 0; i < n; i++) {
        mult[i] = 1.0;
      }
      if (config.positionKeep) {
        int pm = -1;
        double pmPos = double.negativeInfinity;
        for (int i = 0; i < n; i++) {
          if (sd[i] == frontStyle && pos[i] > pmPos) {
            pm = i;
            pmPos = pos[i];
          }
        }
        order.sort((a, b) {
          final c = pos[b].compareTo(pos[a]);
          return c != 0 ? c : a.compareTo(b);
        });
        final first = order[0];
        final secondPos = n > 1 ? pos[order[1]] : pos[first];
        for (int i = 0; i < n; i++) {
          final inPk = sec[i] < 10;
          final gap = pos[pm] - pos[i];
          final lead = pos[i] - secondPos;
          final isFirst = i == first;
          final nige = sd[i] == 0 || rushing[i];
          final due = inPk && t >= pkNext[i] && mode[i] == 0 && started[i];
          bool start = false;
          if (due) {
            final u = random.nextDouble();
            int nm = 0;
            if (nige && isFirst && lead < 4.5 && u < pA[i]) {
              nm = 3;
            } else if (nige && !isFirst && u < pA[i]) {
              nm = 4;
            } else if (!nige && i != pm && gap < pkLo[i]) {
              nm = 2;
            } else if (!nige && i != pm && gap > pkHi[i] && u < pB[i]) {
              nm = 1;
            }
            if (nm > 0) {
              mode[i] = nm;
              pkEnd[i] = pos[i] + secLen;
              start = true;
            }
          }
          if (mode[i] > 0) {
            final mid = (pkLo[i] + pkHi[i]) / 2.0;
            final m = mode[i];
            final fin = pos[i] >= pkEnd[i] ||
                !inPk ||
                (m == 2 && gap >= mid) ||
                (m == 1 && gap <= mid) ||
                (m == 3 && lead > 4.5) ||
                (m == 4 && isFirst && lead > 10.0);
            if (fin) {
              mode[i] = 0;
              pkNext[i] = t + 1.0;
            }
          } else if (due && !start) {
            pkNext[i] = t + 2.0;
          }
          mult[i] = pkMult[mode[i]];
        }
      }

      // 3) スパートの判定(終盤に入った最初のフレーム)
      for (int i = 0; i < n; i++) {
        if (phase[i] != 2 || spurtSet[i] || !started[i] || finished[i]) {
          continue;
        }
        spurtSet[i] = true;
        final l = d - pos[i] - 60.0;
        final v2 = base[i][2];
        final vMax = spurtMax[i];
        double cons(double vv) {
          final e = vv - vb + 12.0;
          return config.hpConsK *
              (e * e) /
              144.0 *
              gutsMod[i] *
              config.groundHp;
        }

        if (hp[i] >= cons(vMax) * l / vMax) {
          spurtV[i] = vMax;
          spurtFrom[i] = pos[i];
          continue;
        }
        final cands = <_SpurtCandidate>[];
        final c2 = cons(v2);
        for (int k = 0; k < 40; k++) {
          final vv = vMax - 0.1 * k;
          if (!(vv > v2)) continue;
          final a = cons(vv) / vv - c2 / v2;
          if (a <= 0) continue;
          double x = (hp[i] - c2 * l / v2) / a;
          if (!(x > 0)) continue;
          x = math.min(x, l);
          cands.add(_SpurtCandidate(x / vv + (l - x) / v2, k, vv, x));
        }
        if (cands.isEmpty) {
          spurtV[i] = v2;
          spurtFrom[i] = double.infinity;
          continue;
        }
        cands.sort((a, b) {
          final c = a.time.compareTo(b.time);
          return c != 0 ? c : a.index.compareTo(b.index);
        });
        _SpurtCandidate? chosen;
        final pAcc = (15.0 + 0.05 * horses[i].wit) / 100.0;
        for (final c in cands) {
          if (!config.spurtAccept || random.nextDouble() < pAcc) {
            chosen = c;
            break;
          }
        }
        chosen ??= cands.last;
        spurtV[i] = chosen.speed;
        spurtFrom[i] = d - 60.0 - chosen.distance;
      }

      // 4) 速度・HP・位置
      for (int i = 0; i < n; i++) {
        if (!started[i] || finished[i]) continue;
        final p = phase[i];
        double tgt = base[i][p];
        if (p < 2) {
          tgt += witRand[i][sec[i]] * vb;
          tgt *= mult[i];
        }
        if (p == 2 && spurtSet[i] && pos[i] >= spurtFrom[i]) {
          tgt = spurtV[i];
        }
        final out = hp[i] <= 0;
        if (out) tgt = minSpeed[i];
        if (!dash[i]) tgt = math.max(tgt, minSpeed[i]);
        final acc = accelBase[i] * ac[i][p] + (dash[i] ? 24.0 : 0.0);
        double dec = decel[p];
        if (mode[i] == 2) dec = -0.5;
        if (out) dec = -1.2;
        double nv;
        if (v[i] < tgt) {
          nv = math.min(v[i] + acc * dt, tgt);
        } else {
          nv = math.max(v[i] + dec * dt, tgt);
        }
        if (dash[i]) {
          nv = math.min(nv, 0.85 * vb);
          if (nv >= 0.85 * vb - 1e-9) dash[i] = false;
        }
        final stat = (rushing[i] ? 1.6 : 1.0) * (mode[i] == 2 ? 0.6 : 1.0);
        final gm = p == 2 ? gutsMod[i] : 1.0;
        final e = nv - vb + 12.0;
        hp[i] -=
            config.hpConsK * (e * e) / 144.0 * stat * gm * config.groundHp * dt;
        final prev = pos[i];
        pos[i] = prev + nv * dt;
        v[i] = nv;
        final step = math.max(pos[i] - prev, 1e-9);
        if (t1000[i] == null && prev < 1000.0 && 1000.0 <= pos[i]) {
          t1000[i] = t - dt + (1000.0 - prev) / step * dt;
        }
        final p6 = d - 600.0;
        if (t600[i] == null && prev < p6 && p6 <= pos[i]) {
          t600[i] = t - dt + (p6 - prev) / step * dt;
        }
        if (pos[i] >= d) {
          final ft = t - dt + (d - prev) / step * dt;
          finish[i] = ft;
          finished[i] = true;
          traces[i].add(GameRacePoint(ft, d));
        } else if (frame % traceEveryFrames == 0) {
          traces[i].add(GameRacePoint(t, pos[i]));
        }
      }
    }

    return GameRaceRunResult(
      finishTimes: finish,
      time1000: t1000,
      time600: t600,
      traces: traces,
    );
  }
}

class _SpurtCandidate {
  final double time;
  final int index;
  final double speed;
  final double distance;

  const _SpurtCandidate(this.time, this.index, this.speed, this.distance);
}