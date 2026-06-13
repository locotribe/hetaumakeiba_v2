// lib/widgets/shutuba_tabs/race_simulation_camera_painter.dart
// [追加] 展開予想アニメーション デュアルビュー: メインカメラビュー描画 (v.1.0)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_camera_transform.dart';

/// 進行方向を画面上で固定した固定スケールのカメラ視点で、コース帯
/// (本線+シュート+インフィールド)と検証用の1周トレースを描画する
/// （メインカメラビュー用）。
///
/// カメラの基準点(画面中央・上端から10%の位置に固定)は、ミニマップの
/// 光るドット([RaceSimulationMinimapPainter])と同一の先頭馬
/// (distanceFromGoal最小)のdistanceFromGoalを使う。位置(refPos)は
/// `basePosition`(生のedgePoints補間値)ではなく
/// [CourseEdgeCoordsData.smoothedPositionForRaceDistance]で位置のジグザグ
/// ノイズを平滑化した座標を使う。これにより、メインカメラビューとミニマップは
/// 常にほぼ同じコース上の地点を指しつつ、画面全体の水平方向の微振動を抑える。
/// スケール・アンカー位置自体はコース座標(`coords`)のみで決まる固定値で、
/// 馬群の配置(bounding box)には依存しないためジッターは発生しない。
/// 馬番号マーカーは[showHorseMarkers]がtrueの場合のみ、各馬の
/// [RaceSimHorseTrack.frameAt]（RaceSimulationEngineの計算結果）から
/// 取得した絶対座標を変換して独立レイヤーとして描画する。
class RaceSimulationCameraPainter extends CustomPainter {
  final CourseEdgeCoordsData coords;
  final double raceDistance;
  final CourseApproach? approach;
  final RaceSimulationData simulationData;
  final double currentTime;
  final bool isLeftHanded;
  final String trackTypeKey;
  final Path trackPath;
  final Path infieldPath;

  /// 馬番号マーカーの描画切替(デフォルトOFF)。
  /// コース描画の検証中は馬群データに依存しない独立レイヤーとして無効化し、
  /// コース1周分の一筆書きオーバーレイ([buildInfieldPath]の枠線)の
  /// 検証を優先する。
  final bool showHorseMarkers;

  const RaceSimulationCameraPainter({
    required this.coords,
    required this.raceDistance,
    required this.approach,
    required this.simulationData,
    required this.currentTime,
    required this.isLeftHanded,
    required this.trackTypeKey,
    required this.trackPath,
    required this.infieldPath,
    this.showHorseMarkers = false,
  });

  static const double _markerRadius = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (simulationData.horseTracks.isEmpty) return;

    final trackColor = trackTypeKey == 'dirt'
        ? const Color(0xFFC8A165)
        : const Color(0xFF7CB342);

    // ミニマップの光るドット([RaceSimulationMinimapPainter])と同一の
    // 先頭馬(distanceFromGoal最小)を求め、distanceFromGoalをカメラの基準点
    // として使う(=メインカメラとミニマップが常に同じ地点を指す)。
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
    var leader = frames.first;
    for (final f in frames) {
      if (f.distanceFromGoal < leader.distanceFromGoal) leader = f;
    }

    // refPosは、basePosition(生のedgePoints補間値)ではなく、位置のジグザグ
    // ノイズを平滑化した座標を使う(ミニマップ側のleader.basePositionは
    // そのまま=従来通り)。これにより画面全体の水平方向の微振動を抑える。
    final refPos = coords.smoothedPositionForRaceDistance(
      leader.distanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
    );

    final transform = RaceSimulationCameraTransform.compute(
      refPos: refPos,
      refDistanceFromGoal: leader.distanceFromGoal,
      viewportSize: size,
      isLeftHanded: isLeftHanded,
      coords: coords,
      raceDistance: raceDistance,
      approach: approach,
    );

    canvas.save();
    canvas.transform(transform.matrix.storage);

    // (a) 走路本体: 本線+シュートを含むtrackPathを、現実の80m幅相当の
    //     極太Strokeで描画する(外側の馬が黒空間に落ちない)。
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 80.0 * coords.pixelsPerMeter
        ..strokeCap = StrokeCap.butt,
    );

    // (b) インフィールド(内ラチの内側)を黒でFillマスクする。
    canvas.drawPath(
      infieldPath,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.fill,
    );

    // (c) スタートライン(赤線): スタート地点から+normal方向(走路外側)へ
    //     40m相当の直線を描画する。
    final startPos = coords.positionForRaceDistance(
      raceDistance,
      raceDistance: raceDistance,
      approach: approach,
    );
    final startTangent = coords.tangentAt(
      raceDistance,
      raceDistance: raceDistance,
      approach: approach,
    );
    final startNormal = Offset(-startTangent.dy, startTangent.dx);
    canvas.drawLine(
      startPos,
      startPos + startNormal * (40.0 * coords.pixelsPerMeter),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2.0,
    );

    // (d) 検証用: コース1周分の一筆書き(edgePoints)の枠線を重ねて描画する。
    //     画面上端から10%(=5m)の位置に内ラチ(edgePoints)が固定されるはずなので、
    //     この線が常にその位置・角度で滑らかに移動するかを確認する。
    final overlayScale =
        RaceSimulationCameraTransform.scaleFor(viewportSize: size, coords: coords);
    canvas.drawPath(
      infieldPath,
      Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / overlayScale,
    );

    canvas.restore();

    // (e) 馬群アイコン: showHorseMarkersがtrueの場合のみ、独立レイヤーとして
    //     スクリーン座標に変換してから一定サイズで描画する。
    if (showHorseMarkers) {
      for (final frame in frames) {
        final pos = transform.apply(frame.rawPosition);
        _drawHorseMarker(canvas, pos, frame);
      }
    }
  }

  /// edgePoints(本線の内ラチ)が囲む閉ループ(インフィールド領域)のPathを
  /// 構築する。`coords`はアニメーション中不変のため、呼び出し元
  /// (_RaceSimulationViewState)で1度だけ構築してキャッシュすることを
  /// 想定した静的メソッド。
  static Path buildInfieldPath({required CourseEdgeCoordsData coords}) {
    final path = Path();
    final pts = coords.edgePoints;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  /// edgePoints(本線の内ラチ)が囲む閉ループに、引き込み線(シュート)区間
  /// （合流点→スタート地点の線分。approachがnullの場合は無し）を加えた
  /// Pathを構築する。Stroke描画用（複数サブパスを保持可能）。
  static Path buildTrackPath({
    required CourseEdgeCoordsData coords,
    required double raceDistance,
    CourseApproach? approach,
  }) {
    final path = Path()..addPath(buildInfieldPath(coords: coords), Offset.zero);

    if (approach != null) {
      final mergeDist = raceDistance - approach.distance;
      final mergePt = coords.positionForRaceDistance(
        mergeDist,
        raceDistance: raceDistance,
        approach: approach,
      );
      final startPt = coords.positionForRaceDistance(
        raceDistance,
        raceDistance: raceDistance,
        approach: approach,
      );
      path.moveTo(mergePt.dx, mergePt.dy);
      path.lineTo(startPt.dx, startPt.dy);
    }
    return path;
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
  bool shouldRepaint(covariant RaceSimulationCameraPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.simulationData != simulationData ||
        oldDelegate.raceDistance != raceDistance ||
        oldDelegate.approach != approach ||
        oldDelegate.isLeftHanded != isLeftHanded ||
        oldDelegate.trackTypeKey != trackTypeKey ||
        oldDelegate.showHorseMarkers != showHorseMarkers;
  }
}
