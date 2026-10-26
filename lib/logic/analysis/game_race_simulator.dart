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

  /// 代表の1回の結果(再生に使う)
  final GameRaceRunResult representative;

  const GameRaceSummary({
    required this.runs,
    required this.checkpoints,
    required this.horses,
    required this.meanWinnerTime,
    required this.meanLeader1000,
    required this.meanWinnerLast600,
    required this.representativeIndex,
    required this.representative,
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

    // 代表の1回: 通過点ごとの順位が平均に最も近い回
    int best = 0;
    double bestScore = double.infinity;
    for (int r = 0; r < runs; r++) {
      double s = 0.0;
      for (int k = 0; k < cps.length; k++) {
        for (int i = 0; i < n; i++) {
          final dlt = cpRanks[r][k][i] - cpSum[k][i] / runs;
          s += dlt * dlt;
        }
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
    );
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