// lib/widgets/horse_detail/growth_curve_painter.dart

// [追加] 馬体重成長曲線 Step2: 成長曲線の描画（馬体重の折れ線＋450kgの水準線＋人気・着順の棒＋日付の目盛り）。
// 棒をレースの実際の日付の位置に立て、その上に折れ線を重ねるため、fl_chart ではなく CustomPainter で描く。
// レース名はグラフに描かない（点をタップすると下に表示される） (v.2026.10.1+26100102)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';

/// 成長曲線の座標計算（描画とタップ判定で共用する）
class GrowthCurveLayout {
  /// 左の体重目盛りの幅
  static const double leftAxisWidth = 34;
  static const double rightPadding = 10;
  static const double topPadding = 10;

  /// 折れ線と棒を描く領域の高さ
  static const double plotHeight = 200;

  /// 日付の目盛りの高さ
  static const double dateAxisHeight = 16;

  /// 点が枠の左右端で切れないための内側の余白
  static const double innerPadding = 12;

  /// 人気・着順の棒が使う高さの割合（描画領域の下から）
  static const double barZoneRatio = 0.5;

  /// 頭数が分からないときに使う頭数
  static const int defaultFieldSize = 18;

  static const double totalHeight = topPadding + plotHeight + dateAxisHeight;

  final Size size;
  final List<GrowthPoint> points;
  final GrowthWeightWindow window;
  late final Rect plot;
  late final DateTime start;
  late final DateTime end;

  GrowthCurveLayout({
    required this.size,
    required this.points,
    required this.window,
  }) {
    plot = Rect.fromLTWH(
      leftAxisWidth,
      topPadding,
      math.max(0.0, size.width - leftAxisWidth - rightPadding),
      plotHeight,
    );
    if (points.isEmpty) {
      start = DateTime(2000, 1, 1);
      end = DateTime(2000, 1, 2);
    } else {
      final first = points.first.date;
      final last = points.last.date;
      if (last.isAfter(first)) {
        start = first;
        end = last;
      } else {
        // 1点だけ（または全部同じ日）のときは前後15日の幅を取って真ん中に置く
        start = first.subtract(const Duration(days: 15));
        end = last.add(const Duration(days: 15));
      }
    }
  }

  double xOf(DateTime date) {
    final span = end.difference(start).inHours.toDouble();
    final usable = plot.width - innerPadding * 2;
    if (span <= 0 || usable <= 0) return plot.center.dx;
    return plot.left +
        innerPadding +
        usable * (date.difference(start).inHours / span);
  }

  double yOfWeight(num kg) {
    final range = (window.max - window.min).toDouble();
    if (range <= 0) return plot.center.dy;
    return plot.bottom - plot.height * ((kg - window.min) / range);
  }

  /// 棒の領域の上端（1位の棒の頂点）
  double get barZoneTop => plot.bottom - plot.height * barZoneRatio;

  /// 順位の棒の頂点。1位が一番高く、最下位が一番低い（頭数で正規化）
  double barTopFor(int position, int? fieldSize) {
    final n = math.max(fieldSize ?? defaultFieldSize, position);
    final fraction = (n - position + 1) / n;
    return plot.bottom - (plot.bottom - barZoneTop) * fraction;
  }

  /// 隣り合う点の横の間隔の最小値（棒の幅を決める）
  double get minGap {
    if (points.length < 2) return plot.width;
    var gap = double.infinity;
    for (var i = 1; i < points.length; i++) {
      final g = xOf(points[i].date) - xOf(points[i - 1].date);
      if (g < gap) gap = g;
    }
    return gap;
  }

  /// タップ位置にいちばん近い点の番号（横方向の距離が [maxDistance] 以内のときだけ）
  int? nearestIndex(Offset position, {double maxDistance = 24}) {
    int? best;
    var bestDistance = maxDistance;
    for (var i = 0; i < points.length; i++) {
      final d = (xOf(points[i].date) - position.dx).abs();
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }
}

class GrowthCurvePainter extends CustomPainter {
  final List<GrowthPoint> points;
  final GrowthWeightWindow window;

  /// 選択中の点の番号（null なら選択なし）
  final int? selectedIndex;

  static const Color weightColor = Color(0xFF5D4037);
  static const Color referenceColor = Color(0xFF1E88E5);
  static const Color popularityColor = Color(0xFFB0BEC5);
  static const Color betterColor = Color(0xFF43A047);
  static const Color worseColor = Color(0xFFE53935);
  static const Color evenColor = Color(0xFF78909C);
  static const Color gridColor = Color(0xFFE0E0E0);
  static const Color axisTextColor = Color(0xFF757575);

