// lib/logic/analysis/game_race_inputs.dart
// [追加] 展開シミュゲーム式移植Step4b: 画面からゲーム式エンジンへ渡す値(騎手の3着内率・馬場状態・過去レースの時計・乱数の種など)を作る純粋ロジック。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の5章・6章・7章 (v.2026.10.27+26102705)

import 'package:hetaumakeiba_v2/logic/analysis/game_race_display.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_reference.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';

/// レース結果のコース情報(「芝左2000m / 天候 : 曇 / 芝 : 良」)を読んだもの。
class GameRaceInfo {
  /// 芝なら false、ダートなら true
  final bool isDirt;
  final int distance;

  /// 馬場状態(良・稍重・重・不良)。読めなければ null
  final String? going;

  const GameRaceInfo(this.isDirt, this.distance, this.going);
}

class GameRaceInputs {
  GameRaceInputs._();

  /// 騎手の3着内率を、騎乗数が少ないときに寄せる先(全体の平均)
  static const double jockeyPriorRate = 0.2;

  /// 騎手の3着内率を寄せる強さ(この騎乗数ぶん、平均の成績を足す。仮の値)
  static const double jockeyPriorRides = 20.0;

  /// 過去レースを使う最大の件数(新しい順)
  static const int maxPastRaces = 30;

  /// クッション値のスライダーの端を、過去の最小・最大から外へ広げる幅
  static const double cushionMargin = 0.5;

  /// 過去のクッション値が無いときのスライダーの範囲
  static const double cushionFallbackMin = 7.0;
  static const double cushionFallbackMax = 12.0;

  /// 騎手の3着内率(0〜1)。騎乗数が少ないほど [jockeyPriorRate] に寄せる。成績が無ければ null
  static double? jockeyShowRateOf(FactorStats? stats) {
    if (stats == null || stats.raceCount <= 0) return null;
    return (stats.showCount + jockeyPriorRides * jockeyPriorRate) /
        (stats.raceCount + jockeyPriorRides);
  }

  /// 含水率(ゴール前)から見込む馬場状態。値が無ければ null。
  /// 区切りは1年分の実測(芝2,996・ダート1,427レース。朝の含水率と発表の馬場状態)で、ずれ(段階の差の平均)が最も小さくなる値。
  /// 芝の含水率は馬場状態とのつながりが弱く(含水率17%超でも4割は良)、区切りは高め
  static String? goingOfMoisture(double? moisture, bool isDirt) {
    if (moisture == null) return null;
    if (isDirt) {
      if (moisture <= 7.0) return '良';
      if (moisture <= 12.0) return '稍重';
      if (moisture <= 16.5) return '重';
      return '不良';
    }
    if (moisture <= 18.0) return '良';
    if (moisture <= 20.0) return '稍重';
    if (moisture <= 21.5) return '重';
    return '不良';
  }

  /// 芝の馬場状態ごとの、よくあるクッション値(1年分の実測の中央値)。馬場状態のボタンを押したときのクッション値に使う
  static const Map<String, double> typicalCushion = {
    '良': 9.4,
    '稍重': 8.8,
    '重': 8.5,
    '不良': 8.1,
  };

  /// クッション値として使える範囲。外れた値(予測の計算が外れたときなど)は使わない
  static const double cushionValidMin = 5.0;
  static const double cushionValidMax = 13.0;

  /// クッション値のスライダーの端の限界(実測は6.2〜11.9)
  static const double cushionSliderFloor = 6.0;
  static const double cushionSliderCeil = 12.5;

  /// クッション値が使える範囲なら0.1刻みに丸めて返す。外れていれば null
  static double? validCushion(double? value) {
    if (value == null || value < cushionValidMin || value > cushionValidMax) {
      return null;
    }
    return (value * 10).round() / 10.0;
  }

  /// 馬場状態によるHP消費の補正(ゲームの値。芝: 重・不良1.02、ダート: 重1.01・不良1.02)
  static double groundHpOf(String? going, bool isDirt) {
    final g = GameRaceReference.normalizeGoing(going);
    if (isDirt) {
      if (g == '重') return 1.01;
      if (g == '不良') return 1.02;
      return 1.0;
    }
    if (g == '重' || g == '不良') return 1.02;
    return 1.0;
  }

