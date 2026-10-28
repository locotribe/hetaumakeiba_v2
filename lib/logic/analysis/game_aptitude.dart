// lib/logic/analysis/game_aptitude.dart
// [追加] 展開シミュ改良Step2(案B): 出走馬の過去走・年齢・性別・馬体重から「適性の点数」の材料を作る純粋ロジック。
// 点数はゲームの距離適性・バ場適性に当たり、能力値の作り方(game_ability_builder.dart)で終盤の速度加算に足す。
// 定義と重みは原型の hook_apt.py・caseB_feat.py(参照実装 aptref.py)と同じ。設計は memory/展開シミュ_改良案_考察.md の案B (v.2026.10.28+26102802)

import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 1頭ぶんの生の値。分からない値は null。
class GameAptitudeRaw {
  /// 今回と同じ芝ダで、距離が今回±200m の過去走の数(取消・中止も数える)。芝・ダートの過去走が無ければ null
  final int? nearCount;

  /// その過去走の3着内率(0〜1)。数が0なら null
  final double? nearTop3Rate;

  /// 3着内に入った過去走の最長距離(m。障害も含む)。無ければ null
  final double? maxTop3Distance;

  /// 直近5走(芝・ダートだけ)のうち、今回と同じ芝ダの割合(0〜1)
  final double? sameSurfaceShare;

  /// 前走(芝・ダートだけ)の距離(m)
  final double? lastDistance;

  /// 直近5走(芝・ダートだけ)の斤量の平均(kg)
  final double? pastCarriedWeight;

  /// 前の記録(障害・取消も含む)からの日数
  final double? daysSinceLast;

  /// 年齢
  final double? age;

  /// 牝馬なら true
  final bool isFemale;

  /// 今回の馬体重の増減(kg)。発表前は null
  final double? bodyWeightChange;

  const GameAptitudeRaw({
    this.nearCount,
    this.nearTop3Rate,
    this.maxTop3Distance,
    this.sameSurfaceShare,
    this.lastDistance,
    this.pastCarriedWeight,
    this.daysSinceLast,
    this.age,
    this.isFemale = false,
    this.bodyWeightChange,
  });
}

class GameAptitude {
  GameAptitude._();

  /// 点数の項の名前(足す順。原型の f_near_top3〜f_hw_chg_abs の順)
  static const List<String> termKeys = [
    'nearTop3',
    'nearNone',
    'overBest',
    'newSurface',
    'distanceUp',
    'age',
    'female',
    'restLong',
    'bodyWeightChange',
  ];

  /// 芝の重み(シミュの平均着順1つぶんあたり。原型の eval_out/caseB_weights.json「芝_経験+年齢・性・休み・馬体重」。
  /// 改良Step4 で決め直す)
  static const Map<String, double> weightsTurf = {
    'nearTop3': 1.663635323685121,
    'nearNone': -0.25090360613839957,
    'overBest': -0.26482447258458325,
    'newSurface': -0.32893133465853036,
    'distanceUp': -0.07876218047673855,
    'age': -0.1380011665598384,
    'female': -0.2704113779223664,
    'restLong': -0.10372879013462795,
    'bodyWeightChange': -0.06541218889378252,
  };

  /// ダートの重み(同「ダ_経験+年齢・性・休み・馬体重」)
  static const Map<String, double> weightsDirt = {
    'nearTop3': 0.6636095509161335,
    'nearNone': -0.25067343875647247,
    'overBest': -0.4239141771940642,
    'newSurface': -0.3689353038378786,
    'distanceUp': -0.12147058275061343,
    'age': -0.08649475813556108,
    'female': -0.28205839448329195,
    'restLong': -0.21564708170119043,
    'bodyWeightChange': -0.10806211175527462,
  };

  static Map<String, double> weightsOf({required bool isDirt}) =>
      isDirt ? weightsDirt : weightsTurf;

  /// 同じ芝ダの過去走を「近い距離」とみなす幅(m)
  static const double nearDistanceRange = 200.0;

