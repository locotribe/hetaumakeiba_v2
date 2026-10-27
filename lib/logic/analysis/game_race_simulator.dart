// lib/logic/analysis/game_race_simulator.dart
// [追加] 展開シミュゲーム式移植Step3: ゲーム式エンジンを多数回走らせ、勝率・複勝率・平均通過順・代表の1回をまとめる純粋ロジック。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の5章・6章・7章 (v.2026.10.27+26102703)

import 'dart:isolate';
import 'dart:math' as math;

import 'package:hetaumakeiba_v2/logic/analysis/game_ability_builder.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';

/// 1頭ぶんの集計。
class GameHorseSummary {
  /// 勝った回数
  final int wins;

  /// 3着以内の回数
  final int top3;

  /// 平均着順
  final double meanRank;

  /// 補正した勝率(0.0〜1.0。全馬の合計が1.0)
  final double winProb;

  /// 補正した3着以内率(0.0〜1.0。全馬の合計が3.0。1.0を超えない)
  final double top3Prob;

  /// 通過点ごとの平均順位(1始まり。通過点は [GameRaceSummary.checkpoints] の順)
  final List<double> meanCheckpointRanks;

  const GameHorseSummary({
    required this.wins,
    required this.top3,
    required this.meanRank,
    required this.winProb,
    required this.top3Prob,
    required this.meanCheckpointRanks,
  });
}

/// 多数回走らせた結果のまとめ。時間はゲームの単位(実時間への換算は [timeScaleFor] で行う)。
class GameRaceSummary {
  final int runs;

  /// 通過点(スタートからの距離 m)。コーナーの中間点とゴール
  final List<double> checkpoints;

  /// 馬ごとの集計(入力の馬の順)
  final List<GameHorseSummary> horses;

  /// 勝ち馬の時計の平均(ゲームの単位)
  final double meanWinnerTime;

  /// 先頭の1000m通過の平均(ゲームの単位)。1000m未満のレースは null
  final double? meanLeader1000;

  /// 勝ち馬の上がり600mの平均(ゲームの単位)
  final double meanWinnerLast600;

  /// 代表の1回の番号(0始まり)
  final int representativeIndex;

  /// 代表の1回の結果
  final GameRaceRunResult representative;

  /// [追加] 展開シミュゲーム式移植Step4c: 平均の走り(各馬の、距離ごとの通過時刻と横の位置を全回で平均した1回ぶんの記録)。
  /// 再生の既定に使う (v.2026.10.27+26102706)
  final GameRaceRunResult averageRun;

  const GameRaceSummary({
    required this.runs,
    required this.checkpoints,
    required this.horses,
    required this.meanWinnerTime,
    required this.meanLeader1000,
    required this.meanWinnerLast600,
    required this.representativeIndex,
    required this.representative,
    required this.averageRun,
  });

  /// 実時間への倍率。[referenceWinnerSeconds] は基準の勝ち時計(秒)。
  double timeScaleFor(double referenceWinnerSeconds) =>
      referenceWinnerSeconds / meanWinnerTime;
}

class GameRaceSimulator {
  GameRaceSimulator._();

  /// 既定の回数
  static const int defaultRuns = 100;

  /// 勝率の補正(芝・ダート)。設計書5章
  static const double winCalibrationTurf = 0.6;
  static const double winCalibrationDirt = 0.7;

  /// 3着以内率の補正(芝・ダート)。設計書5章
  static const double top3CalibrationTurf = 0.55;
  static const double top3CalibrationDirt = 0.5;

  /// [追加] 展開シミュゲーム式移植Step4b: 代表の1回を選ぶとき、表の上位3頭の着順のずれを何倍に数えるか (v.2026.10.27+26102705)
  static const double representativeTopWeight = 4.0;

  /// [追加] 展開シミュゲーム式移植Step4c: 平均の走りを作るときの距離の刻み(m) (v.2026.10.27+26102706)
  static const double averageRunStep = 10.0;

  /// [追加] 展開シミュゲーム式移植Step4c: 平均の走りの位置を記録する間隔(ゲームの秒) (v.2026.10.27+26102706)
  static const double averageRunInterval = 1.0;

  /// [追加] 展開シミュゲーム式移植Step4c: 平均の走りで、前後がこの距離(m)より近く横が1頭分未満の2頭は、外の馬を1頭分外へ出す (v.2026.10.27+26102706)
  static const double averageRunGap = 2.0;

