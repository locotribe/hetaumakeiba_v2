// lib/logic/analysis/game_race_engine.dart
// [修正] 展開シミュゲーム式移植Step2: レーン(横の位置)・前と横の詰まり・追い越し・最終コーナーの外への振り出し・
// コーナーで外を回る距離・坂を追加し、校正値を測り直した。設計は memory/展開シミュ_ゲーム式移植_設計書.md の3章・4章 (v.2026.10.27+26102702)
// ウマ娘のレース計算式を移植した展開シミュのエンジン(1レース・1回ぶん)。DB / I/O / UI に触れない純粋ロジック。

import 'dart:math' as math;

import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// 1頭ぶんの能力値(ゲームの単位)。
class GameHorseAbility {
  /// 終盤の速度加算(m/s)。ゲームの √(500×スピード)×0.002 に当たる
  final double speedAdd;

  /// スタミナ(最大HPの上乗せに使う)
  final double stamina;

  /// パワー(加速・上り坂・横の移動に使う)
  final double power;

  /// 根性(スパートの速度・終盤のHP消費・最低速度に使う)
  final double guts;

  /// 賢さ(掛かり・ポジションキープ・スパートの判断・区間ごとの乱数・下り坂に使う)
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

  /// レーン(横の位置・前と横の詰まり・追い越し・外を回る距離)を入れるか
  final bool lanes;

  /// 坂(上り坂の減速・下り坂モード)を入れるか
  final bool slopes;

  /// [追加] 展開シミュゲーム式移植Step4d: 最低速度(HPが尽きたときの目標速度)の根性の項の倍率(ゲームは1.0)。
  /// 最低速度 = 0.85×基準速度 + √(200×根性)×0.001×倍率 − [minSpeedGutsRef]×(倍率−1)。根性600の馬は倍率によらず同じ。
  /// 倍率を上げると、HPが尽きた後も根性(末脚)の差で差が動く (v.2026.10.27+26102707)
  final double minSpeedGutsScale;

  /// [追加] 展開シミュゲーム式移植Step4d: 根性600のときの √(200×根性)×0.001 (v.2026.10.27+26102707)
  static const double minSpeedGutsRef = 0.3464;

  /// [追加] 展開シミュゲーム式移植Step4e追補: 最終コーナーの振り出し先(コース幅の割合)の作り方。
  /// null はゲームのまま「min(内ラチからの距離/0.1, 1)×0.5 + 乱数(0〜0.1)」で、直線で全馬がコースの真ん中あたりへ動く。
  /// 値があるときは「min(今の横の位置 × この値 + 乱数(0〜0.1), 1)」で、4コーナーを出たときの内ラチからの距離に比例して扇のように広がる
  /// (内の馬は内寄りに、外の馬ほど外へ)。着順の相関・脚質のバランスはほとんど変わらない(設計書 8-1 の Step4e) (v.2026.10.27+26102708)
  final double? finalCornerFan;

  /// [追加] 展開シミュ改良Step1(案C): 内ラチ付近の馬場の進みにくさ(m/s)。内ラチで この値、内ラチから [innerBand] で0になる。
  /// 正 = 内が悪い、負 = 内が良い(芝の採用案は −0.05)。0 で今までと同じ (v.2026.10.28+26102801)
  final double innerBias;

  /// [追加] 展開シミュ改良Step1(案C): [innerBias] が効く幅(コース幅の割合。既定4頭分) (v.2026.10.28+26102801)
  final double innerBand;

  /// [追加] 展開シミュ改良Step1(案C): 砂をかぶる(ダート)。前 [kickDistance] m 以内・横 [kickLanes] 頭分未満に馬がいると、
  /// 進みがこの値(m/s)だけ遅くなる(ダートの採用案は0.3)。0 で今までと同じ (v.2026.10.28+26102801)
  final double kickback;

  /// [追加] 展開シミュ改良Step1(案C): 砂をかぶる前の馬との距離(m) (v.2026.10.28+26102801)
  final double kickDistance;

  /// [追加] 展開シミュ改良Step1(案C): 砂をかぶる横の幅(頭分) (v.2026.10.28+26102801)
  final double kickLanes;

