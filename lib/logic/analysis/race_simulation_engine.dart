// lib/logic/analysis/race_simulation_engine.dart

import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';

class RaceSimulationEngine {
  // [追加] リアルタイム速度化: 時速60km≈16.67m/sを基準にtotalTimeをraceDistanceから算出 (v2026.6.25)
  static const double _baseSpeedMps = 16.67;
  // [追加] 坂補正: 勾配(m/m)あたりの速度変化係数。勾配0.013(中山最急坂)で約10%の速度変化 (v2026.6.25)
  static const double _slopeInfluence = 8.0;

  /// レーン1つあたりの横方向オフセット(px)。coords.pixelsPerMeter≈0.5
  /// (1px≈2m)であるため、0.5px≈1m間隔とする(18頭が重なりながら密集する想定)。
  static const double laneSpacingPx = 0.5;

  /// 隊列の「-」区切りグループ1つあたりの縦方向(ゴールからの絶対残距離)
  /// オフセット(m)。グループ番号が大きい(後方)ほどdistanceFromGoalが増える。
  static const double groupSpacingMeters = 4.0;

  /// 内ラチへのめり込み防止のため、全馬の横方向オフセットに加算する
  /// 固定マージン(px)。coords.pixelsPerMeter≈0.5(1px≈2m)であるため、
  /// 4.75px≈9.5m相当。最内枠(laneRank=-8.5)が内ラチ境界(lateralOffset=0)より
  /// 約+1m走路側に来るよう設定。
  static const double innerMarginPx = 4.75;

  /// [追加] 改善Phase2 positionScore 1点あたりの距離差(m)。
  /// 順位ベース(順位×4m)の瞬間移動を解消し、スコア差を距離差として表現する。
  /// [修正] 改善Phase11 8.0では馬群が約20mにしかならず画面(幅60m相当)を持て余すため
  /// 16.0へ。13頭で約40mとなり、実際の決着時の馬群の長さに近づく (v.2026.9.18+26091802)
  static const double scoreToMeters = 16.0;

  /// [追加] 改善Phase2 先頭馬からの距離差の上限(m)。
  /// スコアが外れ値になった場合でも馬群が破綻しないようクランプする。
  /// [修正] 改善Phase11 scoreToMetersを2倍にしたため、上限も比例して引き上げる (v.2026.9.18+26091802)
  static const double maxScoreSpreadMeters = 160.0;

  /// [追加] 改善Phase2 キーフレーム間の最小前進量(m)。
  /// スコア差の変動で残距離が増える(馬が後退する)ことを防ぐ。
  static const double minForwardStepMeters = 1.0;

  /// [追加] 改善Phase3 スナップショットの刻み(m)。
  /// 7点のキーフレームをこの間隔でリサンプリングし、動きをなめらかにする。
  static const double snapshotIntervalMeters = 100.0;

  /// [追加] 改善Phase9 同じレーンで必要な前後の間隔(m)。1馬身=2.4m。
  /// 画面のマーカーが重なる場合はこの値だけを4.0に上げて調整する。
  static const double horseLengthMeters = 2.4;

  /// [追加] 改善Phase9 横に並んで走れるとみなす最小レーン差(≒1m)。
  static const double sideBySideLaneGap = 1.0;

  /// [修正] 改善Phase10 区間別の「100mで馬群内の相対位置を動かせる割合」。
  /// メートルで制限すると馬群自体が縮んでしまうため、馬群の長さは目標どおりにし、
  /// 隊列の中での位置(0=先頭, 1=最後方)の変化だけを制限する (v.2026.9.18+26091802)
  static const double moveAllowanceStart = 0.15;
  static const double moveAllowanceCorner = 0.02;
  static const double moveAllowanceBackstretch = 0.06;
  static const double moveAllowanceHomeStraight = 0.12;
  static const double moveAllowanceDefault = 0.06;

  /// [修正] 改善Phase10 坂での上乗せ(割合)と、坂とみなす勾配 (v.2026.9.18+26091802)
  static const double moveAllowanceSlopeBonus = 0.04;
  static const double slopeThreshold = 0.005;

  /// [追加] 改善Phase9 ゴール手前で移動制限を解除する距離(m)。
  /// この区間では計算結果どおりの位置へ到達させる。
  static const double finalConvergeMeters = 100.0;

  /// [修正] 改善Phase13 100mあたりの内寄せ量を「最内までの距離に対する割合」にする。
  /// 固定値(0.5レーン)では外にいる馬がラチ沿いに到達するのに3000m以上かかり、
  /// 隊列が絞られなかった。外にいる馬ほど速く寄り、内に近いほど緩やかになる
  /// (v.2026.9.18+26091802)
  static const double inwardFractionPer100m = 0.30;

  /// [追加] 改善Phase13 内へ移るときにだけ必要な前後の間隔の倍率。
  /// 並走を続ける判定は horseLengthMeters(2.4m)のままだが、内へ入るときは
  /// その2倍(4.8m)空いていることを要求し、全馬が最内の1列に並ぶのを防ぐ
  /// (v.2026.9.18+26091802)
  static const double innerEntryClearanceFactor = 2.0;

  /// [追加] 改善Phase9 進出中の馬が100mで外へ持ち出せる最大レーン数。
  static const double outwardStepPer100m = 1.0;

  /// [追加] 改善Phase10 発走時のゲート1頭分の幅(レーン単位=m)。
  /// 実際のゲートは1頭あたり約1.1m。sideBySideLaneGap(1.0)より広くすることで、
  /// 発走直後に全馬が衝突扱いになるのを防ぐ (v.2026.9.18+26091802)
  static const double gateLaneSpacing = 1.1;

  /// [追加] 改善Phase6 スタミナ差による距離補正の強さ(m / 負荷km / スタミナ差1.0)。
  static const double staminaMeterFactor = 8.0;

