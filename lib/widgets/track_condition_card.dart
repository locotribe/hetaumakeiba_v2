import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/utils/track_constants.dart';

enum ChartType { cushion, turfMoisture, dirtMoisture }

class TrackConditionCard extends StatefulWidget {
  final List<TrackConditionRecord> meetingHistory;
  final String lastUpdatedTime;

  const TrackConditionCard({
    super.key,
    required this.meetingHistory,
    required this.lastUpdatedTime,
  });

  @override
  State<TrackConditionCard> createState() => _TrackConditionCardState();
}

class _TrackConditionCardState extends State<TrackConditionCard> {
  ChartType _currentChartType = ChartType.cushion;

  String _getCourseName(int id) {
    String idStr = id.toString();
    if (idStr.length < 6) return "不明";
    String cc = idStr.substring(4, 6);
    final Map<String, String> codes = {
      '01': '札幌', '02': '函館', '03': '福島', '04': '新潟', '05': '東京',
      '06': '中山', '07': '中京', '08': '京都', '09': '阪神', '10': '小倉',
    };
    return codes[cc] ?? "他";
  }

  String _getJapaneseWeekday(String weekDayCode) {
    final Map<String, String> weekdays = {
      'mo': '月', 'tu': '火', 'we': '水', 'th': '木',
      'fr': '金', 'sa': '土', 'su': '日',
    };
    return weekdays[weekDayCode.toLowerCase()] ?? "";
  }

  String _getVenueCode(int id) {
    String idStr = id.toString();
    return idStr.length < 6 ? "00" : idStr.substring(4, 6);
  }

  double _getInterval(double minY, double maxY) {
    double diff = maxY - minY;
    if (diff <= 1.0) return 0.2;
    if (diff <= 3.0) return 0.5;
    if (diff <= 6.0) return 1.0;
    return (diff / 4).ceilToDouble();
  }

