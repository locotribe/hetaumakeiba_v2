// lib/logic/analysis/race_finish_calculator.dart

// [追加] 展開シミュ一般論見直しStep1: ゴールの着差を
// 「4コーナーの位置 × 残る割合 ＋ 末脚 ＋ 能力」で組み立てるための純粋ロジック。
// 定数はすべて過去のレース結果3,286レースの実測に基づく
// (根拠: memory/展開シミュ一般論見直し_実測メモ.md)。
// このファイルは DB / I/O / UI に一切触れない (v.2026.9.29+26092905)
// [修正] 展開シミュ一般論見直しStep4: 末脚の割引きと残る割合が距離で大きく変わるため、
// 定数表に距離帯(短/中/中長/長)の次元を足した。計算の流れは変えていない (v.2026.9.29+26092907)

import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 展開シミュで使う馬場種別。
enum SimSurface { turf, dirt }

/// 展開シミュで使うペース。
enum SimPace { slow, middle, high }

/// [追加] 展開シミュ一般論見直しStep4 展開シミュで使う距離帯。
/// 短=〜1400m / 中=1400〜1800m / 中長=1800〜2200m / 長=2200m〜 (v.2026.9.29+26092907)
enum SimDistanceBand { sprint, mile, middle, long }

/// 馬場 × 距離帯 × ペース ごとの実測定数。
class RaceFinishConstants {
  /// 道中(テン〜4コーナー)の馬群の広がりの目標(m)。
  final double midSpreadMeters;

  /// ゴールの馬群の広がりの目標(m)。
  final double goalSpreadMeters;

  /// 4コーナーの位置差がゴールまで残る割合(0〜1)。
  /// 1.0なら位置差がそのままゴールの差、0なら完全に帳消し。
  final double carryOver;

  /// 「後ろから行った馬ほど上がりが速く出る」分の割引き傾き(秒)。
  /// 最後方(通過順位率1.0)の馬は最前(0.0)よりこの秒数だけ上がりが速く出る。
  /// ダートの中距離以上では負の値になる(後方の馬ほど上がりが遅い)。
  final double kickSlopeSeconds;

  const RaceFinishConstants({
    required this.midSpreadMeters,
    required this.goalSpreadMeters,
    required this.carryOver,
    required this.kickSlopeSeconds,
  });
}

/// 1頭分の末脚(位置による下駄を割り引いたもの)。
class HorseFinishKick {
  /// 予想に使う末脚(秒)。正 = 平均より速く上がる。薄め係数と信頼度を適用済み。
  final double kickSeconds;

  /// 0.0〜1.0。有効な過去走が少ないほど小さい。
  final double confidence;

  /// 計算に使えた過去走の数。
  final int sampleCount;

  /// 薄め係数・信頼度を掛ける前の重み付き平均(秒)。表示・デバッグ用。
  final double rawKickSeconds;

  const HorseFinishKick({
    required this.kickSeconds,
    required this.confidence,
    required this.sampleCount,
    required this.rawKickSeconds,
  });

  /// 過去走から何も計算できなかった馬。
  static const HorseFinishKick empty = HorseFinishKick(
    kickSeconds: 0.0,
    confidence: 0.0,
    sampleCount: 0,
    rawKickSeconds: 0.0,
  );
}

class RaceFinishCalculator {
  RaceFinishCalculator._();

  /// 1秒あたりのメートル(時速60km)。アニメ再生の基準と同じ。
  static const double metersPerSecond = 16.7;

  /// 末脚が次走へ持ち越される割合(実測 0.44〜0.56)。
  static const double kickCarryFactor = 0.5;

  /// 信頼度が1.0になる有効走数。
  static const int kickFullSampleCount = 3;

  /// 近走の重み減衰(既存 marginPower と同じ)。
  static const double recencyDecay = 0.8;

  /// 末脚の計算に使う最大走数。
  static const int kickMaxRecords = 5;

  /// 能力ぶんの上限(位置スコアの点)。0.75点 = 12m相当。
  static const double abilityClampScore = 0.75;

  /// スピード指数1点あたりのメートル。実測できていないため控えめな初期値。
  static const double speedIndexMetersPerPoint = 0.6;

  /// 馬群の広がりの倍率の下限・上限。
  static const double spreadScaleMin = 0.4;
  static const double spreadScaleMax = 1.5;