  GrowthCurvePainter({
    required this.points,
    required this.window,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final layout =
        GrowthCurveLayout(size: size, points: points, window: window);
    _drawGrid(canvas, layout);
    _drawSelectedGuide(canvas, layout);
    _drawBars(canvas, layout);
    _drawReferenceLine(canvas, layout);
    _drawWeightLine(canvas, layout);
    _drawDateAxis(canvas, layout);
    canvas.restore();
  }

  TextPainter _text(String text,
      {double fontSize = 10,
      Color color = axisTextColor,
      FontWeight fontWeight = FontWeight.normal}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: fontSize, color: color, fontWeight: fontWeight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  /// 10kgごとの横線と左の目盛り（線が多いときは目盛りの文字を20kgごとにする）
  void _drawGrid(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final lineCount =
        (window.max - window.min) ~/ GrowthCurveBuilder.gridStep;
    final labelStep = lineCount > 10
        ? GrowthCurveBuilder.gridStep * 2
        : GrowthCurveBuilder.gridStep;
    for (var kg = window.min;
        kg <= window.max;
        kg += GrowthCurveBuilder.gridStep) {
      final y = layout.yOfWeight(kg);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      if ((kg - window.min) % labelStep == 0) {
        final tp = _text('$kg');
        tp.paint(canvas,
            Offset(plot.left - tp.width - 4, y - tp.height / 2));
      }
    }
    final borderPaint = Paint()
      ..color = axisTextColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(plot.left, plot.bottom),
        Offset(plot.right, plot.bottom), borderPaint);
  }

  /// 選択中の点の縦の補助線
  void _drawSelectedGuide(Canvas canvas, GrowthCurveLayout layout) {
    final index = selectedIndex;
    if (index == null || index < 0 || index >= points.length) return;
    final x = layout.xOf(points[index].date);
    final paint = Paint()
      ..color = axisTextColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, layout.plot.top),
        Offset(x, layout.plot.bottom), paint);
  }

  /// 人気（灰）と着順（緑=人気より上・赤=人気より下・青灰=同じ/比べられない）の棒。
  /// 中止・除外・取消は棒の代わりに「中」「除」「取」を描く
  void _drawBars(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    final barWidth = (layout.minGap * 0.3).clamp(1.5, 7.0).toDouble();
    for (final p in points) {
      if (p.isCurrent) continue;
      final x = layout.xOf(p.date);
      final popularity = p.popularity;
      if (popularity != null) {
        final top = layout.barTopFor(popularity, p.fieldSize);
        canvas.drawRect(
          Rect.fromLTRB(x - barWidth - 0.5, top, x - 0.5, plot.bottom),
          Paint()..color = popularityColor.withValues(alpha: 0.85),
        );
      }
      final rank = p.rank;
      if (rank != null) {
        final top = layout.barTopFor(rank, p.fieldSize);
        final vs = p.rankVsPopularity;
        final color = vs == 1
            ? betterColor
            : (vs == -1 ? worseColor : evenColor);
        canvas.drawRect(
          Rect.fromLTRB(x + 0.5, top, x + 0.5 + barWidth, plot.bottom),
          Paint()..color = color.withValues(alpha: 0.75),
        );
      } else {
        final String? mark = switch (p.finishKind) {
          GrowthFinishKind.stopped => '中',
          GrowthFinishKind.excluded => '除',
          GrowthFinishKind.scratched => '取',
          GrowthFinishKind.numeric => null,
          GrowthFinishKind.unknown => null,
        };
        if (mark != null) {
          final tp = _text(mark, fontSize: 9, color: worseColor);
          tp.paint(canvas,
              Offset(x - tp.width / 2, plot.bottom - tp.height - 1));
        }
      }
    }
  }

  /// 450kgの水準線。窓の外なら右上に「450kgは上方 ↑」「450kgは下方 ↓」
  void _drawReferenceLine(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    const ref = GrowthCurveBuilder.referenceWeight;
    if (window.contains(ref)) {
      final y = layout.yOfWeight(ref);
      final paint = Paint()
        ..color = referenceColor
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
      final tp = _text('${ref}kg',
          fontSize: 9, color: referenceColor, fontWeight: FontWeight.bold);
      tp.paint(canvas, Offset(plot.right - tp.width - 2, y - tp.height - 1));
    } else {
      final label = ref > window.max ? '${ref}kgは上方 ↑' : '${ref}kgは下方 ↓';
      final tp = _text(label,
          fontSize: 9, color: referenceColor, fontWeight: FontWeight.bold);
      tp.paint(canvas, Offset(plot.right - tp.width - 2, plot.top + 1));
    }
  }

