// lib/widgets/horse_detail/growth_curve_painter.dart

// [追加] 馬体重成長曲線 Step2: 成長曲線の描画（馬体重の折れ線＋450kgの水準線＋人気・着順の棒＋日付の目盛り）。
// 棒をレースの実際の日付の位置に立て、その上に折れ線を重ねるため、fl_chart ではなく CustomPainter で描く。
// レース名はグラフに描かない（点をタップすると下に表示される） (v.2026.10.1+26100102)
// [修正] 馬詳細タブ 表示項目変更 Step3: 棒を「頭数（薄いグレー）・人気（緑）・着順（赤）」の3本に（18頭立てを満杯とする高さ）。
// 450kgの水準線を廃止。横スクロールのため、体重の目盛りは別の描画（GrowthCurveAxisPainter）に分け、本体は左端0から描く。
// 日付の目盛りは1・4・7・10月の頭に統一 (v.2026.10.15+26101502)
// [修正] 成長曲線の表示項目追加: いちばん上に帯を足し、各レースの位置に赤い ▼（取消・除外は赤い ×）と、
// ▼ と ▼ の間に前走からの間隔（入らないときは出さない）を描く。タップで選んだ点は薄い青で点滅させる (v.2026.10.19+26101905)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';

/// 成長曲線の座標計算（描画とタップ判定で共用する）
class GrowthCurveLayout {
  /// 左の体重目盛りの幅（目盛りは本体の左に固定で置く）
  static const double leftAxisWidth = 34;
  static const double rightPadding = 10;
  static const double topPadding = 10;

  // [追加] 成長曲線の表示項目追加: いちばん上の ▼ と間隔の帯の高さ（この下に topPadding、その下に描画領域） (v.2026.10.19+26101905)
  static const double markerBandHeight = 14;

  /// 折れ線と棒を描く領域の高さ
  // [修正] 馬詳細タブ 表示項目変更 Step3追補: グラフ全体の高さを 226 → 180 にする（描画領域 200 → 154。上の余白10・日付の目盛り16は同じ） (v.2026.10.15+26101502)
  static const double plotHeight = 154;

  /// 日付の目盛りの高さ
  static const double dateAxisHeight = 16;

  /// 点が枠の左右端で切れないための内側の余白
  static const double innerPadding = 12;

  /// 人気・着順の棒が使う高さの割合（描画領域の下から）
  // [修正] 馬詳細タブ 表示項目変更 Step3追補: 棒の領域を下50%から80%へ広げる（体重の線と重なってもよい） (v.2026.10.15+26101502)
  static const double barZoneRatio = 0.8;

