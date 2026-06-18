// lib/widgets/shutuba_tabs/race_simulation_layer2_painter.dart
// [追加] 展開シミュ Layer2: コース座標に依存しない進行距離×横位置座標系で馬番マーカーを描画 (v.13.43.0)

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
/// Y座標(MVP): laneRank（エンジン算出済み）から内ラチ基準の画面Y座標へ直接マッピング。
///             将来フェーズで speed-based drift + 当たり判定に置換予定。
class RaceSimulationLayer2Painter extends CustomPainter {
  final CourseEdgeCoordsData coords;
  final double raceDistance;
  final List<CourseApproach>? approach;
  final RaceSimulationData simulationData;
  final double currentTime;
  final bool isLeftHanded;
  // [追加] 将来のdrift補正・処理順序に使用。MVP段階では保持のみ (v.13.43.0)
  final Map<String, HorseSimulationParams> simulationParams;

  static const double _markerRadius = 9.0;
  // Layer1の_railOffsetRatioと同一値でinnerRailYを揃える
  static const double _railOffsetRatio = 0.1;
  // laneRank 1単位あたりの画面Y間隔(px)。馬群の縦の広がりを制御する
  static const double _laneSpacingY = 13.0;

  const RaceSimulationLayer2Painter({
    required this.coords,
    required this.raceDistance,
    required this.approach,
    required this.simulationData,
    required this.currentTime,
    required this.isLeftHanded,
    this.simulationParams = const {},
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

    // [修正] レース中: エンジン側でビルド時に衝突解決済みのlaneRankをY座標に直接マッピング (v.2026.6.19)
    // リアルタイム当たり判定を廃止し、Y軸の急激なジャンプを根本的に排除する。
    // 外側(laneRank大)から描画して内側の馬が前面になる。
    final sortedForDraw = List<RaceSimFrame>.from(frames)
      ..sort((a, b) => b.laneRank.compareTo(a.laneRank));

    for (final frame in sortedForDraw) {
      final screenX = screenXByHorse[frame.horseNumber]!;
      final screenY =
          (topY + (frame.laneRank - minLaneRank) * effectiveSpacingY)
              .clamp(topY, bottomY);
      _drawHorseMarker(canvas, Offset(screenX, screenY), frame);
    }
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
        oldDelegate.isLeftHanded != isLeftHanded;
  }
}
