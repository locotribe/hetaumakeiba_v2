// lib/logic/analysis/game_race_simulator.dart
// [追加] 展開シミュゲーム式移植Step3: ゲーム式エンジンを多数回走らせ、勝率・複勝率・平均通過順・代表の1回をまとめる純粋ロジック。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の5章・6章・7章 (v.2026.10.27+26102703)

import 'dart:isolate';
import 'dart:math' as math;

import 'package:hetaumakeiba_v2/logic/analysis/game_ability_builder.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';
// [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
import 'package:hetaumakeiba_v2/logic/analysis/game_race_tuning.dart';

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

  /// [追加] 展開シミュ改良Step5a(案E): なぜこの勝率か の数え上げの全回の平均。数えていなければ null (v.2026.10.29+26102902)
  final GameHorseStatsMean? stats;

  const GameHorseSummary({
    required this.wins,
    required this.top3,
    required this.meanRank,
    required this.winProb,
    required this.top3Prob,
    required this.meanCheckpointRanks,
    // [追加] 展開シミュ改良Step5a (v.2026.10.29+26102902)
    this.stats,
  });
}

/// [追加] 展開シミュ改良Step5a(案E): 1頭ぶんの、なぜこの勝率か の数え上げ(GameRunHorseStats)の全回の平均。距離は m (v.2026.10.29+26102902)
class GameHorseStatsMean {
  final double cornerLoss;
  final double blockLoss;
  final double staminaLoss;

  /// HPが尽きた回の割合(0〜1)
  final double staminaOutRate;

  /// HPが尽きた所(ゴールまでの距離 m)の、尽きた回だけの平均。尽きた回が無ければ null
  final double? staminaOutAt;
  final double innerGain;
  final double wearLoss;
  final double kickLoss;

  const GameHorseStatsMean({
    required this.cornerLoss,
    required this.blockLoss,
    required this.staminaLoss,
    required this.staminaOutRate,
    required this.staminaOutAt,
    required this.innerGain,
    required this.wearLoss,
    required this.kickLoss,
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

  /// [追加] 展開シミュ改良Step3(案D): 回ごとに散らした先頭の1000m通過のずれ(秒。正 = 遅い。回の順)。散らさなければ空 (v.2026.10.28+26102803)
  final List<double> paceOffsets;

  /// [追加] 展開シミュ改良Step3(案D): 回ごとの着順(回の順 → 馬の順。1始まり)。ペース別の勝率(改良Step5)に使う (v.2026.10.28+26102803)
  final List<List<int>> runRanks;

  /// [追加] 展開シミュ改良Step5a(案E): 回ごとの先頭の1000m通過(ゲームの単位。回の順)。1000m未満のレースは null。散らしたペースの幅を出すのに使う (v.2026.10.29+26102902)
  final List<double?> runLeader1000;

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
    // [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
    this.paceOffsets = const [],
    this.runRanks = const [],
    // [追加] 展開シミュ改良Step5a (v.2026.10.29+26102902)
    this.runLeader1000 = const [],
  });

  /// 実時間への倍率。[referenceWinnerSeconds] は基準の勝ち時計(秒)。
  double timeScaleFor(double referenceWinnerSeconds) =>
      referenceWinnerSeconds / meanWinnerTime;
}

/// [追加] 展開シミュ改良Step5a(案E): 1つの組(何回か)を走らせた結果 (v.2026.10.29+26102902)
class GameRaceBlock {
  final List<GameRaceRunResult> results;

  /// 回ごとに散らしたペースのずれ(秒)。散らさなければ空
  final List<double> paceOffsets;

  const GameRaceBlock({required this.results, required this.paceOffsets});
}

/// [追加] 展開シミュ改良Step5a(案E): 途中の結果 (v.2026.10.29+26102902)
class GameRaceProgress {
  /// 終わった回数
  final int runsDone;

  /// 全部の回数
  final int runsTotal;

  /// 馬ごとの集計(入力の馬の順。数え上げの平均 stats は null)
  final List<GameHorseSummary> horses;