  /// 馬体重の折れ線。計不をはさむ区間と「今回」への区間は破線。今回の点は白抜き
  void _drawWeightLine(Canvas canvas, GrowthCurveLayout layout) {
    final linePaint = Paint()
      ..color = weightColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    int? prevIndex;
    Offset? prevOffset;
    for (var i = 0; i < points.length; i++) {
      final w = points[i].weight;
      if (w == null) continue;
      final offset = Offset(layout.xOf(points[i].date), layout.yOfWeight(w));
      if (prevIndex != null && prevOffset != null) {
        final dashed = i - prevIndex > 1 || points[i].isCurrent;
        if (dashed) {
          _drawDashedLine(canvas, prevOffset, offset, linePaint);
        } else {
          canvas.drawLine(prevOffset, offset, linePaint);
        }
      }
      prevIndex = i;
      prevOffset = offset;
    }

    for (var i = 0; i < points.length; i++) {
      final w = points[i].weight;
      if (w == null) continue;
      final offset = Offset(layout.xOf(points[i].date), layout.yOfWeight(w));
      final radius = i == selectedIndex ? 5.5 : 3.5;
      if (points[i].isCurrent) {
        canvas.drawCircle(offset, radius, Paint()..color = Colors.white);
        canvas.drawCircle(
          offset,
          radius,
          Paint()
            ..color = weightColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(offset, radius, Paint()..color = weightColor);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final direction = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final segmentEnd = math.min(travelled + dash, total);
      canvas.drawLine(
          from + direction * travelled, from + direction * segmentEnd, paint);
      travelled += dash + gap;
    }
  }

  /// 日付の目盛り。期間が約13か月以内なら1・4・7・10月の頭（'25/10'）、それより長ければ各年の1月1日（'2026'）。
  /// 目盛りが1つも入らないときは最初と最後のレースの日付を出す
  void _drawDateAxis(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    final start = layout.start;
    final end = layout.end;
    final tickPaint = Paint()
      ..color = axisTextColor
      ..strokeWidth = 1;
    final spanDays = end.difference(start).inDays;
    final ticks = <DateTime>[];
    if (spanDays <= 400) {
      var t = DateTime(start.year, start.month, 1);
      while (!t.isAfter(end)) {
        if (!t.isBefore(start) && (t.month - 1) % 3 == 0) ticks.add(t);
        t = DateTime(t.year, t.month + 1, 1);
      }
    } else {
      var year = start.year;
      while (!DateTime(year, 1, 1).isAfter(end)) {
        final t = DateTime(year, 1, 1);
        if (!t.isBefore(start)) ticks.add(t);
        year++;
      }
    }

    String label(DateTime t) {
      if (spanDays <= 400) {
        return "'${(t.year % 100).toString().padLeft(2, '0')}/${t.month}";
      }
      return '${t.year}';
    }

    void drawLabel(String text, double x) {
      final tp = _text(text, fontSize: 9);
      final left = (x - tp.width / 2)
          .clamp(plot.left, math.max(plot.left, plot.right - tp.width))
          .toDouble();
      tp.paint(canvas, Offset(left, plot.bottom + 3));
    }

    if (ticks.isEmpty) {
      // 目盛りが入らないときは、最初と最後のレースの日付をその点の位置に出す
      // （1点だけのときの前後15日の幅は仮の幅なので、その端の日付は出さない）
      if (points.isEmpty) return;
      String edge(DateTime d) =>
          "'${(d.year % 100).toString().padLeft(2, '0')}/${d.month}/${d.day}";
      final first = points.first.date;
      final last = points.last.date;
      drawLabel(edge(first), layout.xOf(first));
      if (last.isAfter(first)) {
        drawLabel(edge(last), layout.xOf(last));
      }
      return;
    }
    for (final t in ticks) {
      final x = layout.xOf(t);
      canvas.drawLine(
          Offset(x, plot.bottom), Offset(x, plot.bottom + 3), tickPaint);
      drawLabel(label(t), x);
    }
  }

  @override
  bool shouldRepaint(covariant GrowthCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.window != window ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