  /// [abilities] の馬を [runs] 回走らせてまとめる。1回ごとに当日の出来(揺らぎ)を加える。
  /// 乱数は「1回ごとに 当日の出来 → エンジン」の順に [random] から引く。
  static GameRaceSummary run({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required GameRaceRandom random,
    required double winCalibration,
    required double top3Calibration,
    GameRaceCourse course = GameRaceCourse.flat,
    int runs = defaultRuns,
  }) {
    final n = abilities.length;
    final cps = checkpointsFor(distance, course);
    final results = <GameRaceRunResult>[];
    final ranks = <List<int>>[];
    final cpRanks = <List<List<int>>>[];
    final wins = List<int>.filled(n, 0);
    final top3 = List<int>.filled(n, 0);
    final rankSum = List<double>.filled(n, 0.0);
    final cpSum = List<List<double>>.generate(
        cps.length, (_) => List<double>.filled(n, 0.0));
    double winnerTimeSum = 0.0;
    double leaderSum = 0.0;
    int leaderCount = 0;
    double last600Sum = 0.0;
    int last600Count = 0;

    for (int r = 0; r < runs; r++) {
      final h = GameAbilityBuilder.applyFormNoise(abilities, random);
      final res = GameRaceEngine.simulate(
        distance: distance,
        horses: h,
        config: config,
        random: random,
        course: course,
      );
      results.add(res);
      final rk = rankOrder(res.finishTimes);
      ranks.add(rk);
      for (int i = 0; i < n; i++) {
        if (rk[i] == 1) wins[i]++;
        if (rk[i] <= 3) top3[i]++;
        rankSum[i] += rk[i];
      }
      final perCp = <List<int>>[];
      for (int k = 0; k < cps.length; k++) {
        final times = <double?>[
          for (final tr in res.traces) crossingTime(tr, cps[k])
        ];
        final cr = rankOrder(times);
        perCp.add(cr);
        for (int i = 0; i < n; i++) {
          cpSum[k][i] += cr[i];
        }
      }
      cpRanks.add(perCp);
      int winner = 0;
      for (int i = 0; i < n; i++) {
        if (rk[i] == 1) winner = i;
      }
      winnerTimeSum += res.finishTimes[winner] ?? 0.0;
      double? lead;
      for (final t in res.time1000) {
        if (t != null && (lead == null || t < lead)) lead = t;
      }
      if (lead != null) {
        leaderSum += lead;
        leaderCount++;
      }
      final f = res.finishTimes[winner];
      final t6 = res.time600[winner];
      if (f != null && t6 != null) {
        last600Sum += f - t6;
        last600Count++;
      }
    }

    // 補正した勝率
    final raw = <double>[
      for (int i = 0; i < n; i++)
        math.pow((wins[i] + 0.5) / (runs + 0.5 * n), winCalibration).toDouble()
    ];
    double rawSum = 0.0;
    for (final x in raw) {
      rawSum += x;
    }

    // 補正した3着以内率(合計が3.0になるようにそろえ、1.0で打ち止め)
    final raw3 = <double>[
      for (int i = 0; i < n; i++)
        math.pow((top3[i] + 0.5) / (runs + 0.5 * n), top3Calibration).toDouble()
    ];
    double raw3Sum = 0.0;
    for (final x in raw3) {
      raw3Sum += x;
    }

    // [修正] 展開シミュゲーム式移植Step4b: 代表の1回の選び方を変えた。結果の表と再生の着順が食い違って見えたため。
    // 表の並び(補正した勝率の高い順、同じなら平均着順の良い順)の1番の馬が勝った回の中から、
    // コーナーの順位が平均に近く、着順が表の並びに近い回を選ぶ(表の上位3頭の着順のずれは4倍に数える)。
    // 1番の馬が勝った回が無ければ全部の回から選ぶ (v.2026.10.27+26102705)
    final tableOrder = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final c = raw[b].compareTo(raw[a]);
        if (c != 0) return c;
        final m = rankSum[a].compareTo(rankSum[b]);
        return m != 0 ? m : a.compareTo(b);
      });
    final tableRank = List<int>.filled(n, 0);
    for (int k = 0; k < n; k++) {
      tableRank[tableOrder[k]] = k + 1;
    }
    final top = tableOrder.first;
    final topWon = [
      for (int r = 0; r < runs; r++)
        if (ranks[r][top] == 1) r
    ];
    final candidates =
        topWon.isNotEmpty ? topWon : List<int>.generate(runs, (r) => r);
    int best = candidates.first;
    double bestScore = double.infinity;
    for (final r in candidates) {
      double s = 0.0;
      for (int k = 0; k < cps.length - 1; k++) {
        for (int i = 0; i < n; i++) {
          final dlt = cpRanks[r][k][i] - cpSum[k][i] / runs;
          s += dlt * dlt;
        }
      }
      for (int i = 0; i < n; i++) {
        final dlt = (ranks[r][i] - tableRank[i]).toDouble();
        s += (tableRank[i] <= 3 ? representativeTopWeight : 1.0) * dlt * dlt;
      }
      if (s < bestScore) {
        best = r;
        bestScore = s;
      }
    }

    final horses = <GameHorseSummary>[
      for (int i = 0; i < n; i++)
        GameHorseSummary(
          wins: wins[i],
          top3: top3[i],
          meanRank: rankSum[i] / runs,
          winProb: raw[i] / rawSum,
          top3Prob: math.min(raw3[i] / raw3Sum * 3.0, 1.0),
          meanCheckpointRanks: [
            for (int k = 0; k < cps.length; k++) cpSum[k][i] / runs
          ],
        )
    ];
    return GameRaceSummary(
      runs: runs,
      checkpoints: cps,
      horses: horses,
      meanWinnerTime: winnerTimeSum / runs,
      meanLeader1000: leaderCount > 0 ? leaderSum / leaderCount : null,
      meanWinnerLast600: last600Count > 0 ? last600Sum / last600Count : 0.0,
      representativeIndex: best,
      representative: results[best],
      averageRun: averageRunOf(results, distance),
    );
  }

  /// [追加] 展開シミュゲーム式移植Step4c: 平均の走りを作る。結果の表(全回の平均)と再生の着順をそろえるため。
  /// 馬ごとに、ゴールした回だけで「[averageRunStep] mごとの通過時刻と横の位置」を平均し、
  /// [averageRunInterval] 秒ごとの位置に直す。平均すると横の位置が重なりやすいので、時刻ごとに前の馬から順に置き、
  /// 前後 [averageRunGap] m未満・横1頭分未満の馬がいれば、その馬の1頭分外へずらす。
  /// 1回もゴールしなかった馬は、1回目の記録をそのまま使う(ゴールの時刻は null) (v.2026.10.27+26102706)
  static GameRaceRunResult averageRunOf(
    List<GameRaceRunResult> results,
    double distance, {
    double step = averageRunStep,
    double interval = averageRunInterval,
    double gap = averageRunGap,
  }) {
    final n = results.first.finishTimes.length;
    final grid = <double>[0.0];
    for (int j = 1; j * step < distance - 1e-9; j++) {
      grid.add(j * step);
    }
    grid.add(distance);

    // 距離ごとの平均の通過時刻と横の位置
    final curveT = List<List<double>?>.filled(n, null);
    final curveL = List<List<double>?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      final valid = [
        for (final r in results)
          if (r.finishTimes[i] != null) r
      ];
      if (valid.isEmpty) continue;
      final t = List<double>.filled(grid.length, 0.0);
      final l = List<double>.filled(grid.length, 0.0);
      for (final r in valid) {
        final tr = r.traces[i];
        int k = 1;
        t[0] += tr[0].time;
        l[0] += tr[0].lane;
        for (int j = 1; j < grid.length; j++) {
          final x = grid[j];
          while (!(tr[k - 1].distance < x && x <= tr[k].distance)) {
            k++;
          }
          final a = tr[k - 1];
          final b = tr[k];
          final f = (x - a.distance) / (b.distance - a.distance);
          t[j] += a.time + f * (b.time - a.time);
          l[j] += a.lane + f * (b.lane - a.lane);
        }
      }
      final m = valid.length.toDouble();
      curveT[i] = [for (final x in t) x / m];
      curveL[i] = [for (final x in l) x / m];
    }

    // 一定の間隔の時刻で、距離と横の位置を出す
    final pts = List<List<List<double>>?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      final t = curveT[i];
      final l = curveL[i];
      if (t == null || l == null) continue;
      final row = <List<double>>[];
      for (int k = 0; k * interval < t.last - 1e-9; k++) {
        final time = k * interval;
        row.add([time, _interp(t, grid, time), _interp(t, l, time)]);
      }
      pts[i] = row;
    }

    // 重なりをほどく(前の馬から順に置く)
    int kMax = 0;
    for (final row in pts) {
      if (row != null && row.length > kMax) kMax = row.length;
    }
    for (int k = 0; k < kMax; k++) {
      final live = [
        for (int i = 0; i < n; i++)
          if (pts[i] != null && k < pts[i]!.length) i
      ]..sort((a, b) {
          final c = pts[b]![k][1].compareTo(pts[a]![k][1]);
          return c != 0 ? c : a.compareTo(b);
        });
      final placed = <int>[];
      for (final i in live) {
        final d = pts[i]![k][1];
        double lane = pts[i]![k][2];
        for (int it = 0; it < n; it++) {
          int? hit;
          for (final p in placed) {
            if ((d - pts[p]![k][1]).abs() < gap &&
                (lane - pts[p]![k][2]).abs() < GameRaceEngine.horseLane - 1e-12) {
              hit = p;
              break;
            }
          }
          if (hit == null) break;
          lane = math.min(pts[hit]![k][2] + GameRaceEngine.horseLane,
              GameRaceEngine.maxLane);
        }
        pts[i]![k][2] = lane;
        placed.add(i);
      }
    }

    final finish = <double?>[];
    final t1000 = <double?>[];
    final t600 = <double?>[];
    final traces = <List<GameRacePoint>>[];
    for (int i = 0; i < n; i++) {
      final t = curveT[i];
      final l = curveL[i];
      if (t == null || l == null) {
        finish.add(null);
        t1000.add(null);
        t600.add(null);
        traces.add(results.first.traces[i]);
        continue;
      }
      finish.add(t.last);
      t1000.add(distance >= 1000.0 ? _interp(grid, t, 1000.0) : null);
      t600.add(distance >= 600.0 ? _interp(grid, t, distance - 600.0) : null);
      final tr = <GameRacePoint>[
        for (final p in pts[i]!) GameRacePoint(p[0], p[1], p[2])
      ];
      final lastLane = tr.isNotEmpty ? tr.last.lane : l.last;
      tr.add(GameRacePoint(t.last, distance, lastLane));
      traces.add(tr);
    }
    return GameRaceRunResult(
      finishTimes: finish,
      time1000: t1000,
      time600: t600,
      traces: traces,
    );
  }

  /// [xs](増える並び)で [x] を挟む区間の線形補間。端の外は端の値
  static double _interp(List<double> xs, List<double> ys, double x) {
    if (x <= xs.first) return ys.first;
    for (int j = 1; j < xs.length; j++) {
      if (x <= xs[j]) {
        final f = (x - xs[j - 1]) / (xs[j] - xs[j - 1]);
        return ys[j - 1] + f * (ys[j] - ys[j - 1]);
      }
    }
    return ys.last;
  }

  /// [run] を別スレッド(Isolate)で行う。画面を止めないためにアプリからはこちらを使う。
  /// 乱数は [seed] から作る(同じ種なら同じ結果)。
  static Future<GameRaceSummary> runInBackground({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required int seed,
    required double winCalibration,
    required double top3Calibration,
    GameRaceCourse course = GameRaceCourse.flat,
    int runs = defaultRuns,
  }) {
    return Isolate.run(() => run(
          distance: distance,
          abilities: abilities,
          config: config,
          random: GameRaceDartRandom(seed),
          winCalibration: winCalibration,
          top3Calibration: top3Calibration,
          course: course,
          runs: runs,
        ));
  }

  /// 通過点: コーナーごとの中間点とゴール。コーナーが無ければ距離の1/4・1/2・3/4とゴール。
  static List<double> checkpointsFor(double distance, GameRaceCourse course) {
    if (course.corners.isEmpty) {
      return [distance * 0.25, distance * 0.5, distance * 0.75, distance];
    }
    return [
      for (final c in course.corners) (c.start + c.end) / 2.0,
      distance,
    ];
  }

  /// 時刻(小さいほど上位、null は最後)から順位(1始まり)を付ける。同じ時刻は馬の順。
  static List<int> rankOrder(List<double?> times) {
    final n = times.length;
    final idx = List<int>.generate(n, (i) => i);
    idx.sort((a, b) {
      final ta = times[a] ?? double.infinity;
      final tb = times[b] ?? double.infinity;
      final c = ta.compareTo(tb);
      return c != 0 ? c : a.compareTo(b);
    });
    final out = List<int>.filled(n, 0);
    for (int r = 0; r < n; r++) {
      out[idx[r]] = r + 1;
    }
    return out;
  }

  /// 位置の記録から、[x] m地点を通過した時刻を線形補間で求める。届かなければ null。
  static double? crossingTime(List<GameRacePoint> trace, double x) {
    for (int k = 1; k < trace.length; k++) {
      final a = trace[k - 1];
      final b = trace[k];
      if (a.distance < x && x <= b.distance) {
        return a.time +
            (x - a.distance) / (b.distance - a.distance) * (b.time - a.time);
      }
    }
    return null;
  }

  /// 1000m通過を [targetSeconds](実時間)にしたいときのペース倍率。
  /// [currentPaceMult] で走らせた結果の先頭の1000m通過(実時間)が [currentSeconds]。
  static double paceMultForLeader1000({
    required double currentPaceMult,
    required double currentSeconds,
    required double targetSeconds,
  }) {
    return currentPaceMult * currentSeconds / targetSeconds;
  }
}