  const GameRaceProgress({
    required this.runsDone,
    required this.runsTotal,
    required this.horses,
  });
}

/// [追加] 展開シミュ改良Step5a(案E): 走らせた結果を数える([GameRaceSimulator.summarize] と [GameRaceSimulator.progressOf] で使う)。
/// 数え方・足す順は Step4 までの run と同じ (v.2026.10.29+26102902)
class _Tally {
  final int runs;
  final int n;
  final List<List<int>> ranks = [];
  final List<List<List<int>>> cpRanks = [];
  final List<int> wins;
  final List<int> top3;
  final List<double> rankSum;
  final List<List<double>> cpSum;
  double winnerTimeSum = 0.0;
  double leaderSum = 0.0;
  int leaderCount = 0;
  double last600Sum = 0.0;
  int last600Count = 0;

  /// 回ごとの先頭の1000m通過
  final List<double?> leaders = [];

  _Tally(this.runs, this.n, int cpCount)
      : wins = List<int>.filled(n, 0),
        top3 = List<int>.filled(n, 0),
        rankSum = List<double>.filled(n, 0.0),
        cpSum = List<List<double>>.generate(
            cpCount, (_) => List<double>.filled(n, 0.0));

  static _Tally of(List<GameRaceRunResult> results, List<double> cps) {
    final t =
        _Tally(results.length, results.first.finishTimes.length, cps.length);
    final n = t.n;
    for (final res in results) {
      final rk = GameRaceSimulator.rankOrder(res.finishTimes);
      t.ranks.add(rk);
      for (int i = 0; i < n; i++) {
        if (rk[i] == 1) t.wins[i]++;
        if (rk[i] <= 3) t.top3[i]++;
        t.rankSum[i] += rk[i];
      }
      final perCp = <List<int>>[];
      for (int k = 0; k < cps.length; k++) {
        final times = <double?>[
          for (final tr in res.traces) GameRaceSimulator.crossingTime(tr, cps[k])
        ];
        final cr = GameRaceSimulator.rankOrder(times);
        perCp.add(cr);
        for (int i = 0; i < n; i++) {
          t.cpSum[k][i] += cr[i];
        }
      }
      t.cpRanks.add(perCp);
      int winner = 0;
      for (int i = 0; i < n; i++) {
        if (rk[i] == 1) winner = i;
      }
      t.winnerTimeSum += res.finishTimes[winner] ?? 0.0;
      double? lead;
      for (final x in res.time1000) {
        if (x != null && (lead == null || x < lead)) lead = x;
      }
      t.leaders.add(lead);
      if (lead != null) {
        t.leaderSum += lead;
        t.leaderCount++;
      }
      final f = res.finishTimes[winner];
      final t6 = res.time600[winner];
      if (f != null && t6 != null) {
        t.last600Sum += f - t6;
        t.last600Count++;
      }
    }
    return t;
  }

  /// 補正した勝率の元の値(合計で割る前)
  List<double> rawWin(double calibration) => [
        for (int i = 0; i < n; i++)
          math.pow((wins[i] + 0.5) / (runs + 0.5 * n), calibration).toDouble()
      ];

  /// 補正した3着以内率の元の値(合計で割る前)
  List<double> rawTop3(double calibration) => [
        for (int i = 0; i < n; i++)
          math.pow((top3[i] + 0.5) / (runs + 0.5 * n), calibration).toDouble()
      ];

  /// 馬ごとの集計。勝率は合計1.0、3着以内率は合計3.0にそろえて1.0で打ち止め
  List<GameHorseSummary> horsesOf(
      List<double> raw, List<double> raw3, List<GameHorseStatsMean>? stats) {
    double rawSum = 0.0;
    for (final x in raw) {
      rawSum += x;
    }
    double raw3Sum = 0.0;
    for (final x in raw3) {
      raw3Sum += x;
    }
    return [
      for (int i = 0; i < n; i++)
        GameHorseSummary(
          wins: wins[i],
          top3: top3[i],
          meanRank: rankSum[i] / runs,
          winProb: raw[i] / rawSum,
          top3Prob: math.min(raw3[i] / raw3Sum * 3.0, 1.0),
          meanCheckpointRanks: [
            for (int k = 0; k < cpSum.length; k++) cpSum[k][i] / runs
          ],
          stats: stats?[i],
        )
    ];
  }
}