  /// [追加] 展開シミュ改良Step1(案C・オーナーの式): コースの位置ごとの内の馬場の傷み。今日の内柵からの距離(m)のしきい値の並び
  /// (過去の使用日ごとに1つ)。内柵から m の位置の傷み = [wearUnit] 秒/200m × (m より大きいしきい値の数)。null・空 で今までと同じ (v.2026.10.28+26102801)
  final List<double>? wearThresholds;

  /// [追加] 展開シミュ改良Step1(案C): 傷み1つぶんの遅れ(実際の秒/200m。オーナーの式は0.01) (v.2026.10.28+26102801)
  final double wearUnit;

  /// [追加] 展開シミュ改良Step1(案C): 実際の秒 ÷ エンジンの秒(傷みの秒をエンジンの時間に直すのに使う。約1.2) (v.2026.10.28+26102801)
  final double wearTimeScale;

  /// [追加] 展開シミュ改良Step1(案C): 序盤・中盤に内へ寄るとき、傷みがこの値(秒/200m)以下の所までしか寄らない。
  /// null はゲームのまま(傷みを見ない) (v.2026.10.28+26102801)
  final double? wearAvoid;

  /// [追加] 展開シミュ改良Step1(案C): true なら、傷んだ内にいる馬は序盤・中盤に [wearAvoid] の所まで外へ出る。
  /// false は内へ寄るのを止めるだけ (v.2026.10.28+26102801)
  final bool wearAvoidOut;

  const GameRaceConfig({
    required this.paceMult,
    required this.lateAdj,
    this.spurtMult = 1.0,
    this.hpConsK = 21.0,
    this.groundHp = 1.0,
    this.witRandom = true,
    this.rushed = true,
    this.positionKeep = true,
    this.spurtAccept = true,
    this.lanes = true,
    this.slopes = true,
    this.minSpeedGutsScale = 1.0,
    this.finalCornerFan,
    // [追加] 展開シミュ改良Step1(案C): 既定値は今までと同じ結果になる値 (v.2026.10.28+26102801)
    this.innerBias = 0.0,
    this.innerBand = 4.0 / 18.0,
    this.kickback = 0.0,
    this.kickDistance = 5.0,
    this.kickLanes = 1.0,
    this.wearThresholds,
    this.wearUnit = 0.01,
    this.wearTimeScale = 1.2,
    this.wearAvoid,
    this.wearAvoidOut = false,
  });

  /// 芝の校正値(設計書4章)
  // [修正] 展開シミュゲーム式移植Step4d: 最低速度の根性の項を4倍にした (v.2026.10.27+26102707)
  static const GameRaceConfig turf = GameRaceConfig(
    paceMult: 1.03,
    lateAdj: [0.0, 0.0, 0.0, 0.0],
    minSpeedGutsScale: 4.0,
    // [追加] 展開シミュゲーム式移植Step4e追補: 直線で、内ラチからの距離の3倍へ扇のように広がる (v.2026.10.27+26102708)
    finalCornerFan: 3.0,
  );

  /// ダートの校正値(設計書4章)
  // [修正] 展開シミュゲーム式移植Step4d: 最低速度の根性の項を4倍にした (v.2026.10.27+26102707)
  static const GameRaceConfig dirt = GameRaceConfig(
    paceMult: 1.08,
    lateAdj: [0.0, 0.0, 0.0, 0.0],
    minSpeedGutsScale: 4.0,
    // [追加] 展開シミュゲーム式移植Step4e追補: 直線で、内ラチからの距離の3倍へ扇のように広がる (v.2026.10.27+26102708)
    finalCornerFan: 3.0,
  );

