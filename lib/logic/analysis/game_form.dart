// lib/logic/analysis/game_form.dart
// [追加] 展開シミュ改良Step7a: 調教から各馬の「調子」の5段階(絶好調〜絶不調)を作る純粋ロジック。
// ゲームの「やる気」に当たり、能力値の作り方(game_ability_builder.dart)で倍率として掛ける。
// 過去走ごとに「そのレースの前の追い切り → そのレースでの出来(着順と、レースの中での上がりの順位)」を結びつけ、
// 出来が良かったときの追い切りをその馬の基準にして、今回の追い切りを比べる。
// 参照実装は原型の formref.py と1対1。設計は memory/展開シミュ_調子_設計メモ.md の4章 (v.2026.10.30+26103005)

import 'dart:math' as math;

import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/training_evaluation.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

/// 調子の5段階(ゲームの「やる気」)。
enum GameFormLevel {
  /// 絶好調(倍率 1.04)
  best,

  /// 好調(1.02)
  good,

  /// 普通(1.00)
  normal,

  /// 不調(0.98)
  poor,

  /// 絶不調(0.96)
  worst,
}

/// 過去走の、レースの中での上がりの順位。
class GameFormAgariRank {
  /// 上がりの速い順の順位(1から)
  final int rank;

  /// 上がりが読めた頭数
  final int count;

  const GameFormAgariRank({required this.rank, required this.count});
}

/// 1頭ぶんの調子。
class GameFormResult {
  /// 5段階
  final GameFormLevel level;

  /// 点数(正 = 良い)
  final double score;

  /// 水準の項(時計)
  final double levelTerm;

  /// 終いの項(ラスト1Fと加速)
  final double kickTerm;

  /// 流れの項(1本前との差)
  final double trendTerm;

  /// 基準に使えた過去走の数
  final int referenceCount;

  /// いちばん効いた見方の言葉(例「時計が良い」)。出せないときは理由
  final String reason;

  const GameFormResult({
    required this.level,
    required this.score,
    required this.levelTerm,
    required this.kickTerm,
    required this.trendTerm,
    required this.referenceCount,
    required this.reason,
  });

  /// やる気の倍率
  double get multiplier => GameForm.multiplierOf(level);
}

/// 追い切り1本の特徴(コースの水準をそろえる前の生の値)。
class _Workout {
  final String ymd;
  final String time;
  final bool isHanro;
  final double diff;
  final double lastFurlong;
  final double accel;
  final int order;

  const _Workout({
    required this.ymd,
    required this.time,
    required this.isHanro,
    required this.diff,
    required this.lastFurlong,
    required this.accel,
    required this.order,
  });
}

/// 過去走1走(日付・着順・頭数・レースID)。
class _PastRun {
  final String ymd;
  final String rank;
  final String numberOfHorses;
  final String raceId;

  const _PastRun(this.ymd, this.rank, this.numberOfHorses, this.raceId);
}

/// 基準に使う1走(その走の最終の追い切りと、その走での出来)。
class _Reference {
  final _Workout workout;
  final double outcome;

  const _Reference(this.workout, this.outcome);
}

class GameForm {
  GameForm._();

  /// 追い切りの見分け(ラスト1Fがこれ以下。坂路)
  static const double hardLastFurlongHanro = 14.0;

  /// 追い切りの見分け(ウッド)
  static const double hardLastFurlongWood = 13.5;

  /// コースの水準(基準差。坂路・ウッド)
  static const double offsetDiffHanro = 0.7;
  static const double offsetDiffWood = 1.1;

  /// コースの水準(ラスト1F)
  static const double offsetLastFurlongHanro = 12.5;
  static const double offsetLastFurlongWood = 11.5;

  /// コースの水準(加速)
  static const double offsetAccelHanro = 0.3;
  static const double offsetAccelWood = 0.4;

  /// ばらつき(z にするときの割り算)
  static const double sdDiff = 1.6;
  static const double sdLastFurlong = 0.28;
  static const double sdAccel = 0.31;

  /// 中心をずらす定数(ふつうの仕上げを「普通」にする)
  static const double centerLevel = 0.18;
  static const double centerKick = 0.08;

  /// 最終の追い切りが1本前より普段から速い秒
  static const double centerTrendSeconds = 1.1;

  /// 3つの見方の重み(水準・終い・流れ)
  static const double weightLevel = 0.40;
  static const double weightKick = 0.35;
  static const double weightTrend = 0.25;

  /// 参照の少なさの割引き(点数に m ÷ (m + これ) をかける)
  static const double referenceDiscount = 2.0;

  /// 過去走の出来に混ぜる、上がりの重み
  static const double agariWeight = 0.3;

  /// 5段階の境目
  static const double cutBest = 0.60;
  static const double cutGood = 0.22;

  /// 窓の最長(日)
  static const int windowDays = 35;

  /// 基準に使う過去走の最大
  static const int maxReferences = 10;

  /// 各項の打ち止め
  static const double clipLimit = 3.0;