class GameRaceSimulator {
  GameRaceSimulator._();

  /// 既定の回数
  static const int defaultRuns = 100;

  /// [追加] 展開シミュ改良Step5a(案E): 既定の組の数(100回を20回ずつ)と、組ごとの乱数の種の間隔 (v.2026.10.29+26102902)
  static const int defaultBlocks = 5;
  static const int blockSeedStep = 100003;

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

  /// [追加] 展開シミュゲーム式移植Step4e: 平均の走りで、横のずらし方を前後この点数ずつ平均してなめらかにする (v.2026.10.27+26102708)
  static const int averageRunSmooth = 2;

  /// [abilities] の馬を [runs] 回走らせてまとめる。1回ごとに当日の出来(揺らぎ)を加える。
  /// 乱数は「1回ごとに 当日の出来 → エンジン」の順に [random] から引く。
  /// [修正] 展開シミュ改良Step3(案D): [paceScatterSd] が0より大きいときは、1回ごとに当日の出来より先に正規乱数を1つ引き、
  /// 先頭の1000m通過を「正規乱数 × [paceScatterSd]」秒ずらすペース倍率で走らせる(GamePacePredictor.paceMultOf)。0 なら今までと同じ (v.2026.10.28+26102803)
  /// [修正] 展開シミュ改良Step5a(案E): 走らせる所を [runBlock]、まとめる所を [summarize] に分けた(結果は今までと同じ) (v.2026.10.29+26102902)
  static GameRaceSummary run({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required GameRaceRandom random,
    required double winCalibration,
    required double top3Calibration,
    GameRaceCourse course = GameRaceCourse.flat,
    int runs = defaultRuns,
    double paceScatterSd = 0.0,
  }) {
    final block = runBlock(
      distance: distance,
      abilities: abilities,
      config: config,
      random: random,
      course: course,
      runs: runs,
      paceScatterSd: paceScatterSd,
    );
    return summarize(
      distance: distance,
      results: block.results,
      paceOffsets: block.paceOffsets,
      winCalibration: winCalibration,
      top3Calibration: top3Calibration,
      course: course,
    );
  }

  /// [追加] 展開シミュ改良Step5a(案E): [abilities] の馬を [runs] 回走らせた結果と、回ごとに散らしたペースのずれ。
  /// 乱数の引き方は [run] と同じ(参照実装 simagg.py の run_block) (v.2026.10.29+26102902)
  static GameRaceBlock runBlock({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required GameRaceRandom random,
    GameRaceCourse course = GameRaceCourse.flat,
    int runs = defaultRuns,
    double paceScatterSd = 0.0,
  }) {
    final results = <GameRaceRunResult>[];
    // [追加] 展開シミュ改良Step3(案D) (v.2026.10.28+26102803)
    final paceOffsets = <double>[];
    for (int r = 0; r < runs; r++) {
      // [追加] 展開シミュ改良Step3(案D): 回ごとにペースを散らす (v.2026.10.28+26102803)
      var runConfig = config;
      if (paceScatterSd > 0.0) {
        final off = GameAbilityBuilder.normal(random) * paceScatterSd;
        paceOffsets.add(off);
        runConfig = config.copyWith(
            paceMult: GamePacePredictor.paceMultOf(config.paceMult, off));
      }
      final h = GameAbilityBuilder.applyFormNoise(abilities, random);
      results.add(GameRaceEngine.simulate(
        distance: distance,
        horses: h,
        // [修正] 展開シミュ改良Step3: 回ごとの設定 (v.2026.10.28+26102803)
        config: runConfig,
        random: random,
        course: course,
      ));
    }
    return GameRaceBlock(results: results, paceOffsets: paceOffsets);
  }