  /// 3着内率を縮める先と強さ(この数ぶん、平均の成績を足す)
  static const double nearPriorRate = 0.25;
  static const double nearPriorCount = 3.0;

  /// 3着内の最長距離をこれより超えると不利(m)
  static const double overBestMargin = 100.0;

  /// 距離延長の単位(m)
  static const double distanceUpUnit = 200.0;

  /// 休み明けとみなす日数
  static const double restLongDays = 90.0;

  /// 馬体重の増減の単位(kg)
  static const double bodyWeightUnit = 10.0;

  /// 斤量などの平均をとる過去走の数(芝・ダートだけ)
  static const int recentCount = 5;

  static double? _num(String s) {
    final v = double.tryParse(s.trim());
    return (v == null || v.isNaN || v.isInfinite) ? null : v;
  }

  /// 1頭ぶんの生の値を作る。[records] は戦績(並びは問わない)。[raceDay] より前の日付の記録だけを使う(null なら日付で絞らない)
  static GameAptitudeRaw rawOf(
    List<HorseRaceRecord> records, {
    required DateTime? raceDay,
    required int distance,
    required bool isDirt,
    String? sexAndAge,
    String? horseWeight,
  }) {
    final past = <_PastRun>[];
    for (final r in records) {
      final d = parseHorseRecordDate(r.date);
      if (d == null || (raceDay != null && !d.isBefore(raceDay))) continue;
      final ds = r.distance;
      past.add(_PastRun(
        d,
        ds.isEmpty ? '' : ds.substring(0, 1),
        ds.length > 1 ? _num(ds.substring(1)) : null,
        _num(r.rank),
        _num(r.carriedWeight),
      ));
    }
    // 古い順(同じ日は元の並びのまま)
    final indexed = past.asMap().entries.toList()
      ..sort((a, b) {
        final c = a.value.day.compareTo(b.value.day);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    final runs = [for (final e in indexed) e.value];
    final surf = isDirt ? 'ダ' : '芝';

    double? daysSince;
    if (runs.isNotEmpty && raceDay != null) {
      // 夏時間などで1日が24時間でない端末でもずれないよう、UTC の日付どうしで数える
      final last = runs.last.day;
      daysSince = DateTime.utc(raceDay.year, raceDay.month, raceDay.day)
          .difference(DateTime.utc(last.year, last.month, last.day))
          .inDays
          .toDouble();
    }
    double? maxTop3;
    for (final x in runs) {
      final rk = x.rank;
      final dist = x.distance;
      if (rk != null && rk <= 3 && dist != null) {
        if (maxTop3 == null || dist > maxTop3) maxTop3 = dist;
      }
    }
    int? nearCount;
    double? nearRate;
    double? share;
    double? lastDist;
    double? pastWc;
    final flat = [
      for (final x in runs)
        if (x.surface == '芝' || x.surface == 'ダ') x
    ];
    if (flat.isNotEmpty) {
      final last = flat.length > recentCount
          ? flat.sublist(flat.length - recentCount)
          : flat;
      double wcSum = 0.0;
      int wcN = 0;
      int same = 0;
      for (final x in last) {
        final w = x.carriedWeight;
        if (w != null) {
          wcSum += w;
          wcN++;
        }
        if (x.surface == surf) same++;
      }
      pastWc = wcN > 0 ? wcSum / wcN : null;
      lastDist = last.last.distance;
      share = same / last.length;
      int n = 0;
      int top3 = 0;
      for (final x in flat) {
        final dist = x.distance;
        if (x.surface == surf &&
            dist != null &&
            (dist - distance).abs() <= nearDistanceRange) {
          n++;
          final rk = x.rank;
          if (rk != null && rk <= 3) top3++;
        }
      }
      nearCount = n;
      nearRate = n > 0 ? top3 / n : null;
    }

    double? age;
    bool female = false;
    final sa = sexAndAge?.trim() ?? '';
    if (sa.isNotEmpty) {
      female = sa.startsWith('牝');
      age = sa.length > 1 ? _num(sa.substring(1)) : null;
    }
    double? hwChg;
    final hw = horseWeight;
    if (hw != null && hw.isNotEmpty) {
      final m = RegExp(r'(\d+)\(([+-]?\d+)\)').firstMatch(hw);
      if (m != null) hwChg = int.parse(m.group(2)!).toDouble();
    }
    return GameAptitudeRaw(
      nearCount: nearCount,
      nearTop3Rate: nearRate,
      maxTop3Distance: maxTop3,
      sameSurfaceShare: share,
      lastDistance: lastDist,
      pastCarriedWeight: pastWc,
      daysSinceLast: daysSince,
      age: age,
      isFemale: female,
      bodyWeightChange: hwChg,
    );
  }

  /// 出走馬全員の生の値から、点数の項(名前は [termKeys])を作る。年齢・牝はレースの中の平均を引く
  static List<Map<String, double>> termsOf(
      List<GameAptitudeRaw> raws, int distance) {
    if (raws.isEmpty) return const [];
    double ageSum = 0.0;
    int ageN = 0;
    double femaleSum = 0.0;
    for (final x in raws) {
      final a = x.age;
      if (a != null) {
        ageSum += a;
        ageN++;
      }
      femaleSum += x.isFemale ? 1.0 : 0.0;
    }
    final ageMean = ageN > 0 ? ageSum / ageN : null;
    final femaleMean = femaleSum / raws.length;
    final d = distance.toDouble();
    return [
      for (final x in raws) _termsOf(x, d, ageMean, femaleMean),
    ];
  }

  static Map<String, double> _termsOf(
      GameAptitudeRaw x, double d, double? ageMean, double femaleMean) {
    final n = (x.nearCount ?? 0).toDouble();
    final t3 = x.nearTop3Rate ?? nearPriorRate;
    final last = x.lastDistance;
    final dc = last != null ? d - last : null;
    final age = x.age;
    final days = x.daysSinceLast;
    final hw = x.bodyWeightChange;
    return {
      'nearTop3': ((t3 * n + nearPriorRate * nearPriorCount) /
              (n + nearPriorCount)) -
          nearPriorRate,
      'nearNone': n == 0 ? 1.0 : 0.0,
      'overBest': (d - (x.maxTop3Distance ?? 0.0)) > overBestMargin ? 1.0 : 0.0,
      'newSurface': x.sameSurfaceShare == 0 ? 1.0 : 0.0,
      'distanceUp': dc != null ? (dc > 0.0 ? dc : 0.0) / distanceUpUnit : 0.0,
      'age': (age != null && ageMean != null) ? age - ageMean : 0.0,
      'female': (x.isFemale ? 1.0 : 0.0) - femaleMean,
      'restLong': (days != null && days >= restLongDays) ? 1.0 : 0.0,
      'bodyWeightChange': hw != null ? hw.abs() / bodyWeightUnit : 0.0,
    };
  }

  /// 点数(重みをかけて足し、レースの中の平均を引く)。正 = 有利
  static List<double> scoresOf(
      List<Map<String, double>> terms, Map<String, double> weights) {
    if (terms.isEmpty) return const [];
    final raw = <double>[];
    for (final t in terms) {
      double s = 0.0;
      for (final k in termKeys) {
        final w = weights[k];
        if (w != null) s += (t[k] ?? 0.0) * w;
      }
      raw.add(s);
    }
    double sum = 0.0;
    for (final s in raw) {
      sum += s;
    }
    final mean = sum / raw.length;
    return [for (final s in raw) s - mean];
  }
}

class _PastRun {
  final DateTime day;

  /// '芝'・'ダ'・'障' など(距離の1文字目)
  final String surface;
  final double? distance;
  final double? rank;
  final double? carriedWeight;

  const _PastRun(
      this.day, this.surface, this.distance, this.rank, this.carriedWeight);
}