  /// [追加] 改善Phase6 ペース圧(前にいる馬の消耗)の強さ(m / km)。
  static const double paceMeterFactor = 10.0;

  /// [追加] 改善Phase6 累積の上り1mを何km相当の負荷とみなすかの係数。
  static const double climbToKmFactor = 0.15;

  /// [追加] 改善Phase6 累積標高の算出ステップ(m)。
  static const double _climbSampleStepMeters = 50.0;

  /// [追加] 改善Phase8 最内レーン(_styleLaneRankの逃げの基準値と同値)。
  static const double laneRailMin = 0.5;

  /// [追加] 改善Phase8 「進出中」と判定する、先頭からの遅れの縮小量(m)。
  static const double gainThresholdMeters = 3.0;

  /// 出走取消済み除外後の各馬について、発走(d0)〜ゴール(d6)の7キーフレーム分の
  /// Snapshot配列(time, distanceFromGoal, laneRank)を構築する。
  static Future<RaceSimulationData?> build({
    required PredictionRaceData raceData,
    required List<PredictionHorseDetail> horses,
    required Map<String, List<HorseRaceRecord>> allPastRecords,
    required RaceCourseData? raceCourse,
    required double raceDistance,
    Map<String, HorseSimulationParams> simulationParams = const {},
    // [追加] フェーズ5-2 スピード指数。build()自身のレーン/衝突解決ロジックでは使わず、
    // 内部のRaceAnalyzer.simulateRaceDevelopment呼び出しへそのまま転送するのみ (v.2026.7.30+26073001)
    Map<String, HorseSpeedIndex> speedIndexParams = const {},
    // [追加] 馬場状態補正: 良=1.00, 稍重=1.03, 重=1.06, 不良=1.10 等 (v2026.6.25)
    double trackSpeedMultiplier = 1.0,
    // [追加] 0-9 馬場の硬軟による前残り/差しの全体バイアス (v.2026.7.27+26072702)
    double trackBias = 0.0,
    // [追加] 0-9b-3 ユーザーによるペース手動選択（未指定時はアプリ予想を使用） (v.2026.7.27+26072707)
    String? paceOverride,
    // [追加] 改善Phase7 枠順が発表済みかどうか。falseのとき(仮枠番)は枠番由来の
    // 有利不利を計算に入れない (v.2026.9.18+26091802)
    bool gatesConfirmed = true,
  }) async {
    if (horses.isEmpty || raceDistance <= 0) return null;

    // raceDistanceと馬場状態補正から実レース時間(秒)を算出し、アニメーション基準時間とする
    final totalAnimationSeconds = raceDistance / _baseSpeedMps * trackSpeedMultiplier;

    // [追加] 改善Phase2 各局面のpositionScoreを受け取り距離算出に使う (v.2026.9.18+26091802)
    final phaseScores = <String, Map<String, double>>{};

    final development = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      const ['テン', '1コーナー', '2コーナー', '3コーナー', '4コーナー', '直線'],
      const {},
      horsesOverride: horses,
      simulationParams: simulationParams,
      speedIndexParams: speedIndexParams,
      trackBias: trackBias,
      paceOverride: paceOverride,
      // [追加] 改善Phase2 (v.2026.9.18+26091802)
      outPhaseScores: phaseScores,
      // [追加] 改善Phase7 (v.2026.9.18+26091802)
      gatesConfirmed: gatesConfirmed,
    );

    // 「ゴールからの絶対残距離」(d0=raceDistance→d6=0, 単調減少)
    // minKeyframeGapMeters保証で等時間キーフレームを防止
    const double minKeyframeGapMeters = 20.0;
    final d0 = raceDistance;
    // d1: テン（固定比率・コース形状非依存）
    final d1 = _clampD(raceDistance * 0.88, 0.0, d0 - minKeyframeGapMeters);
    // d2: 1コーナー初回出現（多周回コース対応）
    final d2 = _clampD(
      _cornerMidFirst(raceCourse, const ['corner_1'],
          fallback: raceDistance * 0.75),
      0.0,
      d1 - minKeyframeGapMeters,
    );
    // d3: 2コーナー初回出現
    final d3 = _clampD(
      _cornerMidFirst(raceCourse, const ['corner_2'],
          fallback: raceDistance * 0.60),
      0.0,
      d2 - minKeyframeGapMeters,
    );
    // d4: 3コーナー最終出現（ゴールに最も近い3コーナー）
    final d4 = _clampD(
      _cornerMid(raceCourse, const ['corner_3'],
          fallback: raceDistance * 0.40),
      0.0,
      d3 - minKeyframeGapMeters,
    );
    // d5: 4コーナー最終出現
    final d5 = _clampD(
      _cornerMid(raceCourse, const ['corner_4'],
          fallback: raceDistance * 0.20),
      minKeyframeGapMeters, // ゴール(0)との最低ギャップを保証
      d4 - minKeyframeGapMeters,
    );
    const d6 = 0.0; // ゴール（直線終了）

    final distances = <double>[d0, d1, d2, d3, d4, d5, d6];
    // [追加] 坂補正: キーフレーム間の平均勾配から速度倍率を算出し時間軸を非線形化 (v2026.6.25)
    final times = _buildKeyframeTimes(
      distances: distances,
      raceCourse: raceCourse,
      raceDistance: raceDistance,
      totalAnimationSeconds: totalAnimationSeconds,
    );