  GameRaceConfig copyWith({
    double? paceMult,
    double? groundHp,
    bool? witRandom,
    bool? rushed,
    bool? positionKeep,
    bool? spurtAccept,
    bool? lanes,
    bool? slopes,
    // [追加] 展開シミュ改良Step1(案C): 内の馬場・砂かぶり・傷みもレースごとに差し替えられるようにする(null は元のまま) (v.2026.10.28+26102801)
    double? innerBias,
    double? innerBand,
    double? kickback,
    double? kickDistance,
    double? kickLanes,
    List<double>? wearThresholds,
    double? wearUnit,
    double? wearTimeScale,
    double? wearAvoid,
    bool? wearAvoidOut,
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
      lanes: lanes ?? this.lanes,
      slopes: slopes ?? this.slopes,
      minSpeedGutsScale: minSpeedGutsScale,
      finalCornerFan: finalCornerFan,
      // [追加] 展開シミュ改良Step1(案C) (v.2026.10.28+26102801)
      innerBias: innerBias ?? this.innerBias,
      innerBand: innerBand ?? this.innerBand,
      kickback: kickback ?? this.kickback,
      kickDistance: kickDistance ?? this.kickDistance,
      kickLanes: kickLanes ?? this.kickLanes,
      wearThresholds: wearThresholds ?? this.wearThresholds,
      wearUnit: wearUnit ?? this.wearUnit,
      wearTimeScale: wearTimeScale ?? this.wearTimeScale,
      wearAvoid: wearAvoid ?? this.wearAvoid,
      wearAvoidOut: wearAvoidOut ?? this.wearAvoidOut,
    );
  }
}

/// コーナー1つ(スタートからの距離で、開始・終了と、内ラチの半径)。
class GameRaceCorner {
  final double start;
  final double end;
  final double radius;

  const GameRaceCorner(this.start, this.end, this.radius);
}

/// エンジンが使うコースの形(コーナーと標高)。距離はすべてスタートからの距離(m)。
class GameRaceCourse {
  /// これ未満の勾配(%)は平坦とみなす
  static const double slopeMinPercent = 1.0;

  /// 標高を取り出す間隔(m)
  static const double elevationStep = 25.0;

  final List<GameRaceCorner> corners;

  /// (スタートからの距離, 標高) の点。距離の昇順
  final List<ElevationPoint> elevation;

  const GameRaceCourse({required this.corners, required this.elevation});

  /// コーナーも坂も無いコース
  static const GameRaceCourse flat = GameRaceCourse(corners: [], elevation: []);

  /// アプリのコースデータから作る。コーナー1つは90度とみなし、半径 = 長さ ÷ (π/2)。
  /// 標高は、ゴールからの距離(1周の長さで割った余り)で基礎データから引く。
  factory GameRaceCourse.fromRaceCourseData(RaceCourseData data) {
    final distance = data.raceDistance.toDouble();
    final corners = <GameRaceCorner>[];
    for (final s in data.sections) {
      if (s.name.startsWith('corner_') && s.endDistance > s.startDistance) {
        corners.add(GameRaceCorner(s.startDistance, s.endDistance,
            (s.endDistance - s.startDistance) / (math.pi / 2.0)));
      }
    }
    final points = data.baseData.points;
    final lap = data.baseData.lapDistance;
    final elevation = <ElevationPoint>[];
    if (points.isNotEmpty) {
      double x = 0.0;
      while (x <= distance + 1e-9) {
        final dg = distance - x;
        final b = lap > 0 ? dg % lap : dg;
        elevation.add(
            ElevationPoint(distance: x, elevation: _interpBase(points, b)));
        x += elevationStep;
      }
    }
    return GameRaceCourse(corners: corners, elevation: elevation);
  }

  static double _interpBase(List<ElevationPoint> points, double d) {
    if (d <= points.first.distance) return points.first.elevation;
    if (d >= points.last.distance) return points.last.elevation;
    for (int k = 0; k < points.length - 1; k++) {
      final a = points[k];
      final b = points[k + 1];
      if (a.distance <= d && d <= b.distance) {
        if (b.distance == a.distance) return a.elevation;
        return a.elevation +
            (b.elevation - a.elevation) *
                (d - a.distance) /
                (b.distance - a.distance);
      }
    }
    return points.last.elevation;
  }

  /// 最初のコーナーの開始(無ければ無限大)
  double get firstCornerStart =>
      corners.isEmpty ? double.infinity : corners.first.start;

  /// 最終コーナーの開始(無ければ無限大)
  double get finalCornerStart =>
      corners.isEmpty ? double.infinity : corners.last.start;

  /// 最終コーナーの終了(無ければ負の無限大)
  double get finalCornerEnd =>
      corners.isEmpty ? double.negativeInfinity : corners.last.end;

