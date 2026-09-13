// lib/widgets/ticket/parts/nagashi_connector_painter.dart

import 'package:flutter/material.dart';

class NagashiConnectorPainter extends CustomPainter {
  final GlobalKey canvasKey;
  final List<GlobalKey> axisKeys;
  final List<GlobalKey> opponentRowKeys;
  final Paint linePaint;

  NagashiConnectorPainter({
    required this.canvasKey,
    required this.axisKeys,
    required this.opponentRowKeys,
  }) : linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 3.0 // 太さを調整
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasBox = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;

    final axisBoxes = axisKeys.map((key) => key.currentContext?.findRenderObject() as RenderBox?).toList();
    final opponentRowBoxes = opponentRowKeys.map((key) => key.currentContext?.findRenderObject() as RenderBox?).toList();

    if (axisBoxes.isEmpty || opponentRowBoxes.isEmpty || axisBoxes.contains(null) || opponentRowBoxes.contains(null)) {
      return;
    }

    final axisPoints = axisBoxes
        .map((box) {
      final position = box!.localToGlobal(Offset.zero);
      final localPosition = canvasBox.globalToLocal(position);
      return Offset(localPosition.dx + box.size.width, localPosition.dy + box.size.height / 2);
    })
        .where((p) => p.isFinite)
        .toList();

    final opponentPoints = opponentRowBoxes
        .map((box) {
      final position = box!.localToGlobal(Offset.zero);
      final localPosition = canvasBox.globalToLocal(position);
      return Offset(localPosition.dx, localPosition.dy + box.size.height / 2);
    })
        .where((p) => p.isFinite)
        .toList();

    if (axisPoints.isEmpty || opponentPoints.isEmpty) return;

    final path = Path();
    final double spineX = axisPoints.first.dx + 8; // 縦線のX座標
    final double verticalPadding = 1.5; // 上下に延長する長さ（お好みで調整してください）

    // 縦線（背骨）のY座標の範囲を、相手リストを基準に決定
    final double spineTopY = opponentPoints.first.dy;
    final double spineBottomY = opponentPoints.last.dy;

    // 1. 縦線（背骨）を、上下に少し延長して描画
    path.moveTo(spineX, spineTopY - verticalPadding);
    path.lineTo(spineX, spineBottomY + verticalPadding);

    // 2. 軸馬から背骨への水平線を描画
    // これが┏の左から伸びる横線になります
    if (axisPoints.isNotEmpty) {
      path.moveTo(axisPoints.first.dx, axisPoints.first.dy);
      path.lineTo(spineX, axisPoints.first.dy);
    }

    // 3. 背骨から各相手馬の行への水平線を描画
    // このループが┏の上辺、┗の下辺、および中間の横線を描画します
    for (final point in opponentPoints) {
      path.moveTo(spineX, point.dy);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant NagashiConnectorPainter oldDelegate) => true;
}
