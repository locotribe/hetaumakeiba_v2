// lib/widgets/shutuba_tabs/race_simulation_layer2_painter.dart

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

/// 展開シミュレーション Layer2 オーバーレイ。
///
/// Layer1（[RaceSimulationCameraPainter]）のカメラ変換行列を使わず、
/// 「進行距離（distanceFromGoal）× 横位置（laneRank）」の正規化座標系で
/// 馬番マーカーを描画する。シュート区間でもコース角度に引きずられない。
///
/// X座標: 設計書の統一式 — 先頭馬を進行方向の端から10%に固定し、
///        馬群の縦の広がりに応じて中央寄せ→先頭固定を自動切替。
/// Y座標: エンジン算出済みlaneRankから直接マッピングし、コーナー遠心力・
///        最終直線のfinishingPower広がりを加算オフセットとして重ねる。
class RaceSimulationLayer2Painter extends CustomPainter {
  final CourseEdgeCoordsData coords;
  final double raceDistance;
  final List<CourseApproach>? approach;
  final RaceSimulationData simulationData;
  final double currentTime;
  final bool isLeftHanded;
  final Map<String, HorseSimulationParams> simulationParams;
  // [追加] 候補A: コーナー遠心力・最終直線広がりに使用 (v2026.6.25)
  final RaceCourseData? raceCourse;

  static const double _markerRadius = 9.0;
  // Layer1の_railOffsetRatioと同一値でinnerRailYを揃える
  static const double _railOffsetRatio = 0.1;
  // laneRank 1単位あたりの画面Y間隔(px)。馬群の縦の広がりを制御する
  static const double _laneSpacingY = 13.0;
  // [追加] 候補A: 4コーナー入口→ゴールの一体化展開係数。finishingPower×外側度合いで広がり量が決まる (v2026.6.25)
  static const double _finalSpreadFactor = 0.20;

