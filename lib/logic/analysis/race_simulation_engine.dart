// lib/logic/analysis/race_simulation_engine.dart

import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
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

  /// 出走取消済み除外後の各馬について、発走(d0)〜ゴール(d6)の7キーフレーム分の
  /// Snapshot配列(time, distanceFromGoal, laneRank)を構築する。
  static Future<RaceSimulationData?> build({
    required PredictionRaceData raceData,
    required List<PredictionHorseDetail> horses,
    required Map<String, List<HorseRaceRecord>> allPastRecords,
    required RaceCourseData? raceCourse,
    required double raceDistance,
    Map<String, HorseSimulationParams> simulationParams = const {},
  }) async {
    if (horses.isEmpty || raceDistance <= 0) return null;

    // raceDistanceから実レース時間(秒)を算出し、アニメーション基準時間とする
    final totalAnimationSeconds = raceDistance / _baseSpeedMps;

    final development = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      const ['テン', '1コーナー', '2コーナー', '3コーナー', '4コーナー', '直線'],
      const {},
      horsesOverride: horses,
      simulationParams: simulationParams,
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
    final order1Groups = _parseTairetsuGroups(development['テン']);
    final order2Groups = _parseTairetsuGroups(development['1コーナー']);
    final order3Groups = _parseTairetsuGroups(development['2コーナー']);
    final order4Groups = _parseTairetsuGroups(development['3コーナー']);
    final order5Groups = _parseTairetsuGroups(development['4コーナー']);
    final order6Groups = _parseTairetsuGroups(development['直線']);

    final orderGroups = <List<List<String>>>[
      order0Groups, // d0: スタート
      order1Groups, // d1: テン
      order2Groups, // d2: 1コーナー
      order3Groups, // d3: 2コーナー
      order4Groups, // d4: 3コーナー
      order5Groups, // d5: 4コーナー
      order6Groups, // d6: ゴール（直線）
    ];

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

        // 確定的ゆらぎ: horseIdとキーフレームから±1グループの予想誤差を付与
        // d0(スタート)のみゆらぎなし（スタートゲートは枠番固定）
        final int effectiveGroupIndex;
        if (i > 0 && groupIndex >= 0) {
          final variance = _deterministicVariance(horse.horseId, i);
          effectiveGroupIndex =
              (groupIndex + variance).clamp(0, groups.length - 1);
        } else {
          effectiveGroupIndex = groupIndex;
        }
        final distanceFromGoal = effectiveGroupIndex >= 0
            ? distances[i] + effectiveGroupIndex * groupSpacingMeters
            : distances[i];

        rawDistances[h][i] = distanceFromGoal;
        rawLaneRanks[h][i] = laneRank;
      }
    }

    // Phase2: d1〜d6をビルド時に衝突解決（d0=スタートゲートはスキップ）
    // 各キーフレームで衝突を静的解決することでPainterのリアルタイム当たり判定を不要にし、
    // Y軸の急激なジャンプを根本的に排除する。
    for (int i = 1; i < 7; i++) {
      final lrList = List<double>.generate(n, (h) => rawLaneRanks[h][i]);
      final dfgList = List<double>.generate(n, (h) => rawDistances[h][i]);
      final resolved = _resolveCollisionsForKeyframe(lrList, dfgList);
      for (int h = 0; h < n; h++) {
        rawLaneRanks[h][i] = resolved[h];
      }
    }

    // Phase3: スナップショット構築
    final horseTracks = <RaceSimHorseTrack>[];
    for (int h = 0; h < n; h++) {
      final horse = horses[h];
      final snapshots = <RaceSimSnapshot>[];
      for (int i = 0; i < 7; i++) {
        snapshots.add(RaceSimSnapshot(
          time: times[i],
          distanceFromGoal: rawDistances[h][i],
          laneRank: rawLaneRanks[h][i],
        ));
      }
      horseTracks.add(RaceSimHorseTrack(
        horseNumber: horse.horseNumber.toString(),
        gateNumber: horse.gateNumber,
        snapshots: snapshots,
      ));
    }

    return RaceSimulationData(
      horseTracks: horseTracks,
      developmentTexts: development,
      totalTime: totalAnimationSeconds,
    );
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

  /// horseIdとキーフレームインデックスから -1/0/+1 の確定的変動値を返す。
  /// 同じ馬・同じキーフレームでは常に同じ値を返すためアニメーション中にちらつかない。
  static int _deterministicVariance(String horseId, int keyframe) {
    final hash = (horseId.hashCode ^ (keyframe * 2654435761)) & 0x7FFFFFFF;
    return (hash % 3) - 1; // -1, 0, +1
  }

  /// 1キーフレーム分の全馬laneRankをビルド時に衝突解決する。
  /// 進行距離が近い馬（|dx| < 6.0m）のみ対象とし、
  /// 内側(laneRank小)から順に処理して重なりを外側へ押し出す。
  static List<double> _resolveCollisionsForKeyframe(
    List<double> rawLaneRanks,
    List<double> distancesFromGoal,
  ) {
    const double collisionThresholdMeters = 6.0;
    const double minLaneGap = 18.0 / 13.0; // markerDiameter / laneSpacingY ≈ 1.38

    final n = rawLaneRanks.length;
    final indices = List<int>.generate(n, (i) => i);
    indices.sort((a, b) => rawLaneRanks[a].compareTo(rawLaneRanks[b]));

    final resolved = List<double>.from(rawLaneRanks);
    for (int i = 0; i < n; i++) {
      final idx = indices[i];
      for (int j = 0; j < i; j++) {
        final jdx = indices[j];
        final dx = (distancesFromGoal[idx] - distancesFromGoal[jdx]).abs();
        if (dx < collisionThresholdMeters) {
          final gap = resolved[idx] - resolved[jdx];
          if (gap < minLaneGap) {
            resolved[idx] = resolved[jdx] + minLaneGap;
          }
        }
      }
    }
    return resolved;
  }

  /// "(3,5)-7-12" 形式の隊列文字列を [['3','5'], ['7'], ['12']] に変換する。
  /// 「-」区切りの各トークンが1グループ（前後関係）、トークン内の「()」が
  /// 並走する馬（横方向のみの関係）を表す。
  static List<List<String>> _parseTairetsuGroups(String? tairetsu) {
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
        ownerName: h.ownerName,
        ownerId: h.ownerId,
        ownerImageLocalPath: h.ownerImageLocalPath,
        breederName: h.breederName,
        fatherName: h.fatherName,
        motherName: h.motherName,
        mfName: h.mfName,
        jockeyComboStats: h.jockeyComboStats,
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