  /// レースIDから乱数の種を作る(同じレースなら毎回同じ結果になるように)
  static int seedOf(String raceId) {
    int h = 17;
    for (final c in raceId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// コース情報の文字列を読む。芝・ダート以外(障害など)や読めないときは null
  static GameRaceInfo? parseRaceInfo(String raceInfo) {
    final text = raceInfo.trim();
    final bool isDirt;
    if (text.startsWith('芝')) {
      isDirt = false;
    } else if (text.startsWith('ダ')) {
      isDirt = true;
    } else {
      return null;
    }
    final d = RegExp(r'(\d{3,4})m').firstMatch(text);
    if (d == null) return null;
    final g = RegExp(r'(?:芝|ダート)\s*:\s*(\S+)').allMatches(text);
    final going =
        g.isEmpty ? null : GameRaceReference.normalizeGoing(g.last.group(1));
    return GameRaceInfo(isDirt, int.parse(d.group(1)!), going);
  }

  /// 過去レース1つを、時計の材料にする。競馬場・芝ダ・距離が違う、今回より後、勝ち時計が読めないものは null。
  /// クッション値は後から [GamePastRaceTime] を作り直して入れる。
  static GamePastRaceTime? pastRaceTimeOf(
    RaceResult race, {
    required String venueCode,
    required int distance,
    required bool isDirt,
    required DateTime? before,
    required String excludeRaceId,
  }) {
    if (race.raceId == excludeRaceId) return null;
    if (race.raceId.length < 6 || race.raceId.substring(4, 6) != venueCode) {
      return null;
    }
    final info = parseRaceInfo(race.raceInfo);
    if (info == null || info.isDirt != isDirt || info.distance != distance) {
      return null;
    }
    if (before != null) {
      final day = parseRaceDateForSpeedIndex(race.raceDate);
      if (day == null || !day.isBefore(before)) return null;
    }
    double? winner;
    for (final h in race.horseResults) {
      if (h.rank.trim() == '1') {
        winner = GameRaceReference.parseTime(h.time);
        if (winner != null) break;
      }
    }
    if (winner == null) return null;
    final laps = GameRaceReference.parseLaps(race.lapTimes);
    return GamePastRaceTime(
      raceId: race.raceId,
      winnerSeconds: winner,
      first1000Seconds:
          laps == null ? null : GameRaceReference.first1000Of(laps, distance),
      going: info.going,
    );
  }

  /// 過去レースを新しい順に並べ、[maxPastRaces] 件までにする
  static List<RaceResult> latestRaces(List<RaceResult> races) {
    final sorted = List<RaceResult>.from(races)
      ..sort((a, b) {
        final da = parseRaceDateForSpeedIndex(a.raceDate);
        final db = parseRaceDateForSpeedIndex(b.raceDate);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    return sorted.length > maxPastRaces
        ? sorted.sublist(0, maxPastRaces)
        : sorted;
  }

  /// クッション値のスライダーの範囲(0.1刻みに丸める)。過去の値と、今回の候補の値([extras])が全部入るようにする。
  /// 使える範囲から外れた値は無視し、端は [cushionSliderFloor]〜[cushionSliderCeil] に収める
  static (double, double) cushionRangeOf(
      List<GamePastRaceTime> races, List<double?> extras) {
    final values = <double>[
      for (final r in races)
        if (validCushion(r.cushion) != null) r.cushion!,
      for (final e in extras)
        if (validCushion(e) != null) e!,
    ];
    if (values.isEmpty) return (cushionFallbackMin, cushionFallbackMax);
    double lo = values.first;
    double hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    lo = ((lo - cushionMargin) * 10).floor() / 10.0;
    hi = ((hi + cushionMargin) * 10).ceil() / 10.0;
    if (lo < cushionSliderFloor) lo = cushionSliderFloor;
    if (hi > cushionSliderCeil) hi = cushionSliderCeil;
    return (lo, hi);
  }

  /// ゴールした後も、最後の速さで少しずつ減速しながら走り続ける点を足す(再生で馬がゴールの所で止まらないように)。
  /// 全馬が、いちばん遅くゴールした馬の [extraSeconds] 秒後まで走る。ゴールまでの距離はマイナスになる
  static List<List<GameRaceTrackPoint>> withOverrun(
    List<List<GameRaceTrackPoint>> tracks, {
    double extraSeconds = overrunSeconds,
    double stepSeconds = 0.5,
    double decel = overrunDecel,
  }) {
    double end = 0.0;
    for (final tr in tracks) {
      if (tr.isNotEmpty && tr.last.time > end) end = tr.last.time;
    }
    end += extraSeconds;
    return [
      for (final tr in tracks) _overrunOf(tr, end, stepSeconds, decel),
    ];
  }

  /// ゴール後に走り続ける秒数
  static const double overrunSeconds = 3.0;

  /// ゴール後の減速(m/s²)
  static const double overrunDecel = 1.0;

  static List<GameRaceTrackPoint> _overrunOf(
      List<GameRaceTrackPoint> tr, double end, double step, double decel) {
    if (tr.length < 2) return tr;
    final last = tr.last;
    final prev = tr[tr.length - 2];
    final dt = last.time - prev.time;
    double v = dt > 0
        ? (prev.distanceFromGoal - last.distanceFromGoal) / dt
        : 0.0;
    if (v <= 0) return tr;
    final out = List<GameRaceTrackPoint>.from(tr);
    double t = last.time;
    double d = last.distanceFromGoal;
    while (t < end - 1e-9) {
      final h = (end - t) < step ? (end - t) : step;
      final v2 = (v - decel * h) > 0 ? v - decel * h : 0.0;
      d -= (v + v2) / 2.0 * h;
      v = v2;
      t += h;
      out.add(GameRaceTrackPoint(t, d, last.laneRank));
    }
    return out;
  }

  /// 結果の表の通過順の見出し。コーナーの数で変える
  static String checkpointHeaderOf(int cornerCount) {
    if (cornerCount >= 2) return '3角-4角-着';
    if (cornerCount == 1) return '4角-着';
    return '中間-着';
  }

  /// 通過点ごとの平均順位から、見出しに合わせた「10-10-4」の形の文字列を作る(最後の2つか3つ)
  static String checkpointTextOf(List<double> meanRanks, int cornerCount) {
    if (meanRanks.isEmpty) return '-';
    final take = cornerCount >= 2 ? 3 : 2;
    final start = meanRanks.length > take ? meanRanks.length - take : 0;
    return meanRanks.sublist(start).map((r) => r.round().toString()).join('-');
  }
}