  /// [追加] 展開シミュ改良Step5a(案E): 走らせた結果([results]。1回以上)をまとめる。Step4 までの [run] の後半と同じ計算に、
  /// 回ごとの先頭の1000m通過([GameRaceSummary.runLeader1000])と、なぜこの勝率か の数え上げの平均([GameHorseSummary.stats])を足した。
  /// 参照実装は simagg.py の summarize (v.2026.10.29+26102902)
  static GameRaceSummary summarize({
    required double distance,
    required List<GameRaceRunResult> results,
    required List<double> paceOffsets,
    required double winCalibration,
    required double top3Calibration,
    GameRaceCourse course = GameRaceCourse.flat,
  }) {
    final runs = results.length;
    final cps = checkpointsFor(distance, course);
    final t = _Tally.of(results, cps);
    final n = t.n;
    final raw = t.rawWin(winCalibration);

    // [修正] 展開シミュゲーム式移植Step4b: 代表の1回の選び方を変えた。結果の表と再生の着順が食い違って見えたため。
    // 表の並び(補正した勝率の高い順、同じなら平均着順の良い順)の1番の馬が勝った回の中から、
    // コーナーの順位が平均に近く、着順が表の並びに近い回を選ぶ(表の上位3頭の着順のずれは4倍に数える)。
    // 1番の馬が勝った回が無ければ全部の回から選ぶ (v.2026.10.27+26102705)
    final tableOrder = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final c = raw[b].compareTo(raw[a]);
        if (c != 0) return c;
        final m = t.rankSum[a].compareTo(t.rankSum[b]);
        return m != 0 ? m : a.compareTo(b);
      });
    final tableRank = List<int>.filled(n, 0);
    for (int k = 0; k < n; k++) {
      tableRank[tableOrder[k]] = k + 1;
    }
    final top = tableOrder.first;
    final topWon = [
      for (int r = 0; r < runs; r++)
        if (t.ranks[r][top] == 1) r
    ];
    final candidates =
        topWon.isNotEmpty ? topWon : List<int>.generate(runs, (r) => r);
    int best = candidates.first;
    double bestScore = double.infinity;
    for (final r in candidates) {
      double s = 0.0;
      for (int k = 0; k < cps.length - 1; k++) {
        for (int i = 0; i < n; i++) {
          final dlt = t.cpRanks[r][k][i] - t.cpSum[k][i] / runs;
          s += dlt * dlt;
        }
      }
      for (int i = 0; i < n; i++) {
        final dlt = (t.ranks[r][i] - tableRank[i]).toDouble();
        s += (tableRank[i] <= 3 ? representativeTopWeight : 1.0) * dlt * dlt;
      }
      if (s < bestScore) {
        best = r;
        bestScore = s;
      }
    }

    return GameRaceSummary(
      runs: runs,
      checkpoints: cps,
      horses: t.horsesOf(raw, t.rawTop3(top3Calibration), statsMeanOf(results)),
      meanWinnerTime: t.winnerTimeSum / runs,
      meanLeader1000: t.leaderCount > 0 ? t.leaderSum / t.leaderCount : null,
      meanWinnerLast600:
          t.last600Count > 0 ? t.last600Sum / t.last600Count : 0.0,
      representativeIndex: best,
      representative: results[best],
      averageRun: averageRunOf(results, distance),
      // [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
      paceOffsets: paceOffsets,
      runRanks: t.ranks,
      // [追加] 展開シミュ改良Step5a (v.2026.10.29+26102902)
      runLeader1000: t.leaders,
    );
  }

  /// [追加] 展開シミュ改良Step5a(案E): 途中の結果(勝率・3着以内率・平均着順・平均の通過順)。[summarize] と同じ計算で、
  /// 代表の1回・平均の走り・数え上げの平均は作らない (v.2026.10.29+26102902)
  static GameRaceProgress progressOf(
    List<GameRaceRunResult> results, {
    required double distance,
    required double winCalibration,
    required double top3Calibration,
    required int runsTotal,
    GameRaceCourse course = GameRaceCourse.flat,
  }) {
    final t = _Tally.of(results, checkpointsFor(distance, course));
    return GameRaceProgress(
      runsDone: results.length,
      runsTotal: runsTotal,
      horses: t.horsesOf(
          t.rawWin(winCalibration), t.rawTop3(top3Calibration), null),
    );
  }

  /// [追加] 展開シミュ改良Step5a(案E): なぜこの勝率か の数え上げを、馬ごとに全回で平均する。数え上げが無ければ null。
  /// 参照実装は simagg.py の stats_mean (v.2026.10.29+26102902)
  static List<GameHorseStatsMean>? statsMeanOf(
      List<GameRaceRunResult> results) {
    if (results.isEmpty || results.first.stats.isEmpty) return null;
    final runs = results.length;
    final n = results.first.stats.length;
    return [
      for (int i = 0; i < n; i++) _statsMeanOne(results, i, runs),
    ];
  }

  static GameHorseStatsMean _statsMeanOne(
      List<GameRaceRunResult> results, int i, int runs) {
    double corner = 0.0;
    double block = 0.0;
    double stamina = 0.0;
    double inner = 0.0;
    double wear = 0.0;
    double kick = 0.0;
    int outCount = 0;
    double outSum = 0.0;
    for (final r in results) {
      final s = r.stats[i];
      corner += s.cornerLoss;
      block += s.blockLoss;
      stamina += s.staminaLoss;
      inner += s.innerGain;
      wear += s.wearLoss;
      kick += s.kickLoss;
      final o = s.staminaOutAt;
      if (o != null) {
        outCount++;
        outSum += o;
      }
    }
    return GameHorseStatsMean(
      cornerLoss: corner / runs,
      blockLoss: block / runs,
      staminaLoss: stamina / runs,
      staminaOutRate: outCount / runs,
      staminaOutAt: outCount > 0 ? outSum / outCount : null,
      innerGain: inner / runs,
      wearLoss: wear / runs,
      kickLoss: kick / runs,
    );
  }

  /// [追加] 展開シミュ改良Step5a(案E): [runs] 回を [blocks] 個の組に分けたときの、組ごとの回数(余りは前の組から1回ずつ) (v.2026.10.29+26102902)
  static List<int> blockSizes(int runs, int blocks) {
    final b = math.max(1, math.min(blocks, runs));
    return [
      for (int k = 0; k < b; k++) runs ~/ b + (k < runs % b ? 1 : 0),
    ];
  }

  /// [追加] 展開シミュ改良Step5a(案E): [k] 番目の組の乱数の種 (v.2026.10.29+26102902)
  static int blockSeedOf(int seed, int k) => seed + k * blockSeedStep;

  /// [追加] 展開シミュ改良Step5a(案E): アプリで使う乱数(dart:math) (v.2026.10.29+26102902)
  static GameRaceRandom dartRandomOf(int seed) => GameRaceDartRandom(seed);

  /// [追加] 展開シミュ改良Step5a(案E): [runs] 回を [blocks] 個の組に分け、組ごとに別の乱数(種 [blockSeedOf]、乱数は [randomOf])で
  /// 走らせて、組の順につないでまとめる。[runParallel] と同じ結果を、この場で(1本で)作る。参照実装は simagg.py の run_blocks (v.2026.10.29+26102902)
  static GameRaceSummary runBlocks({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required int seed,
    required double winCalibration,
    required double top3Calibration,
    GameRaceCourse course = GameRaceCourse.flat,
    int runs = defaultRuns,
    int blocks = defaultBlocks,
    double paceScatterSd = 0.0,
    GameRaceRandom Function(int seed) randomOf = dartRandomOf,
  }) {
    final results = <GameRaceRunResult>[];
    final offsets = <double>[];
    final sizes = blockSizes(runs, blocks);
    for (int k = 0; k < sizes.length; k++) {
      final b = runBlock(
        distance: distance,
        abilities: abilities,
        config: config,
        random: randomOf(blockSeedOf(seed, k)),
        course: course,
        runs: sizes[k],
        paceScatterSd: paceScatterSd,
      );
      results.addAll(b.results);
      offsets.addAll(b.paceOffsets);
    }
    return summarize(
      distance: distance,
      results: results,
      paceOffsets: offsets,
      winCalibration: winCalibration,
      top3Calibration: top3Calibration,
      course: course,
    );
  }

  /// [追加] 展開シミュ改良Step5a(案E): [runBlocks] を、組ごとに別スレッド(Isolate)で同時に走らせる。画面を止めず、速くするためにアプリからはこちらを使う。
  /// 組が終わるたびに、それまでに終わった組の結果で [onProgress] を呼ぶ(終わる順は決まっていない。全部終わったときは呼ばない)。
  /// 最後のまとめ([summarize])も別スレッドで行い、組の順につなぐので、結果は [runBlocks] と同じ (v.2026.10.29+26102902)
  static Future<GameRaceSummary> runParallel({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required int seed,
    required double winCalibration,
    required double top3Calibration,
    GameRaceCourse course = GameRaceCourse.flat,
    int runs = defaultRuns,
    int blocks = defaultBlocks,
    double paceScatterSd = 0.0,
    void Function(GameRaceProgress progress)? onProgress,
    GameRaceRandom Function(int seed) randomOf = dartRandomOf,
  }) async {
    final sizes = blockSizes(runs, blocks);
    final done = List<GameRaceBlock?>.filled(sizes.length, null);
    await Future.wait([
      for (int k = 0; k < sizes.length; k++)
        _blockInBackground(
          distance: distance,
          abilities: abilities,
          config: config,
          seed: blockSeedOf(seed, k),
          course: course,
          runs: sizes[k],
          paceScatterSd: paceScatterSd,
          randomOf: randomOf,
        ).then((b) {
          done[k] = b;
          if (onProgress == null) return;
          final sofar = <GameRaceRunResult>[
            for (final x in done)
              if (x != null) ...x.results
          ];
          if (sofar.length >= runs) return;
          onProgress(progressOf(
            sofar,
            distance: distance,
            winCalibration: winCalibration,
            top3Calibration: top3Calibration,
            runsTotal: runs,
            course: course,
          ));
        }),
    ]);
    final results = <GameRaceRunResult>[
      for (final b in done) ...b!.results
    ];
    final offsets = <double>[for (final b in done) ...b!.paceOffsets];
    return _summarizeInBackground(
      distance: distance,
      results: results,
      paceOffsets: offsets,
      winCalibration: winCalibration,
      top3Calibration: top3Calibration,
      course: course,
    );
  }

  /// 1つの組を別スレッドで走らせる(別スレッドへ渡すのは引数だけにするため、関数を分けた)
  static Future<GameRaceBlock> _blockInBackground({
    required double distance,
    required List<GameHorseAbility> abilities,
    required GameRaceConfig config,
    required int seed,
    required GameRaceCourse course,
    required int runs,
    required double paceScatterSd,
    required GameRaceRandom Function(int seed) randomOf,
  }) {
    return Isolate.run(() => runBlock(
          distance: distance,
          abilities: abilities,
          config: config,
          random: randomOf(seed),
          course: course,
          runs: runs,
          paceScatterSd: paceScatterSd,
        ));
  }

  /// まとめを別スレッドで行う
  static Future<GameRaceSummary> _summarizeInBackground({
    required double distance,
    required List<GameRaceRunResult> results,
    required List<double> paceOffsets,
    required double winCalibration,
    required double top3Calibration,
    required GameRaceCourse course,
  }) {
    return Isolate.run(() => summarize(
          distance: distance,
          results: results,
          paceOffsets: paceOffsets,
          winCalibration: winCalibration,
          top3Calibration: top3Calibration,
          course: course,
        ));
  }

  /// [追加] 展開シミュゲーム式移植Step4c: 平均の走りを作る。結果の表(全回の平均)と再生の着順をそろえるため。
  /// 馬ごとに、ゴールした回だけで「[averageRunStep] mごとの通過時刻と横の位置」を平均し、
  /// [averageRunInterval] 秒ごとの位置に直す。平均すると横の位置が重なりやすいので、時刻ごとに前の馬から順に置き、
  /// 前後 [averageRunGap] m未満・横1頭分未満の馬がいれば、平均の位置から内外1頭分までずらす。
  /// [修正] 展開シミュゲーム式移植Step4e: 1頭分ずつ外へ重ねてずらすと、スタート直後などに外ラチ側まで飛んで画面で上下に激しく動いたため、
  /// ずらし方の候補を「前の時刻と同じ → ずらさない → 1頭分外 → 1頭分内」に限り、どれも空いていなければずらさない(重なってよい)。
  /// さらにずらし方を前後 [averageRunSmooth] 点ずつ平均してなめらかにする (v.2026.10.27+26102708)
  /// 1回もゴールしなかった馬は、1回目の記録をそのまま使う(ゴールの時刻は null) (v.2026.10.27+26102706)
  static GameRaceRunResult averageRunOf(
    List<GameRaceRunResult> results,
    double distance, {
    double step = averageRunStep,
    double interval = averageRunInterval,
    double gap = averageRunGap,
    int smooth = averageRunSmooth,
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

    // 重なりをほどく(前の馬から順に置き、平均の位置から内外1頭分までずらす)
    int kMax = 0;
    for (final row in pts) {
      if (row != null && row.length > kMax) kMax = row.length;
    }
    const hl = GameRaceEngine.horseLane;
    final off = List<double>.filled(n, 0.0);
    final offs = List<List<double>>.generate(n, (_) => <double>[]);
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
        final own = pts[i]![k][2];
        final cands = <double>[];
        for (final o in [off[i], 0.0, hl, -hl]) {
          if (cands.every((c) => (o - c).abs() > 1e-12)) cands.add(o);
        }
        double chosen = 0.0;
        for (final o in cands) {
          final lane = own + o;
          if (lane < 0.0 || lane > GameRaceEngine.maxLane) continue;
          bool free = true;
          for (final p in placed) {
            if ((d - pts[p]![k][1]).abs() < gap &&
                (lane - pts[p]![k][2]).abs() < hl - 1e-12) {
              free = false;
              break;
            }
          }
          if (free) {
            chosen = o;
            break;
          }
        }
        off[i] = chosen;
        offs[i].add(chosen);
        pts[i]![k][2] = own + chosen;
        placed.add(i);
      }
    }
    // ずらし方を前後 [smooth] 点ずつ平均してなめらかにする
    for (int i = 0; i < n; i++) {
      final row = pts[i];
      if (row == null) continue;
      final o = offs[i];
      final m = o.length;
      // [修正] 展開シミュゲーム式移植Step4e追補: 0秒(ゲート)の位置はならさない。ならすとゲートの並びがばらけたため (v.2026.10.27+26102708)
      for (int k = 1; k < m; k++) {
        final lo = math.max(0, k - smooth);
        final hi = math.min(m, k + smooth + 1);
        double sum = 0.0;
        for (int q = lo; q < hi; q++) {
          sum += o[q];
        }
        final sm = sum / (hi - lo);
        row[k][2] =
            (row[k][2] - o[k] + sm).clamp(0.0, GameRaceEngine.maxLane).toDouble();
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
    // [追加] 展開シミュ改良Step3(案D) (v.2026.10.28+26102803)
    double paceScatterSd = 0.0,
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
          // [追加] 展開シミュ改良Step3(案D) (v.2026.10.28+26102803)
          paceScatterSd: paceScatterSd,
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