  Widget _buildSummaryItem(String title, Widget valueWidget, Widget? evaluationWidget) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: valueWidget),
          if (evaluationWidget != null) ...[const SizedBox(height: 2), evaluationWidget]
        ],
      ),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    int index = value.toInt();
    if (index < 0 || index >= widget.meetingHistory.length) return const SizedBox.shrink();
    final record = widget.meetingHistory[index];
    final parts = record.date.split('-');
    final dateStr = parts.length == 3 ? '${parts[1]}/${parts[2]}' : record.date;
    final venueCode = _getVenueCode(record.trackConditionId);
    Widget content;
    const dateStyle = TextStyle(color: Colors.white54, fontSize: 10);

    if (_currentChartType == ChartType.cushion) {
      final val = record.cushionValue;
      final eval = val != null ? TrackConstants.getCushionEvaluation(val) : '-';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateStr, style: dateStyle),
          const SizedBox(height: 2),
          Text(val?.toStringAsFixed(1) ?? '-', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
          Text('($eval)', style: const TextStyle(color: Colors.white70, fontSize: 9)),
        ],
      );
    } else if (_currentChartType == ChartType.turfMoisture) {
      final gVal = record.moistureTurfGoal;
      final cVal = record.moistureTurf4c;
      final gEval = gVal != null ? TrackConstants.evaluateTrackCondition(venueCode, '芝', gVal) : '-';
      final cEval = cVal != null ? TrackConstants.evaluateTrackCondition(venueCode, '芝', cVal) : '-';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateStr, style: dateStyle),
          const SizedBox(height: 2),
          Text(gVal != null ? '${gVal.toStringAsFixed(1)}% $gEval' : '-', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
          Text(cVal != null ? '${cVal.toStringAsFixed(1)}% $cEval' : '-', style: TextStyle(color: Colors.green.shade400, fontSize: 10, fontFamily: 'monospace')),
        ],
      );
    } else {
      final gVal = record.moistureDirtGoal;
      final cVal = record.moistureDirt4c;
      final gEval = gVal != null ? TrackConstants.evaluateTrackCondition(venueCode, 'ダ', gVal) : '-';
      final cEval = cVal != null ? TrackConstants.evaluateTrackCondition(venueCode, 'ダ', cVal) : '-';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateStr, style: dateStyle),
          const SizedBox(height: 2),
          Text(gVal != null ? '${gVal.toStringAsFixed(1)}% $gEval' : '-', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace')),
          Text(cVal != null ? '${cVal.toStringAsFixed(1)}% $cEval' : '-', style: TextStyle(color: Colors.deepOrange.shade300, fontSize: 10, fontFamily: 'monospace')),
        ],
      );
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: content);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.meetingHistory.isEmpty) return const SizedBox.shrink();

    final latestRecord = widget.meetingHistory.last;
    final courseName = _getCourseName(latestRecord.trackConditionId);
    final jpWeekday = _getJapaneseWeekday(latestRecord.weekDay);
    final dateFull = latestRecord.date.replaceAll("-", "/");
    final venueCode = _getVenueCode(latestRecord.trackConditionId);

    double maxTurf = math.max(latestRecord.moistureTurfGoal ?? 0.0, latestRecord.moistureTurf4c ?? 0.0);
    String turfCond = maxTurf > 0 ? TrackConstants.evaluateTrackCondition(venueCode, '芝', maxTurf) : '-';
    double maxDirt = math.max(latestRecord.moistureDirtGoal ?? 0.0, latestRecord.moistureDirt4c ?? 0.0);
    String dirtCond = maxDirt > 0 ? TrackConstants.evaluateTrackCondition(venueCode, 'ダ', maxDirt) : '-';
    String cushionEval = latestRecord.cushionValue != null ? TrackConstants.getCushionEvaluation(latestRecord.cushionValue!) : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$courseName競馬場', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Expanded(child: Center(child: Text('芝: $turfCond ダ: $dirtCond', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)))),
                Text('$dateFull $jpWeekday', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryItem('クッション値', Text('${latestRecord.cushionValue ?? "-"}', style: const TextStyle(color: Colors.greenAccent, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace')), cushionEval.isNotEmpty ? Text('($cushionEval)', style: const TextStyle(color: Colors.white70, fontSize: 10)) : null),
                _buildSummaryItem('芝含水率', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Text('G:', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace')), const SizedBox(width: 4), Text('${latestRecord.moistureTurfGoal ?? "-"}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace'))]),
                  const SizedBox(height: 4),
                  Row(children: [const Text('4C:', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace')), const SizedBox(width: 4), Text('${latestRecord.moistureTurf4c ?? "-"}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace'))]),
                ]), null),
                _buildSummaryItem('ダ含水率', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Text('G:', style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace')), const SizedBox(width: 4), Text('${latestRecord.moistureDirtGoal ?? "-"}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace'))]),
                  const SizedBox(height: 4),
                  Row(children: [const Text('4C:', style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace')), const SizedBox(width: 4), Text('${latestRecord.moistureDirt4c ?? "-"}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace'))]),
                ]), null),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            if (widget.meetingHistory.length > 1) ...[
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<ChartType>(
                  segments: const [
                    ButtonSegment(value: ChartType.cushion, label: Text('クッション値', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: ChartType.turfMoisture, label: Text('芝含水率', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: ChartType.dirtMoisture, label: Text('ダ含水率', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_currentChartType},
                  onSelectionChanged: (Set<ChartType> newSelection) { setState(() { _currentChartType = newSelection.first; }); },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.transparent, foregroundColor: Colors.white70, selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: Colors.green.withOpacity(0.3), side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_currentChartType != ChartType.cushion)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(width: 12, height: 2, color: _currentChartType == ChartType.turfMoisture ? Colors.greenAccent : Colors.orangeAccent),
                    const SizedBox(width: 4),
                    const Text('ゴール前', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(width: 12),
                    Container(width: 12, height: 2, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _currentChartType == ChartType.turfMoisture ? Colors.green.shade400 : Colors.deepOrange.shade300, width: 2, style: BorderStyle.solid)))),
                    const SizedBox(width: 4),
                    const Text('4コーナー', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: _buildChart()),
            ]
          ],
        ),
      ),
    );
  }

  // [修正] グラフの表示を最大6地点に制限し、超過分は横スクロールで確認できるように変更 (v.2026.11.17+26111702)
  Widget _buildChart() {
    List<FlSpot> spots1 = [], spots2 = [];
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (int i = 0; i < widget.meetingHistory.length; i++) {
      final record = widget.meetingHistory[i];
      double? val1, val2;
      if (_currentChartType == ChartType.cushion) { val1 = record.cushionValue; }
      else if (_currentChartType == ChartType.turfMoisture) { val1 = record.moistureTurfGoal; val2 = record.moistureTurf4c; }
      else { val1 = record.moistureDirtGoal; val2 = record.moistureDirt4c; }

      if (val1 != null) { spots1.add(FlSpot(i.toDouble(), val1)); if (val1 < minY) minY = val1; if (val1 > maxY) maxY = val1; }
      else { spots1.add(FlSpot.nullSpot); }

      if (_currentChartType != ChartType.cushion) {
        if (val2 != null) { spots2.add(FlSpot(i.toDouble(), val2)); if (val2 < minY) minY = val2; if (val2 > maxY) maxY = val2; }
        else { spots2.add(FlSpot.nullSpot); }
      }
    }

    if (minY == double.infinity) { minY = 0; maxY = 10; }
    else {
      double padding = (maxY - minY) * 0.1;
      if (padding == 0) padding = 1.0;
      minY = math.max(0, minY - padding);
      maxY = maxY + padding;
    }

    final interval = _getInterval(minY, maxY);
    List<LineChartBarData> lineBarsData = [];

    if (_currentChartType == ChartType.cushion) {
      lineBarsData.add(LineChartBarData(spots: spots1, isCurved: false, color: Colors.greenAccent, barWidth: 2, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: Colors.greenAccent, strokeWidth: 0))));
    } else {
      Color c1 = _currentChartType == ChartType.turfMoisture ? Colors.greenAccent : Colors.orangeAccent;
      Color c2 = _currentChartType == ChartType.turfMoisture ? Colors.green.shade400 : Colors.deepOrange.shade300;
      lineBarsData.add(LineChartBarData(spots: spots1, isCurved: false, color: c1, barWidth: 2, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: c1, strokeWidth: 0))));
      lineBarsData.add(LineChartBarData(spots: spots2, isCurved: false, color: c2, barWidth: 2, isStrokeCapRound: true, dashArray: [4, 4], dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: c2, strokeWidth: 0))));
    }

    // [修正] 6地点以下は従来通り全幅表示。7地点以上は6地点分の幅を1画面として横スクロール表示 (v.2026.11.17+26111702)
    const int maxVisiblePoints = 6;
    final int count = widget.meetingHistory.length;

    if (count <= maxVisiblePoints) {
      return _buildLineChart(lineBarsData, minY, maxY, interval, showLeftTitles: true);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double axisWidth = 36.0; // 固定Y軸の幅(leftTitlesのreservedSizeと同じ)
        final double visibleWidth = math.max(0.0, constraints.maxWidth - axisWidth);
        final double chartWidth = visibleWidth / maxVisiblePoints * count;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: axisWidth, child: _buildFixedYAxis(minY, maxY, interval)),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // 初期表示は最新(右端)。左へスクロールすると過去分を確認できる
                child: SizedBox(
                  width: chartWidth,
                  child: _buildLineChart(lineBarsData, minY, maxY, interval, showLeftTitles: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  LineChart _buildLineChart(List<LineChartBarData> lineBarsData, double minY, double maxY, double interval, {required bool showLeftTitles}) {
    return LineChart(
      LineChartData(
        minX: 0, maxX: (widget.meetingHistory.length - 1).toDouble(), minY: minY, maxY: maxY,
        lineBarsData: lineBarsData,
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, interval: 1, getTitlesWidget: _bottomTitleWidgets)),
          // [修正] 横スクロール時はY軸ラベルをチャート外(固定側)に表示するため非表示にする (v.2026.11.17+26111702)
          leftTitles: showLeftTitles
              ? AxisTitles(sideTitles: SideTitles(showTitles: true, interval: interval, reservedSize: 36, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center)))
              : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval, getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1)),
        borderData: FlBorderData(show: true, border: Border(bottom: const BorderSide(color: Colors.white24, width: 1), left: showLeftTitles ? const BorderSide(color: Colors.white24, width: 1) : BorderSide.none, right: BorderSide.none, top: BorderSide.none)),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (touchedSpot) => Colors.black87, getTooltipItems: (touchedSpots) => touchedSpots.map((spot) => LineTooltipItem(spot.y.toStringAsFixed(1), TextStyle(color: spot.bar.color ?? Colors.white, fontWeight: FontWeight.bold))).toList())),
      ),
    );
  }

  // [修正] 横スクロール時に画面左へ固定表示するY軸ラベル (v.2026.11.17+26111702)
  Widget _buildFixedYAxis(double minY, double maxY, double interval) {
    const double bottomReserved = 60.0; // bottomTitlesのreservedSizeと一致させてプロット領域の高さを合わせる
    return LayoutBuilder(
      builder: (context, constraints) {
        final double plotHeight = math.max(0.0, constraints.maxHeight - bottomReserved);
        final double range = maxY - minY;
        final List<Widget> children = [
          Positioned(top: 0, bottom: bottomReserved, right: 0, child: Container(width: 1, color: Colors.white24)),
        ];
        if (range > 0 && plotHeight > 0) {
          for (double v = (minY / interval).ceilToDouble() * interval; v <= maxY + 1e-9; v += interval) {
            final double top = (maxY - v) / range * plotHeight - 6;
            children.add(Positioned(
              top: top.clamp(0.0, math.max(0.0, plotHeight - 12)),
              right: 4,
              child: Text(v.toStringAsFixed(1), style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ));
          }
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}
