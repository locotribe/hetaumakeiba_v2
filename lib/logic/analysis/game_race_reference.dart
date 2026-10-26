// lib/logic/analysis/game_race_reference.dart
// [追加] 展開シミュゲーム式移植Step4a: 同じレース名の過去レースから、走破タイム・1000m通過のスライダーの範囲と初期値を作る純粋ロジック。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の6章 (v.2026.10.27+26102704)

import 'package:hetaumakeiba_v2/logic/analysis/speed_index_base_time.dart';

/// 過去レース1つぶんの時計。
class GamePastRaceTime {
  final String raceId;

  /// 勝ち時計(秒)
  final double winnerSeconds;

  /// 先頭の1000m通過(秒)。ラップが無ければ null
  final double? first1000Seconds;

  /// 馬場状態(良・稍重・重・不良)。分からなければ null
  final String? going;

  /// その日のクッション値。分からなければ null
  final double? cushion;

  const GamePastRaceTime({
    required this.raceId,
    required this.winnerSeconds,
    this.first1000Seconds,
    this.going,
    this.cushion,
  });
}

/// スライダーの範囲と初期値。
class GameRaceReference {
  /// 計算に使った過去レース(0件なら基準タイムからの仮の値)
  final List<GamePastRaceTime> races;

  /// 過去の勝ち時計の最速・平均・最遅(秒)
  final double winnerMin;
  final double winnerMean;
  final double winnerMax;

  /// 過去の1000m通過の最速・平均・最遅(秒)。ラップが無ければ null
  final double? first1000Min;
  final double? first1000Mean;
  final double? first1000Max;

  /// 今回の馬場状態・クッション値に合わせた、勝ち時計の初期値(秒)
  final double defaultWinnerSeconds;

  /// 過去レースが足りず、基準タイムから作った仮の値か
  final bool isFallback;

  const GameRaceReference({
    required this.races,
    required this.winnerMin,
    required this.winnerMean,
    required this.winnerMax,
    required this.first1000Min,
    required this.first1000Mean,
    required this.first1000Max,
    required this.defaultWinnerSeconds,
    required this.isFallback,
  });

  /// スライダーの端は、過去の最速・最遅から外へこの秒数だけ広げる
  static const double sliderMargin = 1.0;

  /// 過去レースが無いときの勝ち時計の幅(初期値から ± 秒)
  static const double fallbackHalfWidth = 2.0;

  /// 過去レースを使うのに必要な最少の件数
  static const int minRaces = 2;

  /// クッション値 +1 あたりの、1000mあたりの時計の変化(秒)。実測(芝・馬場状態をそろえたとき)
  static const double cushionSecondsPer1000m = -0.1;

  double get sliderWinnerMin => winnerMin - sliderMargin;
  double get sliderWinnerMax => winnerMax + sliderMargin;
  double? get sliderFirst1000Min =>
      first1000Min == null ? null : first1000Min! - sliderMargin;
  double? get sliderFirst1000Max =>
      first1000Max == null ? null : first1000Max! + sliderMargin;

  /// 過去レースから作る。件数が [minRaces] 未満なら null。
  /// 過去の勝ち時計を、それぞれの馬場状態・クッション値の分だけ「良・平均のクッション値」にそろえて平均し、
  /// 今回の [going]・[cushion] の分を足して初期値にする。
  static GameRaceReference? fromPastRaces(
    List<GamePastRaceTime> races, {
    required int distance,
    required bool isDirt,
    required String? going,
    required double? cushion,
  }) {
    if (races.length < minRaces) return null;
    double minW = double.infinity;
    double maxW = double.negativeInfinity;
    double sumW = 0.0;
    double? min1;
    double? max1;
    double sum1 = 0.0;
    int n1 = 0;
    double sumC = 0.0;
    int nC = 0;
    for (final r in races) {
      if (r.winnerSeconds < minW) minW = r.winnerSeconds;
      if (r.winnerSeconds > maxW) maxW = r.winnerSeconds;
      sumW += r.winnerSeconds;
      final f = r.first1000Seconds;
      if (f != null) {
        if (min1 == null || f < min1) min1 = f;
        if (max1 == null || f > max1) max1 = f;
        sum1 += f;
        n1++;
      }
      if (!isDirt && r.cushion != null) {
        sumC += r.cushion!;
        nC++;
      }
    }
    final refCushion = nC > 0 ? sumC / nC : null;
    double sumNorm = 0.0;
    for (final r in races) {
      sumNorm += r.winnerSeconds -
          goingOffsetSeconds(r.going, isDirt) -
          cushionOffsetSeconds(r.cushion, refCushion, distance, isDirt);
    }
    final normMean = sumNorm / races.length;
    final def = normMean +
        goingOffsetSeconds(going, isDirt) +
        cushionOffsetSeconds(cushion, refCushion, distance, isDirt);
    return GameRaceReference(
      races: races,
      winnerMin: minW,
      winnerMean: sumW / races.length,
      winnerMax: maxW,
      first1000Min: min1,
      first1000Mean: n1 > 0 ? sum1 / n1 : null,
      first1000Max: max1,
      defaultWinnerSeconds: def,
      isFallback: false,
    );
  }