  const RaceSimulationLayer2Painter({
    required this.coords,
    required this.raceDistance,
    required this.approach,
    required this.simulationData,
    required this.currentTime,
    required this.isLeftHanded,
    this.simulationParams = const {},
    this.raceCourse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (simulationData.horseTracks.isEmpty) return;

    // 全馬のフレームを取得（distanceFromGoal と laneRank を使用）
    final frames = simulationData.horseTracks
        .map((t) => t.frameAt(
              currentTime,
              coords,
              raceDistance,
              approach,
              RaceSimulationEngine.laneSpacingPx,
              RaceSimulationEngine.innerMarginPx,
            ))
        .toList();

    // ── X座標計算 (設計書の統一式) ──
    // Layer1と共通のscaleを使用: viewportHeight = 50m相当
    final scaleMeters = size.height / 50.0; // screen-px / m

    // 右回り: 先頭馬→画面左 / 左回り: 先頭馬→画面右
    final dirSign = isLeftHanded ? -1.0 : 1.0;

    double leadDist = frames.first.distanceFromGoal;
    double lastDist = frames.first.distanceFromGoal;
    for (final f in frames) {
      if (f.distanceFromGoal < leadDist) leadDist = f.distanceFromGoal;
      if (f.distanceFromGoal > lastDist) lastDist = f.distanceFromGoal;
    }

    final spread = lastDist - leadDist;
    final viewportWidthMeters = size.width / scaleMeters;
    // spread≤0.8×viewportWidth: 中央モード / 超過: 先頭10%固定に自動移行
    final anchorDist = leadDist + min(spread, viewportWidthMeters * 0.8) / 2;

    // ── Y座標計算 (laneRank直接マッピング・MVPバージョン) ──
    final innerRailY = size.height * _railOffsetRatio;

    // このフレームの全馬の最小・最大laneRankを取得
    double minLaneRank = frames.first.laneRank;
    double maxLaneRank = frames.first.laneRank;
    for (final f in frames) {
      if (f.laneRank < minLaneRank) minLaneRank = f.laneRank;
      if (f.laneRank > maxLaneRank) maxLaneRank = f.laneRank;
    }

    // [修正] 馬数が多くカメラ高さを超える場合、間隔を圧縮して全馬を収める (v.13.43.0)
    // 先頭馬(minLaneRank)を上端、最後尾(maxLaneRank)を下端に固定し均等分布
    final double topY = innerRailY + _markerRadius + 2.0;
    final double bottomY = size.height - _markerRadius - 2.0;
    final double availableHeight = bottomY - topY;
    final double laneRankRange = maxLaneRank - minLaneRank;
    final double effectiveSpacingY =
        (laneRankRange > 0 && laneRankRange * _laneSpacingY > availableHeight)
            ? availableHeight / laneRankRange
            : _laneSpacingY;

    // 全馬のscreenXを先行計算
    final screenXByHorse = <String, double>{};
    for (final f in frames) {
      screenXByHorse[f.horseNumber] = size.width / 2 +
          dirSign * (f.distanceFromGoal - anchorDist) * scaleMeters;
    }

    if (spread < 2.0) {
      // スタートゲート: effectiveSpacingYで全馬を均等配置。
      // 頭数が多い場合はマーカーが重なってもよい（修正前の動作を維持）。
      final sorted = List<RaceSimFrame>.from(frames)
        ..sort((a, b) => b.laneRank.compareTo(a.laneRank));
      for (final frame in sorted) {
        final screenY =
            topY + (frame.laneRank - minLaneRank) * effectiveSpacingY;
        _drawHorseMarker(
            canvas, Offset(screenXByHorse[frame.horseNumber]!, screenY), frame);
      }
      return;
    }

    // エンジン側でビルド時に衝突解決済みのlaneRankをY座標に直接マッピング。
    // 外側(laneRank大)から描画して内側の馬が前面になる。
    final sortedForDraw = List<RaceSimFrame>.from(frames)
      ..sort((a, b) => b.laneRank.compareTo(a.laneRank));

    // [追加] 候補A: 4コーナー入口→ゴールの一体化スムーズ展開 (v2026.6.25)
    final corner4StartDfg = raceCourse != null
        ? _corner4StartDfg(raceCourse!.sections, raceDistance)
        : null;

    for (final frame in sortedForDraw) {
      final screenX = screenXByHorse[frame.horseNumber]!;
      final laneFromInner = frame.laneRank - minLaneRank;

      // 4コーナー入口→ゴールを一体のプログレスで外側に広げる。
      // 遠心力で徐々に外に振られ、直線でも広がり続ける自然な流れを実現する。
      double spreadOffset = 0.0;
      if (corner4StartDfg != null &&
          corner4StartDfg > 0 &&
          frame.distanceFromGoal <= corner4StartDfg) {
        final fp = simulationParams[frame.horseNumber]?.finishingPower ?? 0.5;
        final progress =
            (1.0 - frame.distanceFromGoal / corner4StartDfg).clamp(0.0, 1.0);
        spreadOffset = laneFromInner * fp * progress * _finalSpreadFactor;
      }

      final screenY =
          (topY + (laneFromInner + spreadOffset) * effectiveSpacingY)
              .clamp(topY, bottomY);
      _drawHorseMarker(canvas, Offset(screenX, screenY), frame);
    }
  }

  // [追加] 候補A: 最後のcorner_4入口のdistanceFromGoalを返す (v2026.6.25)
  static double? _corner4StartDfg(
      List<CourseSection> sections, double raceDistance) {
    double? lastCorner4Start;
    for (final sec in sections) {
      if (sec.name == 'corner_4') lastCorner4Start = sec.startDistance;
    }
    if (lastCorner4Start == null) return null;
    return raceDistance - lastCorner4Start;
  }

  void _drawHorseMarker(Canvas canvas, Offset pos, RaceSimFrame frame) {
    final bgColor = frame.gateNumber.gateBackgroundColor;
    final textColor = frame.gateNumber.gateTextColor;

    canvas.drawCircle(pos, _markerRadius, Paint()..color = bgColor);
    canvas.drawCircle(
      pos,
      _markerRadius,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: frame.horseNumber,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      pos - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant RaceSimulationLayer2Painter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.simulationData != simulationData ||
        oldDelegate.raceDistance != raceDistance ||
        oldDelegate.approach != approach ||
        oldDelegate.isLeftHanded != isLeftHanded ||
        oldDelegate.raceCourse != raceCourse;
  }
}