  /// その距離がコーナーなら内ラチの半径、そうでなければ0
  double cornerRadiusAt(double x) {
    for (final c in corners) {
      if (c.start <= x && x < c.end) return c.radius;
    }
    return 0.0;
  }

  /// その距離の標高(線形補間)
  double elevationAt(double x) {
    final p = elevation;
    if (p.isEmpty) return 0.0;
    if (x <= p.first.distance) return p.first.elevation;
    if (x >= p.last.distance) return p.last.elevation;
    int lo = 0;
    int hi = p.length - 1;
    final guess = (x / elevationStep).floor();
    if (guess >= 0 &&
        guess + 1 < p.length &&
        p[guess].distance <= x &&
        x < p[guess + 1].distance) {
      lo = guess;
      hi = guess + 1;
    }
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (p[mid].distance <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final x0 = p[lo].distance;
    final e0 = p[lo].elevation;
    final x1 = p[hi].distance;
    final e1 = p[hi].elevation;
    return x1 == x0 ? e0 : e0 + (e1 - e0) * (x - x0) / (x1 - x0);
  }

  /// 進む向きの勾配(%)。上りが正。前後25mの標高差から求め、絶対値が1%未満は0とする。
  double slopePercentAt(double x) {
    final s = (elevationAt(x + 25.0) - elevationAt(x - 25.0)) / 50.0 * 100.0;
    return s.abs() >= slopeMinPercent ? s : 0.0;
  }
}

/// 位置の記録1点(ゲームの時間・スタートからの距離・内ラチからの横の位置)。
/// 横の位置の単位はコース幅(1コース幅 = 11.25m)。
class GameRacePoint {
  final double time;
  final double distance;
  final double lane;

  const GameRacePoint(this.time, this.distance, this.lane);
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

  /// 1コース幅(m)
  static const double courseWidthMeters = 11.25;

  /// 1頭ぶんの横幅(コース幅の単位)
  static const double horseLane = 1.0 / 18.0;

  /// 横の位置の上限(コース幅の単位)
  static const double maxLane = 1.0;

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

  /// 序盤に内へ寄る力の脚質ごとの値(m/s)
  static const List<double> forceInStyle = [0.02, 0.01, 0.01, 0.03];

  /// 外へ動くときのレーン選びの点数の係数(序盤・中盤・終盤)。内へは1.0
  static const List<double> laneOutCoef = [100.0, 1.0, 1.15];

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

  /// 1回走らせる。[distance] はレースの距離(m)。[horses] の順はゲートの内からの順(馬番順)。
  /// 乱数は「発走前(馬ごとに 出遅れ・掛かるか・掛かる区間・区間内の位置・賢さの乱数24個・内へ寄る力)」
  /// 「毎フレーム(掛かりの解除 → ポジションキープ → スパートの候補選び → 最終コーナーの振り出し先
  /// → 下り坂モード、それぞれ馬番の順)」の順に引く。
  static GameRaceRunResult simulate({
    required double distance,
    required List<GameHorseAbility> horses,
    required GameRaceConfig config,
    required GameRaceRandom random,
    GameRaceCourse course = GameRaceCourse.flat,
    int traceEveryFrames = 15,
  }) {
    final d = distance;
    final n = horses.length;
    final vb = 22.0 - d / 1000.0;
    final secLen = d / 24.0;
    final cf = 0.0008 * (d - 1000) + 1.0;
    const hl = horseLane;

    final ac = <List<double>>[];
    final sd = <int>[];
    final maxHp = <double>[];
    final gutsMod = <double>[];
    final minSpeed = <double>[];
    final base = <List<double>>[];
    final spurtMax = <double>[];
    final powerRoot = <double>[];
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
      // [修正] 展開シミュゲーム式移植Step4d: 根性の項に倍率をかける(根性600で変わらないように引く) (v.2026.10.27+26102707)
      minSpeed.add(0.85 * vb +
          math.sqrt(200.0 * g) * 0.001 * config.minSpeedGutsScale -
          GameRaceConfig.minSpeedGutsRef * (config.minSpeedGutsScale - 1.0));
      base.add([
        vb * c[0] * config.paceMult,
        vb * c[1] * config.paceMult,
        vb * c[2] + h.speedAdd,
      ]);
      spurtMax.add((vb * c[2] + 0.01 * vb) * config.spurtMult +
          h.speedAdd +
          math.pow(450.0 * g, 0.597).toDouble() * 0.0001);
      powerRoot.add(math.sqrt(500.0 * h.power));
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
    final forceIn = <double>[];
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
      forceIn.add(random.nextDouble() * 0.1 + forceInStyle[sd[i]]);
    }