  /// 過去レースが足りないときの仮の値。スピード指数の基準タイム(OP級)を初期値にし、± [fallbackHalfWidth] 秒を範囲にする。
  /// 基準タイムが作れないコースなら null。
  static GameRaceReference? fallback({
    required int distance,
    required bool isDirt,
    required int year,
    required String? venueName,
    required String? going,
  }) {
    final cond = normalizeGoing(going) ?? '良';
    final resolved = SpeedIndexBaseTime.resolve(
      surface: isDirt ? 'ダ' : '芝',
      meters: distance,
      year: year,
      venueName: venueName,
      normalizedCondition: cond,
    );
    if (resolved == null) return null;
    final t = resolved.baseTime;
    return GameRaceReference(
      races: const [],
      winnerMin: t - fallbackHalfWidth + sliderMargin,
      winnerMean: t,
      winnerMax: t + fallbackHalfWidth - sliderMargin,
      first1000Min: null,
      first1000Mean: null,
      first1000Max: null,
      defaultWinnerSeconds: t,
      isFallback: true,
    );
  }

  /// 馬場状態による時計の差(秒)。スピード指数の基準タイムと同じ値(良=0)。分からなければ0
  static double goingOffsetSeconds(String? going, bool isDirt) {
    final g = normalizeGoing(going);
    if (g == null) return 0.0;
    const turf = {'良': 0.0, '稍重': 0.933, '重': 1.615, '不良': 3.796};
    const dirt = {'良': 0.0, '稍重': -0.384, '重': -1.471, '不良': -1.862};
    return (isDirt ? dirt[g] : turf[g]) ?? 0.0;
  }

  /// クッション値による時計の差(秒)。芝だけ。どちらかが分からなければ0
  static double cushionOffsetSeconds(
      double? cushion, double? refCushion, int distance, bool isDirt) {
    if (isDirt || cushion == null || refCushion == null) return 0.0;
    return cushionSecondsPer1000m * distance / 1000.0 * (cushion - refCushion);
  }

  /// 馬場状態の書き方をそろえる(「稍」→「稍重」、「不」→「不良」)。読めなければ null
  static String? normalizeGoing(String? going) {
    if (going == null) return null;
    final g = going.trim();
    if (g.startsWith('不')) return '不良';
    if (g.startsWith('稍')) return '稍重';
    if (g.startsWith('重')) return '重';
    if (g.startsWith('良')) return '良';
    return null;
  }

  /// レース結果のラップ文字列(「ラップ: 12.1 - 10.7 - ...」を含む行)から、1ハロンごとの秒を取り出す。無ければ null
  static List<double>? parseLaps(List<String> lapTimes) {
    for (final line in lapTimes) {
      if (!line.startsWith('ラップ')) continue;
      final laps = RegExp(r'\d+\.\d')
          .allMatches(line)
          .map((m) => double.parse(m.group(0)!))
          .toList();
      return laps.isEmpty ? null : laps;
    }
    return null;
  }

  /// ラップから先頭の1000m通過(秒)。最初の区間が100mか200mのときだけ求める
  static double? first1000Of(List<double> laps, int distance) {
    if (laps.isEmpty) return null;
    final firstLen = distance - 200 * (laps.length - 1);
    if (firstLen != 100 && firstLen != 200) return null;
    int acc = firstLen;
    double sum = laps[0];
    int i = 1;
    while (acc < 1000 && i < laps.length) {
      sum += laps[i];
      acc += 200;
      i++;
    }
    return acc == 1000 ? sum : null;
  }

  /// 「1:57.0」「58.3」形式の時計を秒にする。読めなければ null
  static double? parseTime(String text) {
    final m = RegExp(r'^(?:(\d+):)?(\d+\.\d)$').firstMatch(text.trim());
    if (m == null) return null;
    final min = m.group(1) == null ? 0 : int.parse(m.group(1)!);
    return min * 60 + double.parse(m.group(2)!);
  }

  /// 秒を「1:57.0」(60秒未満は「58.3」)にする
  static String formatTime(double seconds) {
    final tenths = (seconds * 10).round();
    final min = tenths ~/ 600;
    final rest = (tenths % 600) / 10.0;
    final s = rest.toStringAsFixed(1);
    if (min == 0) return s;
    return '$min:${s.padLeft(4, '0')}';
  }
}