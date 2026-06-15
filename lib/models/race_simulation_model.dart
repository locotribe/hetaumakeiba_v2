// lib/models/race_simulation_model.dart
// [追加] 展開予想アニメーション機能(MVP)のデータモデル (v.1.0)

import 'dart:ui';

import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// 各馬の、ある時点(time)における状態のスナップショット。
/// distanceFromGoalは「ゴールからの絶対残距離」(発走=raceDistance, ゴール=0が
/// 基準だが、隊列の「-」区切りグループごとの縦方向オフセットが加算される)で
/// 保持する。modulo計算や引き込み線(シュート)判定は描画直前の
/// CourseEdgeCoordsData.positionForRaceDistance()内でのみ行う。
/// laneRankは隊列の「()」グループ内で中心化済みの横方向ランク
/// (例: 2頭組なら-0.5/+0.5)であり、frameAt()では
/// `laneRank * laneSpacingPx`がそのまま横方向オフセット(px)になる。
class RaceSimSnapshot {
  final double time;
  final double distanceFromGoal;
  final double laneRank;

  const RaceSimSnapshot({
    required this.time,
    required this.distanceFromGoal,
    required this.laneRank,
  });
}

/// 1頭分の、ある時点(currentTime)における絶対座標スナップショット。
/// rawPositionは生ピクセル座標（レーン分散オフセット適用後）、basePositionは
/// レーン分散オフセット適用前のコース中心線上の点、distanceFromGoalは
/// 「ゴールからの絶対残距離」。これらの値はRaceSimulationEngineが計算した
/// 絶対座標系の値そのものであり、描画レイヤーの回転・ズーム変換が適用される前の値。
class RaceSimFrame {
  final String horseNumber;
  final int gateNumber;
  final Offset rawPosition;
  final Offset basePosition;
  final double distanceFromGoal;

  const RaceSimFrame({
    required this.horseNumber,
    required this.gateNumber,
    required this.rawPosition,
    required this.basePosition,
    required this.distanceFromGoal,
  });
}

/// 1頭分の、5キーフレーム分のSnapshot配列を保持するトラック情報。
class RaceSimHorseTrack {
  final String horseNumber;
  final int gateNumber;

  /// time昇順、必ず5要素（発走/1-2コーナー/3コーナー/4コーナー/ゴール）
  final List<RaceSimSnapshot> snapshots;

  const RaceSimHorseTrack({
    required this.horseNumber,
    required this.gateNumber,
    required this.snapshots,
  });

  /// currentTimeをsnapshots間で線形補間し、(distanceFromGoal, laneRank)を求めて
  /// コース平面図上の生ピクセル座標(絶対座標)とdistanceFromGoalを返す。
  RaceSimFrame frameAt(
    double currentTime,
    CourseEdgeCoordsData coords,
    double raceDistance,
    List<CourseApproach>? approach,
    double laneSpacingPx,
    double innerMarginPx,
  ) {
    final t = currentTime.clamp(snapshots.first.time, snapshots.last.time);

    int i = 0;
    while (i < snapshots.length - 2 && snapshots[i + 1].time <= t) {
      i++;
    }
    final a = snapshots[i];
    final b = snapshots[i + 1];
    final ratio = (b.time == a.time) ? 0.0 : (t - a.time) / (b.time - a.time);

    final distanceFromGoal =
        a.distanceFromGoal + (b.distanceFromGoal - a.distanceFromGoal) * ratio;
    final laneRank = a.laneRank + (b.laneRank - a.laneRank) * ratio;

    final basePos = coords.positionForRaceDistance(
      distanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
    );
    final tangent = coords.tangentAt(
      distanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
    );
    final normal = Offset(-tangent.dy, tangent.dx);
    final lateralOffset = laneRank * laneSpacingPx + innerMarginPx;

    return RaceSimFrame(
      horseNumber: horseNumber,
      gateNumber: gateNumber,
      rawPosition: basePos + normal * lateralOffset,
      basePosition: basePos,
      distanceFromGoal: distanceFromGoal,
    );
  }
}

/// 展開予想アニメーション全体のデータ。
class RaceSimulationData {
  final List<RaceSimHorseTrack> horseTracks;

  /// 1-2コーナー/3コーナー/4コーナーの隊列文字列（UI表示用）
  final Map<String, String> developmentTexts;

  /// アニメーション全体の長さ(秒) = 全馬共通のsnapshots.last.time
  final double totalTime;

  const RaceSimulationData({
    required this.horseTracks,
    required this.developmentTexts,
    required this.totalTime,
  });
}