    // 各キーフレームでの隊列グループ（「-」区切りの前後グループ × 内側からの並び順）
    final orderedByGate = List<PredictionHorseDetail>.from(horses)
      ..sort((a, b) => a.gateNumber.compareTo(b.gateNumber));
    // d0: スタートゲート（枠番順の横一列）
    final order0Groups = [
      orderedByGate.map((h) => h.horseNumber.toString()).toList()
    ];
    final order1Groups = parseTairetsuGroups(development['テン']);
    final order2Groups = parseTairetsuGroups(development['1コーナー']);
    final order3Groups = parseTairetsuGroups(development['2コーナー']);
    final order4Groups = parseTairetsuGroups(development['3コーナー']);
    final order5Groups = parseTairetsuGroups(development['4コーナー']);
    final order6Groups = parseTairetsuGroups(development['直線']);

    final orderGroups = <List<List<String>>>[
      order0Groups, // d0: スタート
      order1Groups, // d1: テン
      order2Groups, // d2: 1コーナー
      order3Groups, // d3: 2コーナー
      order4Groups, // d4: 3コーナー
      order5Groups, // d5: 4コーナー
      order6Groups, // d6: ゴール（直線）
    ];

    // [追加] 改善Phase2 キーフレームindex -> 局面名。d0(スタート)は対応する局面が無い (v.2026.9.18+26091802)
    const phaseNames = <String?>[
      null,
      'テン',
      '1コーナー',
      '2コーナー',
      '3コーナー',
      '4コーナー',
      '直線',
    ];

    // [追加] 改善Phase2 各キーフレームの先頭馬(最小)スコア。
    // スコアが取得できないキーフレームはnullのままとし、従来の順位ベースで距離を算出する (v.2026.9.18+26091802)
    final phaseMinScores = List<double?>.filled(7, null);
    for (int i = 1; i < 7; i++) {
      final phaseName = phaseNames[i];
      final scores = phaseName == null ? null : phaseScores[phaseName];
      if (scores == null || scores.isEmpty) continue;
      double minScore = double.infinity;
      for (final horse in horses) {
        final score = scores[horse.horseNumber.toString()];
        if (score != null && score < minScore) minScore = score;
      }
      if (minScore != double.infinity) {
        phaseMinScores[i] = minScore;
      }
    }

    final int n = horses.length;

    // Phase1: 全馬×全キーフレームの生(distanceFromGoal, laneRank)を計算
    final rawDistances =
        List<List<double>>.generate(n, (_) => List<double>.filled(7, 0.0));
    final rawLaneRanks =
        List<List<double>>.generate(n, (_) => List<double>.filled(7, 0.0));

    for (int h = 0; h < n; h++) {
      final horse = horses[h];
      final horseNumber = horse.horseNumber.toString();

      for (int i = 0; i < 7; i++) {
        final groups = orderGroups[i];

        int groupIndex = -1;
        int idxInGroup = -1;
        int groupSize = 1;
        for (int g = 0; g < groups.length; g++) {
          final idx = groups[g].indexOf(horseNumber);
          if (idx >= 0) {
            groupIndex = g;
            idxInGroup = idx;
            groupSize = groups[g].length;
            break;
          }
        }

        // d0=枠番ベース縦配列 / d1以降=脚質ベース内外優先度
        final double laneRank;
        if (i == 0) {
          // スタートゲート: 枠番順の縦1列（既存動作）
          laneRank = groupIndex >= 0
              ? idxInGroup - (groupSize - 1) / 2.0
              : 0.0;
        } else {
          // d1以降: 脚質ベース（逃げ=内、追込=外）
          laneRank =
              _styleLaneRank(simulationParams[horseNumber], horse.gateNumber);
        }

        // [削除] 改善Phase7 確定的ゆらぎ(±1グループ)はデータに基づかない順位変動であり、
        // ゴール順位まで動かしていたため廃止。順位ベースのフォールバックは
        // 隊列の並び順をそのまま使う (v.2026.9.18+26091802)
        final int effectiveGroupIndex = groupIndex;
        // [修正] 改善Phase2 距離を「順位×4m」ではなく「先頭馬とのpositionScore差×k」で
        // 算出する。スコアが取得できないキーフレーム(d0や取得失敗時)は従来の
        // 順位ベースにフォールバックする (v.2026.9.18+26091802)
        final double distanceFromGoal;
        final phaseName = phaseNames[i];
        final phaseScore =
            phaseName == null ? null : phaseScores[phaseName]?[horseNumber];
        final minPhaseScore = phaseMinScores[i];
        if (i > 0 && phaseScore != null && minPhaseScore != null) {
          final gapMeters = ((phaseScore - minPhaseScore) * scoreToMeters)
              .clamp(0.0, maxScoreSpreadMeters);
          distanceFromGoal = distances[i] + gapMeters;
        } else {
          distanceFromGoal = effectiveGroupIndex >= 0
              ? distances[i] + effectiveGroupIndex * groupSpacingMeters
              : distances[i];
        }

        rawDistances[h][i] = distanceFromGoal;
        rawLaneRanks[h][i] = laneRank;
      }
    }

    // [追加] 改善Phase6 走破距離・累積の上り・ペースから消耗を積み上げ、
    // 各馬の「先頭からの遅れ(m)」を直接補正する。スタミナの高い馬は遅れが縮み、
    // 低い馬・前にいる馬ほど遅れが広がる (v.2026.9.18+26091802)
    final effectivePace = paceOverride ??
        raceData.racePacePrediction?.predictedPace ??
        'ミドルペース';
    final paceLoadFactor = _paceLoadFactor(effectivePace);
    final cumulativeClimbs =
        _cumulativeClimbAtKeyframes(raceCourse, distances, raceDistance);

