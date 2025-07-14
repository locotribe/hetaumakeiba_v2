// lib/widgets/custom_background.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui; // CustomPainterでRect.fromLTWHを正確に使うために必要

class CustomBackground extends StatelessWidget {
  final Color stripeColor;
  final Color fillColor;
  final Color? overallBackgroundColor; // Scaffoldの背景色もここで指定できるようにオプションで追加

  const CustomBackground({
    super.key,
    required this.stripeColor,
    required this.fillColor,
    this.overallBackgroundColor, // オプション
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: overallBackgroundColor, // Scaffoldの背景色をここで適用
      child: CustomPaint(
        painter: _BackgroundPainter(
          stripeColor: stripeColor,
          fillColor: fillColor,
        ),
        child: Container(), // CustomPaintが子を持たない場合、Container()を置くのが一般的
      ),
    );
  }
}

// BackgroundPainterクラスをプライベートクラスとしてCustomBackground内に含める
class _BackgroundPainter extends CustomPainter {
  final Color stripeColor;
  final Color fillColor;

  _BackgroundPainter({required this.stripeColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 縦ストライプの描画
    final stripePaint = Paint()..color = stripeColor;
    const double stripeWidth = 2.0; // ストライプの幅
    const double stripeSpacing = 10.0; // ストライプの間隔 (stripeWidth + space)

    for (double x = 0; x < size.width; x += stripeSpacing) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeWidth, size.height), stripePaint);
    }

    // 左から20%〜30%の領域を塗る
    final fillPaint = Paint()..color = fillColor;
    final double startX = size.width * 0.20;
    final double endX = size.width * 0.30;
    canvas.drawRect(Rect.fromLTWH(startX, 0, endX - startX, size.height), fillPaint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor || oldDelegate.fillColor != fillColor;
  }
}