  /// 今回の窓に追い切りが無いときの理由
  static const String reasonNoWorkout = '追い切りの時計なし';

  /// 比べる過去走が無いときの理由
  static const String reasonNoReference = '比べる過去走なし';

  /// やる気の倍率(ゲームの値)
  static double multiplierOf(GameFormLevel level) {
    switch (level) {
      case GameFormLevel.best:
        return 1.04;
      case GameFormLevel.good:
        return 1.02;
      case GameFormLevel.normal:
        return 1.00;
      case GameFormLevel.poor:
        return 0.98;
      case GameFormLevel.worst:
        return 0.96;
    }
  }

  /// 点数から5段階にする。
  static GameFormLevel levelOf(double score) {
    if (score >= cutBest) return GameFormLevel.best;
    if (score >= cutGood) return GameFormLevel.good;
    if (score > -cutGood) return GameFormLevel.normal;
    if (score > -cutBest) return GameFormLevel.poor;
    return GameFormLevel.worst;
  }

  /// 1頭ぶんの調子を作る。
  ///
  /// [records] その馬の過去走(今回のレースの日より前。並びは問わない)。
  /// [trainings] その馬の坂路・ウッドの時計(今回のレースの日より前。並びは問わない)。
  /// [raceYmd] 今回のレースの日(YYYYMMDD)。
  /// [agariRanks] レースID → そのレースの中での上がりの順位。無い分は着順だけで出来を出す。
  static GameFormResult of(
    List<HorseRaceRecord> records, {
    required List<TrainingTimeModel> trainings,
    required String raceYmd,
    Map<String, GameFormAgariRank> agariRanks = const {},
  }) {
    if (!_isYmd(raceYmd)) return _plain(reasonNoWorkout);
    final hards = _hardWorkouts(trainings);
    final runs = _pastRuns(records, raceYmd);
    final cur =
        _window(hards, raceYmd, runs.isEmpty ? null : runs[runs.length - 1].ymd);
    final refs = <_Reference>[];
    for (int i = 0; i < runs.length; i++) {
      final w = _window(hards, runs[i].ymd, i > 0 ? runs[i - 1].ymd : null);
      if (w.isEmpty) continue;
      final o = _outcome(runs[i], agariRanks);
      if (o == null) continue;
      refs.add(_Reference(w[w.length - 1], o));
    }
    final all = refs.length > maxReferences
        ? refs.sublist(refs.length - maxReferences)
        : refs;
    if (cur.isEmpty) return _plain(reasonNoWorkout);
    if (all.isEmpty) return _plain(reasonNoReference);

    final c = cur[cur.length - 1];
    final same = [
      for (final r in all)
        if (r.workout.isHanro == c.isHanro) r
    ];
    final use = same.isNotEmpty ? same : all;

    double total = 0.0;
    double sumDiff = 0.0;
    double sumLastFurlong = 0.0;
    double sumAccel = 0.0;
    for (final r in use) {
      final w = math.exp(2.0 * (r.outcome - 0.5));
      total += w;
      sumDiff += _adjDiff(r.workout) * w;
      sumLastFurlong += _adjLastFurlong(r.workout) * w;
      sumAccel += _adjAccel(r.workout) * w;
    }
    final meanDiff = sumDiff / total;
    final meanLastFurlong = sumLastFurlong / total;
    final meanAccel = sumAccel / total;

    final levelTerm = _clip((meanDiff - _adjDiff(c)) / sdDiff - centerLevel);
    final k1 = _clip((meanLastFurlong - _adjLastFurlong(c)) / sdLastFurlong);
    final k2 = _clip((_adjAccel(c) - meanAccel) / sdAccel);
    final kickTerm = _clip(0.5 * (k1 + k2) - centerKick);
    double trendTerm = 0.0;
    if (cur.length >= 2 && cur[cur.length - 2].isHanro == c.isHanro) {
      trendTerm = _clip(
          (_adjDiff(cur[cur.length - 2]) - _adjDiff(c) - centerTrendSeconds) /
              sdDiff);
    }
    final m = use.length;
    final score =
        (weightLevel * levelTerm + weightKick * kickTerm + weightTrend * trendTerm) *
            m /
            (m + referenceDiscount);

    // いちばん効いた見方(同じ大きさなら 時計 → 終い → 流れ の順)
    const names = ['時計', '終い', '流れ'];
    final values = [
      weightLevel * levelTerm,
      weightKick * kickTerm,
      weightTrend * trendTerm,
    ];
    int top = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i].abs() > values[top].abs()) top = i;
    }
    final reason = '${names[top]}が${values[top] > 0 ? '良い' : '落ちる'}';

    return GameFormResult(
      level: levelOf(score),
      score: score,
      levelTerm: levelTerm,
      kickTerm: kickTerm,
      trendTerm: trendTerm,
      referenceCount: m,
      reason: reason,
    );
  }

  static GameFormResult _plain(String reason) => GameFormResult(
        level: GameFormLevel.normal,
        score: 0.0,
        levelTerm: 0.0,
        kickTerm: 0.0,
        trendTerm: 0.0,
        referenceCount: 0,
        reason: reason,
      );

  static bool _isYmd(String s) => RegExp(r'^\d{8}$').hasMatch(s);

  static double _clip(double z) =>
      z < -clipLimit ? -clipLimit : (z > clipLimit ? clipLimit : z);

  static double _adjDiff(_Workout w) =>
      w.diff - (w.isHanro ? offsetDiffHanro : offsetDiffWood);

  static double _adjLastFurlong(_Workout w) =>
      w.lastFurlong - (w.isHanro ? offsetLastFurlongHanro : offsetLastFurlongWood);

  static double _adjAccel(_Workout w) =>
      w.accel - (w.isHanro ? offsetAccelHanro : offsetAccelWood);

  /// 日付を [days] 日だけ戻した YYYYMMDD。
  static String _minusDays(String ymd, int days) {
    final d = DateTime.utc(
      int.parse(ymd.substring(0, 4)),
      int.parse(ymd.substring(4, 6)),
      int.parse(ymd.substring(6, 8)),
    ).subtract(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 追い切りだけを日付・時刻の順に並べる。
  static List<_Workout> _hardWorkouts(List<TrainingTimeModel> trainings) {
    final out = <_Workout>[];
    for (int i = 0; i < trainings.length; i++) {
      final f = _featureOf(trainings[i], i);
      if (f == null) continue;
      final limit = f.isHanro ? hardLastFurlongHanro : hardLastFurlongWood;
      if (f.lastFurlong <= limit) out.add(f);
    }
    out.sort((a, b) {
      final byDate = a.ymd.compareTo(b.ymd);
      if (byDate != 0) return byDate;
      final byTime = a.time.compareTo(b.time);
      if (byTime != 0) return byTime;
      return a.order.compareTo(b.order);
    });
    return out;
  }

  /// 時計1本 → 特徴。基準タイムが出せない・ラスト1Fが無いときは null。
  static _Workout? _featureOf(TrainingTimeModel t, int order) {
    if (!isComparableCourse(t)) return null;
    if (!_isYmd(t.trainingDate)) return null;
    final f1 = t.f1;
    if (f1 == null || f1 <= 0) return null;
    final c = trainingCumulatives(t);
    if (c.length < 2) return null;
    final diff = baseDiff(t);
    if (diff == null) return null;
    final f2 = c[c.length - 2];
    return _Workout(
      ymd: t.trainingDate,
      time: t.trainingTime,
      isHanro: t.trackType == '坂路',
      diff: diff,
      lastFurlong: f1,
      accel: (f2 - f1) - f1,
      order: order,
    );
  }

  /// 過去走を古い順に並べる(同じ日は入力の並びのまま)。今回のレースの日以降は入れない。
  static List<_PastRun> _pastRuns(List<HorseRaceRecord> records, String raceYmd) {
    final runs = <_PastRun>[];
    final order = <int>[];
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final d = parseHorseRecordDate(r.date);
      if (d == null) continue;
      final ymd = '${d.year.toString().padLeft(4, '0')}'
          '${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}';
      if (ymd.compareTo(raceYmd) >= 0) continue;
      runs.add(_PastRun(ymd, r.rank, r.numberOfHorses, r.raceId));
      order.add(i);
    }
    final index = List<int>.generate(runs.length, (i) => i);
    index.sort((a, b) {
      final byDate = runs[a].ymd.compareTo(runs[b].ymd);
      return byDate != 0 ? byDate : order[a].compareTo(order[b]);
    });
    return [for (final i in index) runs[i]];
  }

  /// 窓(前走の翌日〜レースの前日、ただし最長 [windowDays] 日)の追い切り。
  static List<_Workout> _window(
      List<_Workout> hards, String raceYmd, String? prevYmd) {
    var lo = _minusDays(raceYmd, windowDays);
    if (prevYmd != null && prevYmd.compareTo(lo) > 0) lo = prevYmd;
    return [
      for (final f in hards)
        if (f.ymd.compareTo(lo) > 0 && f.ymd.compareTo(raceYmd) < 0) f
    ];
  }

  /// 過去走の出来(0〜1)。使えないときは null。
  static double? _outcome(
      _PastRun run, Map<String, GameFormAgariRank> agariRanks) {
    final rank = int.tryParse(run.rank.trim());
    final count = int.tryParse(run.numberOfHorses.trim());
    if (rank == null || count == null) return null;
    if (count < 5 || rank < 1) return null;
    final byRank = 1.0 - (rank - 1) / (count - 1);
    final a = run.raceId.isEmpty ? null : agariRanks[run.raceId];
    if (a != null && a.count >= 5 && a.rank >= 1) {
      final byAgari = 1.0 - (a.rank - 1) / (a.count - 1);
      return (1.0 - agariWeight) * byRank + agariWeight * byAgari;
    }
    return byRank;
  }
}
