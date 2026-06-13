// lib/widgets/shutuba_tabs/race_simulation_elevation_painter.dart
// [追加] 展開予想アニメーション: 高低差グラフ＋現在位置インジケーター描画 (v.1.0)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/elevation_logic.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// 高低差グラフ（[ElevationLogic.generateRaceChartData]で生成した
/// [ChartDrawData]）を軽量な[CustomPainter]として描画し、現在位置に
/// 光る点を重ねて表示する。
///
/// チャートのX軸は「スタートからの距離」(0=スタート, raceDistance=ゴール)で
/// あり、シミュレーションの`distanceFromGoal`(0=ゴール)とは逆向きのため、
/// `chartX = raceDistance - currentDistanceFromGoal`で変換する。
/// [currentDistanceFromGoal]はミニマップ([RaceSimulationMinimapPainter])・
/// メインカメラ([RaceSimulationCameraPainter])と同一の先頭馬
/// (distanceFromGoal最小)の値を渡すこと。これにより3表示は常に同じ
/// コース上の地点を指す。
class RaceSimulationElevationPainter extends CustomPainter {
  final ChartDrawData drawData;
  final List<CourseSection> sections;
  final double raceDistance;
  final double currentDistanceFromGoal;

  const RaceSimulationElevationPainter({
    required this.drawData,
    required this.sections,
    required this.raceDistance,
    required this.currentDistanceFromGoal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spots = drawData.spots;
    if (spots.isEmpty || size.width <= 0 || size.height <= 0) return;

    final maxX = drawData.maxX;

    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    minY -= 1.0;
    maxY += 1.5;
    final rangeY = (maxY - minY).abs() < 1e-9 ? 1.0 : (maxY - minY);

    Offset toCanvas(double x, double y) {
      final cx = (x / maxX) * size.width;
      final cy = size.height - ((y - minY) / rangeY) * size.height;
      return Offset(cx, cy);
    }

    final rect = Offset.zero & size;

    // (a) セクションの帯(交互の薄い背景)・境界の破線
    const stripeColors = [Color(0x03000000), Color(0x08000000)];
    for (int i = 0; i < sections.length; i++) {
      final sec = sections[i];
      final x1 = toCanvas(sec.startDistance, 0).dx;
      final x2 = toCanvas(sec.endDistance, 0).dx;
      canvas.drawRect(
        Rect.fromLTRB(x1, 0, x2, size.height),
        Paint()..color = stripeColors[i % stripeColors.length],
      );
      if (i > 0) {
        _drawDashedVerticalLine(canvas, x1, size.height, Colors.black12);
      }
    }

    // (b) エリア(高低差グラデーション塗り)
    final areaPath = Path()
      ..moveTo(toCanvas(spots.first.x, minY).dx, toCanvas(spots.first.x, minY).dy);
    for (final s in spots) {
      final p = toCanvas(s.x, s.y);
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath
      ..lineTo(toCanvas(spots.last.x, minY).dx, toCanvas(spots.last.x, minY).dy)
      ..close();
    canvas.drawPath(areaPath, Paint()..shader = drawData.areaGradient.createShader(rect));

    // (c) 高低差曲線
    final linePath = Path();
    for (int i = 0; i < spots.length; i++) {
      final p = toCanvas(spots[i].x, spots[i].y);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..shader = drawData.lineGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // (d) スタート線(青)・ゴール線(赤)
    final startX = toCanvas(0, 0).dx;
    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, size.height),
      Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );
    final goalX = toCanvas(maxX, 0).dx;
    canvas.drawLine(
      Offset(goalX, 0),
      Offset(goalX, size.height),
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );

    // (e) 現在位置: 光る点(ミニマップと同じ表現)
    double chartX = raceDistance - currentDistanceFromGoal;
    if (chartX < 0) chartX = 0;
    if (chartX > maxX) chartX = maxX;
    final currentElevation = _elevationAt(spots, chartX);
    final pos = toCanvas(chartX, currentElevation);
    _drawGlowingDot(canvas, pos);
  }

  /// spotsは0..raceDistanceまで1m刻み(+末尾にゴール重複点)のため、
  /// xの前後の整数インデックス間を線形補間して標高を求める。
  double _elevationAt(List<FlSpot> spots, double x) {
    if (x <= spots.first.x) return spots.first.y;
    if (x >= spots.last.x) return spots.last.y;
    final i = x.floor();
    if (i + 1 >= spots.length) return spots.last.y;
    final p1 = spots[i];
    final p2 = spots[i + 1];
    if (p2.x == p1.x) return p1.y;
    final ratio = (x - p1.x) / (p2.x - p1.x);
    return p1.y + (p2.y - p1.y) * ratio;
  }

  void _drawDashedVerticalLine(Canvas canvas, double x, double height, Color color) {
    const dashLength = 4.0;
    const gapLength = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    double y = 0;
    while (y < height) {
      final yEnd = (y + dashLength) < height ? y + dashLength : height;
      canvas.drawLine(Offset(x, y), Offset(x, yEnd), paint);
      y += dashLength + gapLength;
    }
  }

  void _drawGlowingDot(Canvas canvas, Offset center) {
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
  bool shouldRepaint(covariant RaceSimulationElevationPainter oldDelegate) {
    return oldDelegate.currentDistanceFromGoal != currentDistanceFromGoal ||
        oldDelegate.drawData != drawData ||
        oldDelegate.raceDistance != raceDistance ||
        oldDelegate.sections != sections;
  }
}