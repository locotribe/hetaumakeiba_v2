// lib/widgets/shutuba_tabs/course_diagram_painter.dart
// [追加] コース平面図統合表示機能の描画ロジック (v.1.0)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
// [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// 背景のコース平面図画像の上に、レース距離に応じた走行軌跡をオーバーレイ描画する
class CourseDiagramPainter extends CustomPainter {
  final CourseDiagramData diagram;
  final int raceDistance;
  // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
  final List<CourseApproach>? approachPaths;

  CourseDiagramPainter({
    required this.diagram,
    required this.raceDistance,
    this.approachPaths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transform = ImageTransform.compute(size, diagram.imageInfo);
    final coords = diagram.coords;

    // 1. 本線全体のアウトライン（淡色・参考表示）
    canvas.drawPath(
      _buildPath(coords.edgePoints, transform, closed: true),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 2. レース距離に応じた走行区間（シュート区間＋本線合流区間）の算出
    final approachPath = coords.approachPathFor(raceDistance);
    final List<Offset> racePoints = [];
    final Offset startRawPos;

    if (approachPaths != null && approachPaths!.isNotEmpty) {
      // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
      // 各競馬場のRaceCourseData.approachPathに定義された
      // 「合流点からスタート地点へ向かう相対ベクトル(角度・距離)」の連結
      // ポリラインを、approachVertices()経由で三角関数により生ピクセル座標に
      // 変換し、シュート区間のPathを生成する（複数セグメント=カーブ対応）
      final approach = approachPaths!;
      final vertices = coords.approachVertices(
        raceDistance: raceDistance.toDouble(),
        approach: approach,
      );
      final mergeDist =
          raceDistance - approach.fold(0.0, (sum, a) => sum + a.distance);
      final rawStartPt = vertices.last;

      // mergeDistが1周分(lap)を超える場合、合流点から本線を複数周してゴールに
      // 至る。合流点の本線上の位置はlapで折り返した値(wrappedMergeDist)で求め、
      // 超過分の周回ごとに本線1周分(edgePoints全体)を追加で繋ぐ。
      final lap = coords.cumulativeDistances.last;
      final wrappedMergeDist = mergeDist % lap;
      final mergeIndex = coords.indexAtDistance(wrappedMergeDist);
      final lapCount = (mergeDist / lap).floor();

      racePoints.addAll(vertices.reversed);
      racePoints.addAll(coords.edgePoints.sublist(0, mergeIndex + 1).reversed);
      for (int i = 0; i < lapCount; i++) {
        racePoints.addAll(coords.edgePoints.reversed);
      }
      startRawPos = rawStartPt;
    } else if (approachPath != null && approachPath.isNotEmpty) {
      // シュート（引き込み線）区間あり：シュート -> 本線上の最近傍点 -> ゴール
      racePoints.addAll(approachPath);
      final joinIndex = coords.nearestEdgeIndex(approachPath.last);
      racePoints.addAll(coords.edgePoints.sublist(0, joinIndex + 1).reversed);
      startRawPos = approachPath.first;
    } else {
      // シュート区間なし：本線上のスタート位置 -> ゴール
      // raceDistanceがbaseLapDistance(1周分)を超える場合、超過分の周回ごとに
      // 本線1周分(edgePoints全体)を追加で繋ぎ、実際に走行する距離分を
      // すべてハイライトする。
      final lap = coords.baseLapDistance;
      final startDist = raceDistance.toDouble() % lap;
      final startIndex = coords.indexAtDistance(startDist);
      final lapCount = (raceDistance / lap).floor();

      racePoints.addAll(coords.edgePoints.sublist(0, startIndex + 1).reversed);
      for (int i = 0; i < lapCount; i++) {
        racePoints.addAll(coords.edgePoints.reversed);
      }
      startRawPos = coords.positionAtDistance(startDist);
    }

    // 3. 走行区間のハイライト描画
    canvas.drawPath(
      _buildPath(racePoints, transform, closed: false),
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 4. スタート/ゴールのマーカー
    final goalPos = transform.apply(coords.edgePoints.first);
    final startPos = transform.apply(startRawPos);
    _drawMarker(canvas, goalPos, Colors.redAccent, 'G');
    _drawMarker(canvas, startPos, Colors.lightBlueAccent, 'S');
  }

  /// edgePoints/approachPathsの生ピクセル座標列を、曲線補間なしで直線連結したPathを生成する
  Path _buildPath(List<Offset> rawPoints, ImageTransform transform,
      {required bool closed}) {
    final path = Path();
    for (int i = 0; i < rawPoints.length; i++) {
      final p = transform.apply(rawPoints[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (closed) path.close();
    return path;
  }

  void _drawMarker(Canvas canvas, Offset pos, Color color, String label) {
    canvas.drawCircle(pos, 6, Paint()..color = color);
    canvas.drawCircle(
      pos,
      6,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black,
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
  bool shouldRepaint(covariant CourseDiagramPainter oldDelegate) {
    return oldDelegate.diagram != diagram ||
        oldDelegate.raceDistance != raceDistance ||
        oldDelegate.approachPaths != approachPaths; // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
  }
}