    for (int i = 1; i < 7; i++) {
      final travelled = raceDistance - distances[i];
      if (travelled <= 0) continue;

      double maxGap = 0.0;
      for (int h = 0; h < n; h++) {
        final gap = rawDistances[h][i] - distances[i];
        if (gap > maxGap) maxGap = gap;
      }

      final loadKm = (travelled / 1000.0) * paceLoadFactor +
          cumulativeClimbs[i] * climbToKmFactor;

      for (int h = 0; h < n; h++) {
        final gap = rawDistances[h][i] - distances[i];
        final frontness = maxGap > 0.0 ? (1.0 - gap / maxGap) : 1.0;
        final stamina =
            simulationParams[horses[h].horseNumber.toString()]?.staminaIndex ??
                0.5;

        // スタミナ差による消耗(前にいる馬ほど負荷が大きい)
        final staminaDelta = loadKm *
            (0.5 - stamina) *
            staminaMeterFactor *
            (0.5 + frontness);
        // ペース圧(ハイペースは前が消耗、スローは前が有利。後方の馬には効かない)
        final pacePressure = (paceLoadFactor - 1.0) *
            frontness *
            (travelled / 1000.0) *
            paceMeterFactor;

        final adjustedGap = (gap + staminaDelta + pacePressure)
            .clamp(0.0, maxScoreSpreadMeters);
        rawDistances[h][i] = distances[i] + adjustedGap;
      }
    }

    // [追加] 改善Phase12 消耗補正で全馬の遅れが同時に増えると、先頭馬でも遅れが
    // 0にならず、誰もゴール(残距離0m)に到達しなくなる。各キーフレームで最小の遅れが
    // 0になるよう正規化する。馬同士の差は変わらない (v.2026.9.18+26091802)
    for (int i = 1; i < 7; i++) {
      double minGap = double.infinity;
      for (int h = 0; h < n; h++) {
        final gap = rawDistances[h][i] - distances[i];
        if (gap < minGap) minGap = gap;
      }
      if (minGap.isFinite && minGap != 0.0) {
        for (int h = 0; h < n; h++) {
          rawDistances[h][i] -= minGap;
        }
      }
    }

    // [追加] 改善Phase2 スコア差の変動でキーフレーム間の残距離が増える(＝馬が
    // 後退して見える)ことを防ぐため、各馬の残距離を単調減少に補正する (v.2026.9.18+26091802)
    for (int h = 0; h < n; h++) {
      for (int i = 1; i < 7; i++) {
        final maxAllowed = rawDistances[h][i - 1] - minForwardStepMeters;
        if (rawDistances[h][i] > maxAllowed) {
          rawDistances[h][i] = maxAllowed;
        }
      }
    }

    // [修正] 改善Phase10 100mごとの逐次計算。移動制限は「メートル」ではなく
    // 「馬群内の相対位置の割合」にかける。これにより馬群の長さは目標(スコア計算)
    // どおりに伸び縮みし、隊列の中での位置だけが区間ごとの割合で動く。
    // 発走地点(最初のサンプル)は隊列整形を行わず、ゲートの並びをそのまま出す
    // (v.2026.9.18+26091802)
    // [追加] 改善Phase13 最終コーナーを出た地点。これ以降は内寄せを行わない (v.2026.9.18+26091802)
    final double? finalStraightStart = _finalStraightStartFromStart(raceCourse);

    final sampleRefDistances = <double>[];
    for (double refDistance = d0;
        refDistance > 0.0;
        refDistance -= snapshotIntervalMeters) {
      sampleRefDistances.add(refDistance);
    }
    sampleRefDistances.add(0.0);

    // スタート時のレーン: ゲートの並び(d0)を最内基準に、1頭分の幅で配置する
    double startLaneMin = rawLaneRanks[0][0];
    for (int h = 1; h < n; h++) {
      if (rawLaneRanks[h][0] < startLaneMin) startLaneMin = rawLaneRanks[h][0];
    }
    final currentLanes = List<double>.generate(
        n,
        (h) =>
            laneRailMin +
            (rawLaneRanks[h][0] - startLaneMin) * gateLaneSpacing);
    final currentGaps = List<double>.filled(n, 0.0);
    final targetGaps = List<double>.filled(n, 0.0);
    final wantsToAdvance = List<bool>.filled(n, false);
    final previousDistances = List<double>.filled(n, double.infinity);
    final snapshotsByHorse =
        List<List<RaceSimSnapshot>>.generate(n, (_) => <RaceSimSnapshot>[]);