  // [修正] 成長曲線の表示項目追加: 上の帯の高さを足す (v.2026.10.19+26101905)
  static const double totalHeight =
      markerBandHeight + topPadding + plotHeight + dateAxisHeight;

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
    // [修正] 馬詳細タブ 表示項目変更 Step3: 目盛りを別に描くので、描画領域は左端0から (v.2026.10.15+26101502)
    // [修正] 成長曲線の表示項目追加: 描画領域は上の帯の下から (v.2026.10.19+26101905)
    plot = Rect.fromLTWH(
      0,
      markerBandHeight + topPadding,
      math.max(0.0, size.width - rightPadding),
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

  /// 棒の領域の上端（満杯の棒の頂点）
  double get barZoneTop => plot.bottom - plot.height * barZoneRatio;

  // [修正] 馬詳細タブ 表示項目変更 Step3: 棒の頂点を高さの割合（0〜1。GrowthCurveBuilder の fieldBarFraction / positionBarFraction）から求める (v.2026.10.15+26101502)
  double barTopForFraction(double fraction) {
    final f = fraction.clamp(0.0, 1.0).toDouble();
    return plot.bottom - (plot.bottom - barZoneTop) * f;
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

/// 色・文字の共通部品
class _GrowthCurveText {
  static TextPainter text(String text,
      {double fontSize = 10,
      Color color = GrowthCurvePainter.axisTextColor,
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
}

// [追加] 馬詳細タブ 表示項目変更 Step3: 左の体重目盛り（横スクロールしない帯）。本体と同じ縦の位置に目盛りの文字を描く (v.2026.10.15+26101502)
class GrowthCurveAxisPainter extends CustomPainter {
  final GrowthWeightWindow window;

  GrowthCurveAxisPainter({required this.window});

  @override
  void paint(Canvas canvas, Size size) {
    final layout = GrowthCurveLayout(
        size: size, points: const <GrowthPoint>[], window: window);
    final lineCount =
        (window.max - window.min) ~/ GrowthCurveBuilder.gridStep;
    final labelStep = lineCount > 10
        ? GrowthCurveBuilder.gridStep * 2
        : GrowthCurveBuilder.gridStep;
    for (var kg = window.min;
        kg <= window.max;
        kg += GrowthCurveBuilder.gridStep) {
      if ((kg - window.min) % labelStep != 0) continue;
      final y = layout.yOfWeight(kg);
      final tp = _GrowthCurveText.text('$kg');
      tp.paint(canvas, Offset(size.width - tp.width - 4, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant GrowthCurveAxisPainter oldDelegate) {
    return oldDelegate.window != window;
  }
}

class GrowthCurvePainter extends CustomPainter {
  final List<GrowthPoint> points;
  final GrowthWeightWindow window;

  /// 選択中の点の番号（null なら選択なし）
  final int? selectedIndex;

  // [追加] 成長曲線の表示項目追加: true なら選択中の点を薄い青で点滅させる（タップで選んだときだけ） (v.2026.10.19+26101905)
  final bool highlightSelected;

  // [追加] 成長曲線の表示項目追加: 点滅の進み具合（0〜1）。値が変わるたびに描き直す (v.2026.10.19+26101905)
  final Animation<double>? blink;

  // [追加] 成長曲線の表示項目追加: 上の帯の ▼・× の色と、選択中の点の点滅の色 (v.2026.10.19+26101905)
  static const Color markerColor = Color(0xFFE53935);
  static const Color highlightColor = Color(0xFF4FC3F7);

  static const Color weightColor = Color(0xFF5D4037);
  // [修正] 馬詳細タブ 表示項目変更 Step3: 棒の色は 頭数=薄いグレー・人気=緑・着順=赤 の3色（着順の上/下/同じの色分けと450kg線の色は廃止） (v.2026.10.15+26101502)
  static const Color fieldColor = Color(0xFFB0BEC5);
  static const Color popularityColor = Color(0xFF43A047);
  static const Color rankColor = Color(0xFFE53935);
  static const Color gridColor = Color(0xFFE0E0E0);
  static const Color axisTextColor = Color(0xFF757575);

  GrowthCurvePainter({
    required this.points,
    required this.window,
    required this.selectedIndex,
    this.highlightSelected = false,
    this.blink,
  }) : super(repaint: blink);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final layout =
        GrowthCurveLayout(size: size, points: points, window: window);
    _drawGrid(canvas, layout);
    _drawSelectedGuide(canvas, layout);
    _drawBars(canvas, layout);
    _drawWeightLine(canvas, layout);
    _drawDateAxis(canvas, layout);
    // [追加] 成長曲線の表示項目追加 (v.2026.10.19+26101905)
    _drawRaceMarkers(canvas, layout);
    canvas.restore();
  }

  /// 10kgごとの横線（目盛りの文字は GrowthCurveAxisPainter が描く）
  void _drawGrid(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var kg = window.min;
        kg <= window.max;
        kg += GrowthCurveBuilder.gridStep) {
      final y = layout.yOfWeight(kg);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
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

  // [修正] 馬詳細タブ 表示項目変更 Step3: 左から 頭数・人気・着順 の3本。高さは18頭立てを満杯とする。
  // 頭数が分からないレースは頭数の棒を描かない（人気・着順は18頭として計算）。中止・除外・取消は着順の棒の代わりに「中」「除」「取」 (v.2026.10.15+26101502)
  void _drawBars(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    final barWidth = (layout.minGap * 0.22).clamp(1.5, 6.0).toDouble();
    const gap = 0.5;
    for (final p in points) {
      if (p.isCurrent) continue;
      final x = layout.xOf(p.date);
      final fieldLeft = x - barWidth * 1.5 - gap;
      final popularityLeft = x - barWidth / 2;
      final rankLeft = x + barWidth / 2 + gap;

      final fieldSize = p.fieldSize;
      if (fieldSize != null) {
        final top = layout.barTopForFraction(
            GrowthCurveBuilder.fieldBarFraction(fieldSize));
        canvas.drawRect(
          Rect.fromLTRB(fieldLeft, top, fieldLeft + barWidth, plot.bottom),
          Paint()..color = fieldColor.withValues(alpha: 0.9),
        );
      }

      final popularity = p.popularity;
      if (popularity != null) {
        final top = layout.barTopForFraction(
            GrowthCurveBuilder.positionBarFraction(popularity, fieldSize));
        canvas.drawRect(
          Rect.fromLTRB(
              popularityLeft, top, popularityLeft + barWidth, plot.bottom),
          Paint()..color = popularityColor.withValues(alpha: 0.8),
        );
      }

      final rank = p.rank;
      if (rank != null) {
        final top = layout.barTopForFraction(
            GrowthCurveBuilder.positionBarFraction(rank, fieldSize));
        canvas.drawRect(
          Rect.fromLTRB(rankLeft, top, rankLeft + barWidth, plot.bottom),
          Paint()..color = rankColor.withValues(alpha: 0.8),
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
          final tp = _GrowthCurveText.text(mark, fontSize: 9, color: rankColor);
          tp.paint(canvas,
              Offset(x - tp.width / 2, plot.bottom - tp.height - 1));
        }
      }
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
      // [修正] 成長曲線の表示項目追加: タップで選んだ点は薄い青で点滅（透明度 35%〜100%）。
      // 下の折れ線が透けないよう、先に白で塗る (v.2026.10.19+26101905)
      final highlight = highlightSelected && i == selectedIndex;
      final color = highlight
          ? highlightColor.withValues(
              alpha: 0.35 + 0.65 * (blink?.value ?? 1.0))
          : weightColor;
      if (points[i].isCurrent) {
        canvas.drawCircle(offset, radius, Paint()..color = Colors.white);
        canvas.drawCircle(
          offset,
          radius,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        if (highlight) {
          canvas.drawCircle(offset, radius, Paint()..color = Colors.white);
        }
        canvas.drawCircle(offset, radius, Paint()..color = color);
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

  /// 日付の目盛り。1・4・7・10月の頭（'25/10'）。
  /// 目盛りが1つも入らないときは最初と最後のレースの日付を出す
  void _drawDateAxis(Canvas canvas, GrowthCurveLayout layout) {
    final plot = layout.plot;
    final start = layout.start;
    final end = layout.end;
    final tickPaint = Paint()
      ..color = axisTextColor
      ..strokeWidth = 1;
    final ticks = <DateTime>[];
    var t = DateTime(start.year, start.month, 1);
    while (!t.isAfter(end)) {
      if (!t.isBefore(start) && (t.month - 1) % 3 == 0) ticks.add(t);
      t = DateTime(t.year, t.month + 1, 1);
    }

    String label(DateTime d) =>
        "'${(d.year % 100).toString().padLeft(2, '0')}/${d.month}";

    void drawLabel(String text, double x) {
      final tp = _GrowthCurveText.text(text, fontSize: 9);
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
    for (final tick in ticks) {
      final x = layout.xOf(tick);
      canvas.drawLine(
          Offset(x, plot.bottom), Offset(x, plot.bottom + 3), tickPaint);
      drawLabel(label(tick), x);
    }
  }

  // [追加] 成長曲線の表示項目追加: いちばん上の帯。各レースの位置に赤い ▼（取消・除外は赤い ×）、
  // 隣り合う印の間に前走からの間隔の文字（印の間に入りきらないときは出さない） (v.2026.10.19+26101905)
  void _drawRaceMarkers(Canvas canvas, GrowthCurveLayout layout) {
    if (points.isEmpty) return;
    const half = 4.0;
    const top = 3.0;
    const tip = 10.0;
    const centerY = (top + tip) / 2;
    final fillPaint = Paint()..color = markerColor;
    final crossPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final xs = [for (final p in points) layout.xOf(p.date)];
    for (var i = 0; i < points.length; i++) {
      final x = xs[i];
      if (points[i].didNotStart) {
        canvas.drawLine(Offset(x - half + 0.5, top),
            Offset(x + half - 0.5, tip), crossPaint);
        canvas.drawLine(Offset(x + half - 0.5, top),
            Offset(x - half + 0.5, tip), crossPaint);
      } else {
        final path = Path()
          ..moveTo(x - half, top)
          ..lineTo(x + half, top)
          ..lineTo(x, tip)
          ..close();
        canvas.drawPath(path, fillPaint);
      }
      if (i == 0) continue;
      final label =
          GrowthCurveBuilder.intervalLabel(points[i - 1].date, points[i].date);
      if (label == '--') continue;
      final tp = _GrowthCurveText.text(label, fontSize: 9);
      final room = xs[i] - xs[i - 1] - half * 2 - 4;
      if (tp.width > room) continue;
      tp.paint(
          canvas,
          Offset((xs[i - 1] + xs[i]) / 2 - tp.width / 2,
              centerY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant GrowthCurvePainter oldDelegate) {
    // [修正] 成長曲線の表示項目追加: 点滅の有無と点滅の進み具合も見る (v.2026.10.19+26101905)
    return oldDelegate.points != points ||
        oldDelegate.window != window ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.highlightSelected != highlightSelected ||
        oldDelegate.blink != blink;
  }
}