  /// ペース判定: この割合以上「逃げ」ている馬をハナを主張する馬とみなす。
  static const double nigeShareThreshold = 0.35;

  /// ペース判定: この割合以上「先行」している馬を先行馬とみなす。
  static const double senkoShareThreshold = 0.40;

  /// [追加] 展開シミュ一般論見直しStep4 距離帯の境界(m) (v.2026.9.29+26092907)
  static const int sprintMaxMeters = 1400;
  static const int mileMaxMeters = 1800;
  static const int middleMaxMeters = 2200;

  // [修正] 展開シミュ一般論見直しStep4 馬場 × 距離帯 × ペース の実測定数表。
  // 芝は全12通りとも十分なサンプル(30レース以上)がある実測値。
  // ダートはサンプルの少ない区分があり、近い区分から補っている(下のコメント参照)。
  // ゴールの広がりは画面の幅(約60m相当)を超えても情報が増えないため60mで頭打ちにしてある (v.2026.9.29+26092907)
  static const Map<SimSurface,
      Map<SimDistanceBand, Map<SimPace, RaceFinishConstants>>> _constants = {
    SimSurface.turf: {
      // 短(〜1400m)
      SimDistanceBand.sprint: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 22.0, goalSpreadMeters: 30.0, carryOver: 0.46, kickSlopeSeconds: 0.64),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 25.0, goalSpreadMeters: 32.0, carryOver: 0.34, kickSlopeSeconds: 0.81),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 37.0, carryOver: 0.16, kickSlopeSeconds: 1.11),
      },
      // 中(1400〜1800m)
      SimDistanceBand.mile: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 22.0, goalSpreadMeters: 37.0, carryOver: 0.61, kickSlopeSeconds: 0.34),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 25.0, goalSpreadMeters: 40.0, carryOver: 0.22, kickSlopeSeconds: 0.85),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 32.0, goalSpreadMeters: 47.0, carryOver: 0.15, kickSlopeSeconds: 0.99),
      },
      // 中長(1800〜2200m)
      SimDistanceBand.middle: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 20.0, goalSpreadMeters: 40.0, carryOver: 0.60, kickSlopeSeconds: 0.20),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 25.0, goalSpreadMeters: 47.0, carryOver: 0.30, kickSlopeSeconds: 0.42),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 30.0, goalSpreadMeters: 60.0, carryOver: 0.08, kickSlopeSeconds: 0.28),
      },
      // 長(2200m〜)
      SimDistanceBand.long: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 22.0, goalSpreadMeters: 52.0, carryOver: 0.65, kickSlopeSeconds: 0.07),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 25.0, goalSpreadMeters: 60.0, carryOver: 0.32, kickSlopeSeconds: 0.46),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 23.0, goalSpreadMeters: 52.0, carryOver: 0.26, kickSlopeSeconds: 0.56),
      },
    },
    SimSurface.dirt: {
      // 短(〜1400m)。スローはサンプル1件のためミドルから補い、残る割合だけ上げている。
      SimDistanceBand.sprint: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 27.0, goalSpreadMeters: 50.0, carryOver: 0.60, kickSlopeSeconds: 0.44),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 27.0, goalSpreadMeters: 50.0, carryOver: 0.56, kickSlopeSeconds: 0.44),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 33.0, goalSpreadMeters: 53.0, carryOver: 0.39, kickSlopeSeconds: 0.87),
      },
      // 中(1400〜1800m)。スローはサンプル18件のためミドルから補っている。
      SimDistanceBand.mile: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 27.0, goalSpreadMeters: 60.0, carryOver: 0.68, kickSlopeSeconds: -0.09),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 27.0, goalSpreadMeters: 60.0, carryOver: 0.65, kickSlopeSeconds: -0.09),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 30.0, goalSpreadMeters: 60.0, carryOver: 0.64, kickSlopeSeconds: -0.21),
      },
      // 中長(1800〜2200m)。ハイ以外はサンプル不足のためハイから補っている。
      SimDistanceBand.middle: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 60.0, carryOver: 0.68, kickSlopeSeconds: -0.33),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 60.0, carryOver: 0.66, kickSlopeSeconds: -0.33),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 60.0, carryOver: 0.64, kickSlopeSeconds: -0.33),
      },
      // 長(2200m〜)。JRAのダート重賞にはほぼ無く、実測できないため中長と同値。
      SimDistanceBand.long: {
        SimPace.slow: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 60.0, carryOver: 0.68, kickSlopeSeconds: -0.33),
        SimPace.middle: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 60.0, carryOver: 0.66, kickSlopeSeconds: -0.33),
        SimPace.high: RaceFinishConstants(
            midSpreadMeters: 28.0, goalSpreadMeters: 60.0, carryOver: 0.64, kickSlopeSeconds: -0.33),
      },
    },
  };

  /// 馬場 × 距離帯 × ペース の実測定数を返す。
  static RaceFinishConstants constantsFor(
    SimSurface surface,
    SimDistanceBand band,
    SimPace pace,
  ) {
    return _constants[surface]![band]![pace]!;
  }

  /// [追加] 展開シミュ一般論見直しStep4 距離(m)から距離帯を返す (v.2026.9.29+26092907)
  static SimDistanceBand bandOfMeters(int meters) {
    if (meters <= sprintMaxMeters) return SimDistanceBand.sprint;
    if (meters <= mileMaxMeters) return SimDistanceBand.mile;
    if (meters <= middleMaxMeters) return SimDistanceBand.middle;
    return SimDistanceBand.long;
  }

  /// 'ハイ' / 'スロー' を含む文字列を SimPace に変換する。それ以外はミドル。
  static SimPace paceFromLabel(String? label) {
    if (label == null) return SimPace.middle;
    if (label.contains('ハイ')) return SimPace.high;
    if (label.contains('スロー')) return SimPace.slow;
    return SimPace.middle;
  }

  /// SimPace を既存コードが使う日本語ラベルへ変換する。
  static String paceLabel(SimPace pace) {
    if (pace == SimPace.high) return 'ハイペース';
    if (pace == SimPace.slow) return 'スローペース';
    return 'ミドルペース';
  }

  /// 面子の脚質分布からペースを判定する(設計書 5-1)。
  /// [styleDistributions] は出走各馬の LegStyleProfile.styleDistribution
  /// (合計1.0の割合。取消馬は呼び出し側で除いておくこと)。
  static SimPace predictPace({
    required List<Map<String, double>> styleDistributions,
    required int distanceMeters,
    required SimSurface surface,
  }) {
    if (styleDistributions.isEmpty) return SimPace.middle;

    int nigeCount = 0;
    int senkoCount = 0;
    for (final d in styleDistributions) {
      final nigeRate = d['逃げ'] ?? 0.0;
      final senkoRate = d['先行'] ?? 0.0;
      if (nigeRate >= nigeShareThreshold) {
        nigeCount++;
      } else if (senkoRate >= senkoShareThreshold) {
        senkoCount++;
      }
    }

    int point;
    if (nigeCount <= 0) {
      point = 0;
    } else if (nigeCount == 1) {
      point = 1;
    } else if (nigeCount == 2) {
      point = 2;
    } else {
      point = 3;
    }

    if (senkoCount * 3 >= styleDistributions.length) point += 1;
    if (distanceMeters > 0 && distanceMeters <= 1400) point += 1;
    if (distanceMeters >= 2200) point -= 1;
    if (surface == SimSurface.dirt) point += 2;

    if (point <= 1) return SimPace.slow;
    if (point <= 3) return SimPace.middle;
    return SimPace.high;
  }

  /// 過去成績から、位置による下駄を割り引いた末脚を求める(設計書 5-2)。
  /// [records] は新しい順。
  static HorseFinishKick calculateKick(List<HorseRaceRecord> records) {
    double totalWeighted = 0.0;
    double totalWeight = 0.0;
    double weight = 1.0;
    int used = 0;

    for (final record in records.take(kickMaxRecords)) {
      final value = _recordKickSeconds(record);
      if (value == null) {
        weight *= recencyDecay;
        continue;
      }
      totalWeighted += value * weight;
      totalWeight += weight;
      weight *= recencyDecay;
      used++;
    }

    if (used == 0 || totalWeight <= 0.0) return HorseFinishKick.empty;

    final raw = totalWeighted / totalWeight;
    final confidence =
        (used / kickFullSampleCount).clamp(0.0, 1.0).toDouble();
    return HorseFinishKick(
      kickSeconds: raw * kickCarryFactor * confidence,
      confidence: confidence,
      sampleCount: used,
      rawKickSeconds: raw,
    );
  }

  /// 1走分の割引き後の末脚(秒)。必要な値が欠けていれば null。
  /// 割引きの強さは、その過去走自身の馬場・距離帯・ペースから引く。
  static double? _recordKickSeconds(HorseRaceRecord record) {
    final last3F = raceLast3F(record.pace);
    if (last3F == null) return null;

    final agari = double.tryParse(record.agari.trim());
    if (agari == null || agari <= 0.0) return null;

    final rate = lastCornerRate(record.cornerPassage, record.numberOfHorses);
    if (rate == null) return null;

    final surface = surfaceOfDistanceText(record.distance);
    if (surface == null) return null;

    // [修正] 展開シミュ一般論見直しStep4 その過去走自身の距離帯で割引きの強さを引く (v.2026.9.29+26092907)
    final meters = distanceMetersOfText(record.distance);
    if (meters == null || meters <= 0) return null;
    final band = bandOfMeters(meters);

    final pace = paceFromLabel(RaceDataParser.calculatePace(record.pace));
    final slope = constantsFor(surface, band, pace).kickSlopeSeconds;

    // 生の末脚 = レースの後半3F − その馬の上がり3F。正 = レースの上がりより速い。
    // そこから「後ろにいたぶんの下駄」を引く。
    return (last3F - agari) - slope * (rate - 0.5);
  }

  /// "34.3-33.4" 形式のペース文字列から後半3F(33.4)を取り出す。
  static double? raceLast3F(String paceText) {
    final parts = paceText.split('-');
    if (parts.length < 2) return null;
    final value = double.tryParse(parts[1].trim());
    if (value == null || value <= 0.0) return null;
    return value;
  }

  /// 最終コーナーの通過順位率(0.0=先頭, 1.0=最後方)。取得できなければ null。
  static double? lastCornerRate(String cornerPassage, String numberOfHorses) {
    final count = int.tryParse(numberOfHorses.trim());
    if (count == null || count <= 0) return null;

    int? last;
    for (final part in cornerPassage.split('-')) {
      final value = int.tryParse(part.trim());
      if (value != null) last = value;
    }
    if (last == null || last <= 0) return null;

    return (last / count).clamp(0.0, 1.0).toDouble();
  }

  /// "芝1600" / "ダ1200" / "障3380" から馬場種別を返す。障害・不明は null。
  static SimSurface? surfaceOfDistanceText(String distanceText) {
    final text = distanceText.trim();
    if (text.startsWith('障')) return null;
    if (text.startsWith('ダ')) return SimSurface.dirt;
    if (text.startsWith('芝')) return SimSurface.turf;
    return null;
  }

  /// [追加] 展開シミュ一般論見直しStep4 "芝1600" / "ダ1200" から距離(m)を取り出す (v.2026.9.29+26092907)
  static int? distanceMetersOfText(String distanceText) {
    final match = RegExp(r'(\d+)').firstMatch(distanceText);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// ゴール時点の「先頭からの遅れ(位置スコアの点)」を組み立てる(設計書 5-4)。
  /// [frontScoreAt4c] は4コーナー終了時点の、先頭からの遅れ(点・0以上)。
  /// [abilityScore] は既存の直線要素(総合適性・スピード指数・騎手・斤量など)の合計(点)。
  static double goalScore({
    required double frontScoreAt4c,
    required double carryOver,
    required double kickSeconds,
    required double meanKickSeconds,
    required double abilityScore,
    double scoreToMeters = 16.0,
  }) {
    final positionPart = frontScoreAt4c * carryOver;
    final kickPart =
        (meanKickSeconds - kickSeconds) * metersPerSecond / scoreToMeters;
    final abilityPart =
        abilityScore.clamp(-abilityClampScore, abilityClampScore).toDouble();
    return positionPart + kickPart + abilityPart;
  }

  /// 馬群の広がりを目標に合わせる倍率(設計書 5-5)。
  /// [maxFrontScore] はそのキーフレームの「先頭からの遅れ」の最大値(点)。
  static double spreadScale({
    required double maxFrontScore,
    required double targetSpreadMeters,
    double scoreToMeters = 16.0,
  }) {
    final currentMeters = maxFrontScore * scoreToMeters;
    if (currentMeters <= 0.0) return 1.0;
    return (targetSpreadMeters / currentMeters)
        .clamp(spreadScaleMin, spreadScaleMax)
        .toDouble();
  }
}