    for (int s = 0; s < sampleRefDistances.length; s++) {
      final refDistance = sampleRefDistances[s];

      // refDistanceが属するキーフレーム区間(seg = 0〜5)
      int seg = 0;
      while (seg < 5 && distances[seg + 1] > refDistance) {
        seg++;
      }
      final segStart = distances[seg];
      final segEnd = distances[seg + 1];
      final span = segStart - segEnd;
      final u = span > 0.0
          ? ((segStart - refDistance) / span).clamp(0.0, 1.0)
          : 1.0;
      final eased = _smoothStep(u);
      final time = times[seg] + (times[seg + 1] - times[seg]) * u;

      final distanceFromStart = raceDistance - refDistance;
      final bool converging = refDistance <= finalConvergeMeters;
      final double allowanceRatio = converging
          ? 1.0
          : _moveAllowanceRatioPer100m(raceCourse, distanceFromStart) *
              (snapshotIntervalMeters / 100.0);

      // 目標の遅れと、その時点の馬群の長さ(目標)
      double targetSpread = 0.0;
      for (int h = 0; h < n; h++) {
        final targetStart = rawDistances[h][seg] - distances[seg];
        final targetEnd = rawDistances[h][seg + 1] - distances[seg + 1];
        targetGaps[h] = targetStart + (targetEnd - targetStart) * eased;
        if (targetGaps[h] > targetSpread) targetSpread = targetGaps[h];
      }

      // 現在の馬群の長さ
      double currentSpread = 0.0;
      for (int h = 0; h < n; h++) {
        if (currentGaps[h] > currentSpread) currentSpread = currentGaps[h];
      }

      for (int h = 0; h < n; h++) {
        final targetRatio =
            targetSpread > 0.0 ? targetGaps[h] / targetSpread : 0.0;
        final currentRatio =
            currentSpread > 0.0 ? currentGaps[h] / currentSpread : 0.0;

        // 進出中(馬群内で前へ上がろうとしている)かどうか
        wantsToAdvance[h] =
            (currentRatio - targetRatio) * targetSpread >= gainThresholdMeters;

        final diff = targetRatio - currentRatio;
        double nextRatio;
        if (converging || diff.abs() <= allowanceRatio) {
          nextRatio = targetRatio;
        } else {
          nextRatio =
              currentRatio + (diff > 0 ? allowanceRatio : -allowanceRatio);
        }
        if (nextRatio < 0.0) nextRatio = 0.0;

        // 馬群の長さは目標どおりにし、その中での位置だけを制限する
        currentGaps[h] = nextRatio * targetSpread;
      }

      // 発走地点(s == 0)はゲートの並びをそのまま使う
      if (s > 0) {
        // [追加] 改善Phase13 最終コーナーを出た以降は内寄せを行わない (v.2026.9.18+26091802)
        final bool inFinalStraight = finalStraightStart != null &&
            distanceFromStart >= finalStraightStart;

        _resolveFormationAtSample(
          n: n,
          horses: horses,
          simulationParams: simulationParams,
          currentGaps: currentGaps,
          currentLanes: currentLanes,
          wantsToAdvance: wantsToAdvance,
          allowPushBack: !converging,
          allowInward: !inFinalStraight,
        );
      }

      for (int h = 0; h < n; h++) {
        if (currentGaps[h] > maxScoreSpreadMeters) {
          currentGaps[h] = maxScoreSpreadMeters;
        }
        double distanceFromGoal = refDistance + currentGaps[h];
        final maxAllowed = previousDistances[h] - minForwardStepMeters;
        if (distanceFromGoal > maxAllowed) {
          distanceFromGoal = maxAllowed;
        }
        if (distanceFromGoal < 0.0) {
          distanceFromGoal = 0.0;
        }
        previousDistances[h] = distanceFromGoal;

        snapshotsByHorse[h].add(RaceSimSnapshot(
          time: time,
          distanceFromGoal: distanceFromGoal,
          laneRank: currentLanes[h],
        ));
      }
    }

    final horseTracks = <RaceSimHorseTrack>[];
    for (int h = 0; h < n; h++) {
      horseTracks.add(RaceSimHorseTrack(
        horseNumber: horses[h].horseNumber.toString(),
        gateNumber: horses[h].gateNumber,
        snapshots: snapshotsByHorse[h],
      ));
    }

