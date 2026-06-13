// lib/widgets/shutuba_tabs/race_simulation_painter.dart
// [改修] 展開予想アニメーション デュアルビュー: 全体俯瞰マップ(光るドット)描画 (v.2.0)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';

/// コース平面図上に、currentTime時点での先頭馬の現在位置を
/// 「光るドット」1つだけでオーバーレイ描画する（全体俯瞰マップ用）。
class RaceSimulationMinimapPainter extends CustomPainter {
  final CourseDiagramData diagram;
  final double raceDistance;
  final CourseApproach? approach;
  final RaceSimulationData simulationData;
  final double currentTime;

  const RaceSimulationMinimapPainter({
    required this.diagram,
    required this.raceDistance,
    required this.approach,
    required this.simulationData,
    required this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transform = ImageTransform.compute(size, diagram.imageInfo);
    final coords = diagram.coords;
    if (simulationData.horseTracks.isEmpty) return;

    RaceSimFrame? leader;
    for (final track in simulationData.horseTracks) {
      final frame = track.frameAt(
        currentTime,
        coords,
        raceDistance,
        approach,
        RaceSimulationEngine.laneSpacingPx,
        RaceSimulationEngine.innerMarginPx,
      );
      if (leader == null || frame.distanceFromGoal < leader.distanceFromGoal) {
        leader = frame;
      }
    }
    if (leader == null) return;

    final pos = transform.apply(leader.basePosition);
    _drawGlowingDot(canvas, pos);
  }

  void _drawGlowingDot(Canvas canvas, Offset center) {
    // 外側から内側へ、blurの効いた円を重ねて「光る」効果を作る
    const glowLayers = [(14.0, 0.18), (9.0, 0.35), (5.5, 0.6)];
    for (final (radius, alpha) in glowLayers) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
    }
    canvas.drawCircle(center, 3.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant RaceSimulationMinimapPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.simulationData != simulationData ||
        oldDelegate.diagram != diagram ||
        oldDelegate.raceDistance != raceDistance ||
        oldDelegate.approach != approach;
  }
}