    // [修正] 展開シミュゲーム式移植Step4c: ゲートは内から馬の順に1頭分ずつ均等に並べる。
    // ゲームの外枠の補正(10番目以降+0.6頭分・14番目以降+1.86頭分)は、再生でゲートの並びに隙間ができるため使わない (v.2026.10.27+26102706)
    var lane = <double>[];
    for (int i = 0; i < n; i++) {
      lane.add(i * hl);
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
    final tgtLane = List<double>.from(lane);
    final laneSpeed = List<double>.filled(n, 0.0);
    final otTimer = List<double>.filled(n, 0.0);
    final needUpdate = List<bool>.filled(n, true);
    final extraLane = List<double?>.filled(n, null);
    final lastTgt = List<double>.filled(n, 0.0);
    final downMode = List<bool>.filled(n, false);
    final traces = List<List<GameRacePoint>>.generate(
        n, (i) => [GameRacePoint(0.0, 0.0, lane[i])]);
    final sec = List<int>.filled(n, 0);
    final phase = List<int>.filled(n, 0);
    final mult = List<double>.filled(n, 1.0);
    final rank = List<int>.filled(n, 0);
    final order = List<int>.generate(n, (i) => i);
    final slope = List<double>.filled(n, 0.0);
    final cap = List<double>.filled(n, double.infinity);
    final blockIn = List<bool>.filled(n, false);
    final blockOut = List<bool>.filled(n, false);
    final inRoom = List<double>.filled(n, 0.0);
    final outRoom = List<double>.filled(n, maxLane);
    final vis = <int>[];
    final targets = <int>[];
    final crowd = <int>[];
    final inCrowd = List<bool>.filled(n, false);

    // [追加] 展開シミュ改良Step1(案C): 内の馬場の傷み。避けるときの境目(内柵からの距離。コース幅の割合)。
    // 傷みが [GameRaceConfig.wearAvoid] 以下になるのは、大きい方から数えて (wearAvoid÷wearUnit) 番目のしきい値より外 (v.2026.10.28+26102801)
    final wearThr = config.wearThresholds ?? const <double>[];
    final hasWear = wearThr.isNotEmpty;
    double? wearEdge;
    final wearAvoid = config.wearAvoid;
    if (hasWear && wearAvoid != null) {
      final kOk = (wearAvoid / config.wearUnit + 1e-9).toInt();
      final ts = List<double>.from(wearThr)..sort((a, b) => b.compareTo(a));
      if (ts.length > kOk) {
        wearEdge = ts[kOk] / courseWidthMeters;
      }
    }

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
      order.sort((a, b) {
        final c = pos[b].compareTo(pos[a]);
        return c != 0 ? c : a.compareTo(b);
      });
      for (int r = 0; r < n; r++) {
        rank[order[r]] = r;
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

      // 4) 最終コーナーに入った馬の振り出し先
      for (int i = 0; i < n; i++) {
        if (config.lanes &&
            extraLane[i] == null &&
            started[i] &&
            pos[i] >= course.finalCornerStart) {
          // [修正] 展開シミュゲーム式移植Step4e追補: 扇の広がりを指定したときは、今の横の位置に比例させる(乱数の引き方は変えない) (v.2026.10.27+26102708)
          final u = random.nextDouble();
          final fan = config.finalCornerFan;
          extraLane[i] = fan == null
              ? (lane[i] / 0.1).clamp(0.0, 1.0).toDouble() * 0.5 + u * 0.1
              : math.min(lane[i] * fan + u * 0.1, maxLane);
        }
      }

      // 5) 下り坂モード(1秒ごと)
      for (int i = 0; i < n; i++) {
        slope[i] = config.slopes ? course.slopePercentAt(pos[i]) : 0.0;
      }
      if (config.slopes && frame % fps == 0) {
        for (int i = 0; i < n; i++) {
          if (!started[i] || finished[i]) continue;
          if (downMode[i]) {
            if (slope[i] >= 0 || random.nextDouble() < 0.2) {
              downMode[i] = false;
            }
          } else if (slope[i] < 0) {
            if (random.nextDouble() < horses[i].wit * 0.0004) {
              downMode[i] = true;
            }
          }
        }
      }

      // 6) 前と横の詰まり・レーンの選び方(フレーム開始時の位置で判定)
      for (int i = 0; i < n; i++) {
        cap[i] = double.infinity;
        blockIn[i] = false;
        blockOut[i] = false;
        inRoom[i] = 0.0;
        outRoom[i] = maxLane;
      }
      if (config.lanes) {
        for (int i = 0; i < n; i++) {
          if (!started[i] || finished[i]) continue;
          int fb = -1;
          double fbd = double.infinity;
          double innerLim = 0.0;
          double outerLim = maxLane;
          vis.clear();
          for (int j = 0; j < n; j++) {
            if (j == i || finished[j]) continue;
            final dg = pos[j] - pos[i];
            if (dg > 20.0 || dg <= -1.05) continue;
            final lg = lane[j] - lane[i];
            if (0.0 < dg &&
                dg < 2.0 &&
                lg.abs() <= (1.0 - 0.6 * dg / 2.0) * 0.75 * hl &&
                dg < fbd) {
              fb = j;
              fbd = dg;
            }
            if (dg.abs() < 1.05 && lg.abs() < 2.0 * hl) {
              if (lg < 0) {
                innerLim = math.max(innerLim, lane[j] + hl);
              } else if (lg > 0) {
                outerLim = math.min(outerLim, lane[j] - hl);
              }
            }
            if (0.0 <= dg &&
                dg <= 20.0 &&
                lg.abs() <= ((dg / 20.0) * 11.5 * hl + 2.0 * hl) / 2.0) {
              vis.add(j);
            }
          }
          inRoom[i] = innerLim;
          outRoom[i] = outerLim;
          blockIn[i] = lane[i] <= innerLim + 1e-9;
          blockOut[i] = lane[i] >= outerLim - 1e-9;
          if (fb >= 0) {
            cap[i] = (0.988 + 0.012 * fbd / 2.0) * v[fb];
          }
          // 追い越しの対象
          targets.clear();
          for (final j in vis) {
            final dg = pos[j] - pos[i];
            if (j == fb) {
              targets.add(j);
              continue;
            }
            if (1.0 <= dg &&
                dg <= 20.0 &&
                v[i] > v[j] &&
                dg / (v[i] - v[j]) < 15.0 &&
                lastTgt[j] < lastTgt[i]) {
              targets.add(j);
            }
          }
          final noOtZone = phase[i] < 2 &&
              course.firstCornerStart - 200.0 <= pos[i] &&
              pos[i] < course.firstCornerStart;
          if (targets.isNotEmpty && !noOtZone) {
            otTimer[i] = 1.5;
          } else {
            otTimer[i] = math.max(otTimer[i] - dt, 0.0);
          }
          final overtake = targets.isNotEmpty && !noOtZone;
          if (!overtake && otTimer[i] > 0.0 && !noOtZone) continue;
          final diff = tgtLane[i] - lane[i];
          final blockedDir =
              (diff < 0 && blockIn[i]) || (diff > 0 && blockOut[i]);
          if (!(needUpdate[i] || diff.abs() < 0.5 * hl || blockedDir)) {
            continue;
          }
          needUpdate[i] = false;
          final p = phase[i];
          final finalStraight = pos[i] >= course.finalCornerEnd;
          if (overtake) {
            final cands = <double>[];
            double farEdge = pos[i];
            for (final j in targets) {
              for (int k = 0; k < n; k++) {
                inCrowd[k] = false;
              }
              crowd.clear();
              crowd.add(j);
              inCrowd[j] = true;
              bool changed = true;
              while (changed) {
                changed = false;
                for (int k = 0; k < n; k++) {
                  if (inCrowd[k] || k == i || finished[k]) continue;
                  if ((pos[k] - pos[j]).abs() <= 3.0 &&
                      crowd.any((c) => (lane[k] - lane[c]).abs() < 2.0 * hl)) {
                    crowd.add(k);
                    inCrowd[k] = true;
                    changed = true;
                  }
                }
              }
              double loL = double.infinity;
              double hiL = double.negativeInfinity;
              double edgePos = double.negativeInfinity;
              for (final c in crowd) {
                loL = math.min(loL, lane[c]);
                hiL = math.max(hiL, lane[c]);
                edgePos = math.max(edgePos, pos[c]);
              }
              farEdge = math.max(farEdge, edgePos);
              for (final cand in [loL - hl, hiL + hl]) {
                if (cand < 0.0 || cand > maxLane) continue;
                bool bad = false;
                for (final k in vis) {
                  if (pos[i] <= pos[k] &&
                      pos[k] <= edgePos + 0.5 &&
                      (lane[k] - cand).abs() < 0.8 * hl) {
                    bad = true;
                    break;
                  }
                }
                if (!bad) cands.add(cand);
              }
            }
            final extra = (p < 2 && lane[i] >= hl) ? lane[i] - hl : lane[i];
            bool extraBad = false;
            for (final k in vis) {
              if (pos[i] < pos[k] &&
                  pos[k] <= farEdge + 0.5 &&
                  (lane[k] - extra).abs() < 0.8 * hl) {
                extraBad = true;
                break;
              }
            }
            if (!extraBad) cands.add(extra);
            double? best;
            double bestScore = double.infinity;
            for (final cand in cands) {
              if (cand < lane[i] && blockIn[i]) continue;
              if (cand > lane[i] && blockOut[i]) continue;
              final coef = cand > lane[i] ? laneOutCoef[p] : 1.0;
              final score = (cand - lane[i]).abs() * coef;
              if (score < bestScore) {
                best = cand;
                bestScore = score;
              }
            }
            double chosenLane = best ?? lane[i];
            final ex = extraLane[i];
            if (ex != null &&
                chosenLane < ex &&
                !blockOut[i] &&
                finalStraight) {
              chosenLane = ex;
            }
            tgtLane[i] = chosenLane;
          } else {
            final ex = extraLane[i];
            if (hp[i] <= 0) {
              tgtLane[i] = lane[i];
            } else if (mode[i] == 2) {
              tgtLane[i] = 0.18;
            } else if (finalStraight &&
                ex != null &&
                ex > lane[i] &&
                !blockOut[i]) {
              tgtLane[i] = ex;
            } else if (p < 2 && !blockIn[i]) {
              tgtLane[i] = lane[i] > 0.05 ? 0.05 : lane[i];
              // [追加] 展開シミュ改良Step1(案C): 傷んだ内を避ける。境目より内へは寄らない(外へ出る指定なら境目まで出る) (v.2026.10.28+26102801)
              final edge = wearEdge;
              if (edge != null && tgtLane[i] < edge) {
                if (config.wearAvoidOut) {
                  tgtLane[i] = edge;
                } else {
                  tgtLane[i] = lane[i] >= edge
                      ? math.min(math.max(edge, tgtLane[i]), lane[i])
                      : lane[i];
                }
              }
            } else {
              tgtLane[i] = lane[i];
            }
          }
        }
      }

      // 7) 速度・HP・位置・レーン
      final newLane = List<double>.from(lane);
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
        if (config.lanes && p == 0 && lane[i] > 0.12 && !blockIn[i]) {
          tgt += forceIn[i];
        }
        final uphill = config.slopes && slope[i] > 0;
        if (uphill) {
          tgt -= slope[i] * 200.0 / horses[i].power;
        }
        if (config.slopes && downMode[i]) {
          tgt += 0.3 + slope[i].abs() / 10.0;
        }
        tgt = math.min(tgt, cap[i]);
        lastTgt[i] = tgt;
        final out = hp[i] <= 0;
        if (out) tgt = minSpeed[i];
        if (!dash[i]) tgt = math.max(tgt, minSpeed[i]);
        final acc = (uphill ? 0.0004 : 0.0006) * powerRoot[i] * ac[i][p] +
            (dash[i] ? 24.0 : 0.0);
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
        final stat = (rushing[i] ? 1.6 : 1.0) *
            (mode[i] == 2 ? 0.6 : 1.0) *
            ((config.slopes && downMode[i]) ? 0.4 : 1.0);
        final gm = p == 2 ? gutsMod[i] : 1.0;
        final e = nv - vb + 12.0;
        hp[i] -=
            config.hpConsK * (e * e) / 144.0 * stat * gm * config.groundHp * dt;
        final prev = pos[i];
        final radius = config.lanes ? course.cornerRadiusAt(prev) : 0.0;
        double adv = nv * dt;
        // [追加] 展開シミュ改良Step1(案C): 内ラチ付近の進みにくさ → 内の馬場の傷み → 砂かぶり の順に進みを直す(参照実装 simref2.py と同じ順) (v.2026.10.28+26102801)
        if (config.innerBias != 0.0 && config.lanes) {
          adv -= config.innerBias *
              math.max(0.0, 1.0 - lane[i] / config.innerBand) *
              dt;
        }
        if (hasWear && config.lanes) {
          final m = lane[i] * courseWidthMeters;
          int c = 0;
          for (final th in wearThr) {
            if (th > m) c++;
          }
          if (c > 0) {
            adv = adv /
                (1.0 + c * config.wearUnit * nv / (200.0 * config.wearTimeScale));
          }
        }
        if (config.kickback != 0.0 && config.lanes) {
          for (int j = 0; j < n; j++) {
            if (j != i &&
                started[j] &&
                !finished[j] &&
                0.0 < pos[j] - prev &&
                pos[j] - prev < config.kickDistance &&
                (lane[j] - lane[i]).abs() < config.kickLanes * hl) {
              adv -= config.kickback * dt;
              break;
            }
          }
        }
        if (radius > 0) {
          adv = adv * radius / (radius + lane[i] * courseWidthMeters);
        }
        pos[i] = prev + adv;
        v[i] = nv;
        // レーンの移動
        if (config.lanes) {
          final diff = tgtLane[i] - lane[i];
          if (diff.abs() < 1e-9) {
            laneSpeed[i] = 0.0;
          } else {
            double tls = 0.02 * (0.3 + 0.001 * horses[i].power);
            if (p < 2 && pos[i] < course.firstCornerStart) {
              tls *= 1.0 + lane[i] / maxLane * 0.05;
            }
            if (p == 2) {
              tls *= 1.0 + rank[i] * 0.01;
            }
            laneSpeed[i] = math.min(laneSpeed[i] + 0.03 * dt, tls);
            final sp = math.min(laneSpeed[i], 0.6);
            if (diff > 0) {
              if (!blockOut[i]) {
                final nl = math.min(
                    math.min(lane[i] + sp * dt, tgtLane[i]), outRoom[i]);
                newLane[i] = math.max(nl, lane[i]);
              }
            } else {
              if (!blockIn[i]) {
                final nl = math.max(
                    math.max(
                        math.max(
                            lane[i] - sp * (1.0 + lane[i]) * dt, tgtLane[i]),
                        inRoom[i]),
                    0.0);
                newLane[i] = math.min(nl, lane[i]);
              }
            }
          }
        }
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
          traces[i].add(GameRacePoint(ft, d, newLane[i]));
        } else if (frame % traceEveryFrames == 0) {
          traces[i].add(GameRacePoint(t, pos[i], newLane[i]));
        }
      }

      // 8) 重なったら外の馬を外へ押し出す
      if (config.lanes) {
        for (int i = 0; i < n; i++) {
          for (int j = i + 1; j < n; j++) {
            if (finished[i] || finished[j] || !started[i] || !started[j]) {
              continue;
            }
            if ((pos[i] - pos[j]).abs() < 0.4 &&
                (newLane[i] - newLane[j]).abs() < 0.4 * hl) {
              final o = newLane[i] > newLane[j] ? i : j;
              newLane[o] = math.min(newLane[o] + 0.4 * hl, maxLane);
              needUpdate[o] = true;
            }
          }
        }
      }
      lane = newLane;
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