    return RaceSimulationData(
      horseTracks: horseTracks,
      developmentTexts: development,
      totalTime: totalAnimationSeconds,
    );
  }

  /// [追加] 改善Phase3 スムーズステップ補間 (0→1の変化を両端でなだらかにする) (v.2026.9.18+26091802)
  static double _smoothStep(double t) {
    final u = t.clamp(0.0, 1.0);
    return u * u * (3.0 - 2.0 * u);
  }

  static double _clampD(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  /// raceCourse.sections（distanceFromStart基準）からsectionNamesに該当する
  /// 最後（=ゴールに最も近い）の連続グループを探し、その中間値を
  /// 「ゴールからの絶対残距離」に変換して返す。該当が無い場合はfallbackを返す。
  static double _cornerMid(
    RaceCourseData? raceCourse,
    List<String> sectionNames, {
    required double fallback,
  }) {
    if (raceCourse == null) return fallback;
    final sections = raceCourse.sections;

    final matches = <int>[];
    for (int i = 0; i < sections.length; i++) {
      if (sectionNames.contains(sections[i].name)) matches.add(i);
    }
    if (matches.isEmpty) return fallback;

    // 複数周回コースで同名セクションが複数存在する場合は、
    // ゴールに最も近い（最後の）連続グループのみを採用する
    final lastGroup = <int>[matches.last];
    for (int i = matches.length - 2; i >= 0; i--) {
      if (matches[i] == lastGroup.first - 1) {
        lastGroup.insert(0, matches[i]);
      } else {
        break;
      }
    }

    double minStart = sections[lastGroup.first].startDistance;
    double maxEnd = sections[lastGroup.first].endDistance;
    for (final idx in lastGroup) {
      if (sections[idx].startDistance < minStart) {
        minStart = sections[idx].startDistance;
      }
      if (sections[idx].endDistance > maxEnd) {
        maxEnd = sections[idx].endDistance;
      }
    }
    final midFromStart = (minStart + maxEnd) / 2.0;
    return raceCourse.raceDistance - midFromStart;
  }

  /// raceCourse.sections から sectionNames に該当する「最初の」連続グループを探し、
  /// その中間値を「ゴールからの絶対残距離」に変換して返す。
  /// 多周回コースで1コーナー・2コーナーが複数出現する場合、スタートに最も近い
  /// （最初の）出現を使うことでテン〜2コーナー区間の正確な距離を得る。
  static double _cornerMidFirst(
    RaceCourseData? raceCourse,
    List<String> sectionNames, {
    required double fallback,
  }) {
    if (raceCourse == null) return fallback;
    final sections = raceCourse.sections;

    final matches = <int>[];
    for (int i = 0; i < sections.length; i++) {
      if (sectionNames.contains(sections[i].name)) matches.add(i);
    }
    if (matches.isEmpty) return fallback;

    // 最初の連続グループのみ採用
    final firstGroup = <int>[matches.first];
    for (int i = 1; i < matches.length; i++) {
      if (matches[i] == firstGroup.last + 1) {
        firstGroup.add(matches[i]);
      } else {
        break;
      }
    }

    double minStart = sections[firstGroup.first].startDistance;
    double maxEnd = sections[firstGroup.first].endDistance;
    for (final idx in firstGroup) {
      if (sections[idx].startDistance < minStart) {
        minStart = sections[idx].startDistance;
      }
      if (sections[idx].endDistance > maxEnd) {
        maxEnd = sections[idx].endDistance;
      }
    }
    final midFromStart = (minStart + maxEnd) / 2.0;
    return raceCourse.raceDistance - midFromStart;
  }

  /// "(3,5)-7-12" 形式の隊列文字列を [['3','5'], ['7'], ['12']] に変換する。
  /// 「-」区切りの各トークンが1グループ（前後関係）、トークン内の「()」が
  /// 並走する馬（横方向のみの関係）を表す。
  static List<List<String>> parseTairetsuGroups(String? tairetsu) {
    if (tairetsu == null || tairetsu.isEmpty) return [];
    return tairetsu
        .split('-')
        .map((token) => token
            .replaceAll(RegExp(r'[()]'), '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList())
        .where((group) => group.isNotEmpty)
        .toList();
  }

  /// 脚質に基づくレーンランク（内外優先度）を返す。逃げ=最内(0.5)、追込=最外(6.0)。
  /// 同脚質の馬は枠番で微分散（0〜1.05）させて初期位置が重ならないようにする。
  static double _styleLaneRank(
      HorseSimulationParams? params, int gateNumber) {
    double base;
    if (params?.legStyle == '逃げ') {
      base = 0.5;
    } else if (params?.legStyle == '先行') {
      base = 2.0;
    } else if (params?.legStyle == '自在') {
      base = 1.5;
    } else if (params?.legStyle == '差し') {
      base = 4.0;
    } else if (params?.legStyle == '追込') {
      base = 6.0;
    } else {
      base = 3.0;
    }
    // 同脚質内で枠番を使って微分散（0〜1.05の範囲）
    return base + (gateNumber - 1) * 0.15;
  }

  /// [追加] 改善Phase8 脚質ごとの「内を取りたい強さ」(0.0〜1.0) (v.2026.9.18+26091802)
  static double _styleInwardTendency(HorseSimulationParams? params) {
    switch (params?.legStyle) {
      case '逃げ':
        return 1.0;
      case '先行':
        return 0.8;
      case '自在':
        return 0.6;
      case 'マクリ':
        return 0.5;
      case '差し':
        return 0.4;
      case '追込':
        return 0.3;
      default:
        return 0.5;
    }
  }

  /// [追加] 改善Phase13 最後の corner_4 区間が終わる地点(スタートからの距離)を返す。
  /// これ以降は最終直線とみなし、内寄せを行わない。
  /// コーナーが無いコース(直線競走)や区間データが無い場合は null (v.2026.9.18+26091802)
  static double? _finalStraightStartFromStart(RaceCourseData? raceCourse) {
    if (raceCourse == null) return null;
    double? lastCornerEnd;
    for (final section in raceCourse.sections) {
      if (section.name == 'corner_4') {
        if (lastCornerEnd == null || section.endDistance > lastCornerEnd) {
          lastCornerEnd = section.endDistance;
        }
      }
    }
    return lastCornerEnd;
  }

  /// [修正] 改善Phase10 その地点(スタートからの距離)で、100mあたり馬群内の相対位置を
  /// 動かしてよい割合を返す。コース区間(start/corner/backstretch/home_straight/finish)と
  /// 坂の有無で決まる。コーナーでは小さく、直線とスタート直後・坂では大きくする
  /// (v.2026.9.18+26091802)
  static double _moveAllowanceRatioPer100m(
    RaceCourseData? raceCourse,
    double distanceFromStart,
  ) {
    if (raceCourse == null) return moveAllowanceDefault;

    String sectionName = '';
    for (final section in raceCourse.sections) {
      if (distanceFromStart >= section.startDistance &&
          distanceFromStart < section.endDistance) {
        sectionName = section.name;
        break;
      }
    }

    double allowance;
    switch (sectionName) {
      case 'start':
      case 'start_turf':
      case 'start_dirt':
        allowance = moveAllowanceStart;
        break;
      case 'corner_1':
      case 'corner_2':
      case 'corner_3':
      case 'corner_4':
        allowance = moveAllowanceCorner;
        break;
      case 'backstretch':
      case 'straight':
        allowance = moveAllowanceBackstretch;
        break;
      case 'home_straight':
      case 'finish':
        allowance = moveAllowanceHomeStraight;
        break;
      default:
        allowance = moveAllowanceDefault;
    }

    // 坂: 勾配が閾値以上の地点は動きやすさを上乗せする
    final lapDistance = raceCourse.baseData.lapDistance;
    if (lapDistance > 0) {
      final lapPos = distanceFromStart % lapDistance;
      const double delta = 50.0;
      final e1 = raceCourse.baseData
          .getElevationAt((lapPos - delta).clamp(0.0, lapDistance));
      final e2 = raceCourse.baseData
          .getElevationAt((lapPos + delta).clamp(0.0, lapDistance));
      final gradient = (e2 - e1) / (2 * delta);
      if (gradient.abs() >= slopeThreshold) {
        allowance += moveAllowanceSlopeBonus;
      }
    }
    return allowance;
  }

  /// [修正] 改善Phase10 1サンプル地点の隊列整形。先頭の馬から順に配置する。
  /// 内寄せは「その位置のまま内側が空いている場合」だけ行い、空いていなければ
  /// 今のレーンを維持する(位置を落としてまで内に入らない)。
  /// 後ろへ下げるのは、今のレーンで前が詰まったときだけ。
  /// 進出中の馬は外へ持ち出して抜く。先頭の馬は押されない (v.2026.9.18+26091802)
  static void _resolveFormationAtSample({
    required int n,
    required List<PredictionHorseDetail> horses,
    required Map<String, HorseSimulationParams> simulationParams,
    required List<double> currentGaps,
    required List<double> currentLanes,
    required List<bool> wantsToAdvance,
    required bool allowPushBack,
    // [追加] 改善Phase13 最終直線では内寄せを行わない (v.2026.9.18+26091802)
    required bool allowInward,
  }) {
    if (n == 0) return;

    final inwardLanes = List<double>.filled(n, 0.0);
    final laneCeilings = List<double>.filled(n, 0.0);
    for (int h = 0; h < n; h++) {
      final params = simulationParams[horses[h].horseNumber.toString()];
      // [修正] 改善Phase13 最内までの距離に対する割合で内へ寄る。
      // 最終直線(allowInward == false)では内寄せを行わない (v.2026.9.18+26091802)
      double inward = currentLanes[h];
      if (allowInward) {
        inward = currentLanes[h] -
            (currentLanes[h] - laneRailMin) *
                inwardFractionPer100m *
                _styleInwardTendency(params);
        if (inward < laneRailMin) inward = laneRailMin;
      }
      inwardLanes[h] = inward;
      laneCeilings[h] = currentLanes[h] + outwardStepPer100m;
    }

    // 先頭(遅れが小さい馬)から順に置く
    final order = List<int>.generate(n, (h) => h)
      ..sort((a, b) => currentGaps[a].compareTo(currentGaps[b]));

    final placedLanes = <double>[];
    final placedGaps = <double>[];

    for (final h in order) {
      double lane = currentLanes[h];
      double gap = currentGaps[h];

      // 1) 内側が空いているときだけ内へ寄る。空いていなければ今のレーンを維持する
      final inwardLane = inwardLanes[h];
      // [修正] 改善Phase13 内へ入るときだけ、必要な前後の間隔を
      // innerEntryClearanceFactor倍にする。はっきり空いているときだけ内へ入る
      // (v.2026.9.18+26091802)
      if (inwardLane < lane &&
          _findConflictIndex(inwardLane, gap, placedLanes, placedGaps,
                  horseLengthMeters * innerEntryClearanceFactor) <
              0) {
        lane = inwardLane;
      }

      // 2) 今のレーンで前が詰まっている場合だけ解決する
      for (int attempt = 0; attempt < 16; attempt++) {
        final conflict = _findConflictIndex(
            lane, gap, placedLanes, placedGaps, horseLengthMeters);
        if (conflict < 0) break;

        final blockerLane = placedLanes[conflict];
        final blockerGap = placedGaps[conflict];
        final outerCandidate = blockerLane + sideBySideLaneGap;

        if (wantsToAdvance[h] && outerCandidate <= laneCeilings[h]) {
          // 進出中の馬は外へ持ち出して抜く(まくり・進出)
          lane = outerCandidate;
          continue;
        }
        if (allowPushBack) {
          // 同じレーンの後ろに並ぶ(自分が後方なので自分が下がる)
          gap = blockerGap + horseLengthMeters;
          continue;
        }
        // ゴール前は下げずに横へ逃がす
        lane = outerCandidate;
      }

      currentLanes[h] = lane;
      currentGaps[h] = gap;
      placedLanes.add(lane);
      placedGaps.add(gap);
    }
  }

  /// [追加] 改善Phase10 配置済みの馬と重なるかを判定する。
  /// 横に sideBySideLaneGap 以上離れていれば並走とみなして衝突としない。
  /// 同じレーン(横がそれ未満)で前後 horseLengthMeters 未満なら衝突 (v.2026.9.18+26091802)
  static int _findConflictIndex(
    double lane,
    double gap,
    List<double> placedLanes,
    List<double> placedGaps,
    // [追加] 改善Phase13 必要な前後の間隔(m)。内へ入るときだけ大きくする (v.2026.9.18+26091802)
    double requiredGapMeters,
  ) {
    for (int p = 0; p < placedLanes.length; p++) {
      if ((lane - placedLanes[p]).abs() < sideBySideLaneGap &&
          (gap - placedGaps[p]).abs() < requiredGapMeters) {
        return p;
      }
    }
    return -1;
  }

  /// 枠順発表前（全馬 horseNumber=0）のときに呼ぶ仮番号付与ヘルパー。
  /// 馬名のあいうえお順でソートし、1 始まりの連番を割り当てる。
  /// 上限なし（19頭・20頭以上でも動作する）。
  static List<PredictionHorseDetail> assignTempNumbers(
      List<PredictionHorseDetail> horses) {
    final sorted = List<PredictionHorseDetail>.from(horses)
      ..sort((a, b) => a.horseName.compareTo(b.horseName));
    return sorted.asMap().entries.map((entry) {
      final tempNum = entry.key + 1;
      final tempGate = ((tempNum - 1) ~/ 2) + 1;
      final h = entry.value;
      return PredictionHorseDetail(
        horseId: h.horseId,
        horseNumber: tempNum,
        gateNumber: tempGate,
        horseName: h.horseName,
        sexAndAge: h.sexAndAge,
        jockey: h.jockey,
        jockeyId: h.jockeyId,
        carriedWeight: h.carriedWeight,
        trainerName: h.trainerName,
        trainerAffiliation: h.trainerAffiliation,
        odds: h.odds,
        effectiveOdds: h.effectiveOdds,
        popularity: h.popularity,
        horseWeight: h.horseWeight,
        userMark: h.userMark,
        userMemo: h.userMemo,
        isScratched: h.isScratched,
        predictionScore: h.predictionScore,
        conditionFit: h.conditionFit,
        distanceCourseAptitudeStats: h.distanceCourseAptitudeStats,
        trackAptitudeLabel: h.trackAptitudeLabel,
        bestTimeStats: h.bestTimeStats,
        fastestAgariStats: h.fastestAgariStats,
        bestCourseTimeStats: h.bestCourseTimeStats,
        fastestCourseAgariStats: h.fastestCourseAgariStats,
        overallScore: h.overallScore,
        expectedValue: h.expectedValue,
        legStyleProfile: h.legStyleProfile,
        previousHorseWeight: h.previousHorseWeight,
        previousJockey: h.previousJockey,
        // [追加] 馬データ再生成時に前走騎手IDを引き継ぐ (v.2026.9.21+26092102)
        previousJockeyId: h.previousJockeyId,
        ownerName: h.ownerName,
        ownerId: h.ownerId,
        ownerImageLocalPath: h.ownerImageLocalPath,
        breederName: h.breederName,
        fatherName: h.fatherName,
        motherName: h.motherName,
        mfName: h.mfName,
        jockeyComboStats: h.jockeyComboStats,
        // ▼ [修正] 再構築時に競馬新聞マークが false にリセットされる不具合を修正 (v.2026.7.28+26072805)
        isBlinker: h.isBlinker,
        isFirstBlinker: h.isFirstBlinker,
        isMaruGai: h.isMaruGai,
        isMaruChi: h.isMaruChi,
        // ▲ [修正]
      );
    }).toList();
  }

  /// キーフレームの distanceFromGoal リストから、坂勾配を考慮した時刻リストを構築する。
  /// 各区間の中点における平均勾配を算出し、上り坂=減速・下り坂=加速として区間時間を補正する。
  /// 正規化により totalAnimationSeconds が常に最終時刻になることを保証する。
  /// シュート（引き込み線）スタートのレースは approach path の標高データが無いため、
  /// d0→d1 区間は本線の同距離帯の標高で近似する（誤差は軽微）。
  static List<double> _buildKeyframeTimes({
    required List<double> distances,
    required RaceCourseData? raceCourse,
    required double raceDistance,
    required double totalAnimationSeconds,
  }) {
    final times = <double>[0.0];
    for (int i = 1; i < distances.length; i++) {
      final sectionMeters = distances[i - 1] - distances[i];
      double speedMultiplier = 1.0;
      if (raceCourse != null && sectionMeters > 0) {
        final gradient = _sectionAverageGradient(
          raceCourse,
          distances[i - 1],
          distances[i],
          raceDistance,
        );
        speedMultiplier =
            (1.0 - gradient * _slopeInfluence).clamp(0.5, 1.5);
      }
      final linearTime =
          (sectionMeters / raceDistance) * totalAnimationSeconds;
      times.add(times.last + linearTime / speedMultiplier);
    }
    // 最終時刻が totalAnimationSeconds になるよう正規化
    final rawTotal = times.last;
    return [for (final t in times) t / rawTotal * totalAnimationSeconds];
  }

  /// [追加] 改善Phase6 ペース文字列から距離あたりの負荷係数を返す。
  /// ハイ=消耗が大きい、スロー=小さい (v.2026.9.18+26091802)
  static double _paceLoadFactor(String pace) {
    if (pace.contains('ハイ')) return 1.3;
    if (pace.contains('スロー')) return 0.8;
    return 1.0;
  }

  /// [追加] 改善Phase6 スタートから各キーフレーム地点までの「累積の上り(m)」を返す。
  /// 標高データが無い場合は全て0.0を返す(＝坂の影響なし)。
  /// 多周回コースは lapDistance で折り返して参照する (v.2026.9.18+26091802)
  static List<double> _cumulativeClimbAtKeyframes(
    RaceCourseData? raceCourse,
    List<double> distances,
    double raceDistance,
  ) {
    final result = List<double>.filled(distances.length, 0.0);
    if (raceCourse == null) return result;
    final lapDistance = raceCourse.baseData.lapDistance;
    if (lapDistance <= 0) return result;

    double climb = 0.0;
    double travelled = 0.0;
    double previousElevation = raceCourse.baseData.getElevationAt(0.0);

    while (travelled < raceDistance) {
      final next = travelled + _climbSampleStepMeters;
      travelled = next > raceDistance ? raceDistance : next;
      final elevation =
          raceCourse.baseData.getElevationAt(travelled % lapDistance);
      final diff = elevation - previousElevation;
      if (diff > 0) climb += diff;
      previousElevation = elevation;

      for (int i = 0; i < distances.length; i++) {
        // そのキーフレームの走破距離に到達していれば、その時点の累積上りを記録する
        if (raceDistance - distances[i] <= travelled && result[i] == 0.0) {
          result[i] = climb;
        }
      }
    }

    // 到達判定から漏れたキーフレーム(ゴール付近)には最終値を入れる
    for (int i = 0; i < distances.length; i++) {
      if (raceDistance - distances[i] >= raceDistance) {
        result[i] = climb;
      }
    }
    return result;
  }

  /// distanceFromGoal 区間の中点における 1周分標高データの平均勾配 (m/m) を返す。
  /// 多周回コースは % lapDistance で単周回座標に折り返す。
  static double _sectionAverageGradient(
    RaceCourseData raceCourse,
    double sectionStartDfg,
    double sectionEndDfg,
    double raceDistance,
  ) {
    final lapDist = raceCourse.baseData.lapDistance;
    final midDfs =
        raceDistance - (sectionStartDfg + sectionEndDfg) / 2.0;
    final lapPos = midDfs % lapDist;
    const double delta = 50.0;
    final e1 = raceCourse.baseData
        .getElevationAt((lapPos - delta).clamp(0.0, lapDist));
    final e2 = raceCourse.baseData
        .getElevationAt((lapPos + delta).clamp(0.0, lapDist));
    return (e2 - e1) / (2 * delta);
  }
}