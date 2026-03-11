import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class LapTimeChartCard extends StatefulWidget {
  final LapTimeAnalysisResult result;

  const LapTimeChartCard({super.key, required this.result});

  @override
  State<LapTimeChartCard> createState() => _LapTimeChartCardState();
}

class _LapTimeChartCardState extends State<LapTimeChartCard> {
  int? _touchedSpotIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.result.averageLapTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    String formatTime(double sec) {
      if (sec >= 60) {
        int m = (sec / 60).floor();
        double s = sec % 60;
        return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
      }
      return '${sec.toStringAsFixed(1)}秒';
    }

    final avgLaps = widget.result.averageLapTimes;

    double realMinY = 999.0;
    double realMaxY = 0.0;
    for (final race in widget.result.allRacesLapData) {
      for (final lap in race.lapTimes) {
        if (lap < realMinY) realMinY = lap;
        if (lap > realMaxY) realMaxY = lap;
      }
    }
    for (final lap in avgLaps) {
      if (lap < realMinY) realMinY = lap;
      if (lap > realMaxY) realMaxY = lap;
    }
    realMinY = (realMinY - 0.5).floorToDouble();
    realMaxY = (realMaxY + 0.5).ceilToDouble();

    double chartMinY = -realMaxY;
    double chartMaxY = -realMinY;

    final avgSpots = <FlSpot>[];
    for (int i = 0; i < avgLaps.length; i++) {
      avgSpots.add(FlSpot(i.toDouble(), -avgLaps[i]));
    }

    final lineBars = <LineChartBarData>[];

    for (final race in widget.result.allRacesLapData) {
      final raceSpots = <FlSpot>[];
      for (int i = 0; i < race.lapTimes.length; i++) {
        raceSpots.add(FlSpot(i.toDouble(), -race.lapTimes[i]));
      }

      Color lineColor;
      switch (race.trackCondition) {
        case '良':
          lineColor = Colors.green;
          break;
        case '稍重':
          lineColor = Colors.lightBlue;
          break;
        case '重':
          lineColor = Colors.brown;
          break;
        case '不良':
          lineColor = Colors.grey;
          break;
        default:
          lineColor = Colors.grey;
      }

      lineBars.add(
        LineChartBarData(
          spots: raceSpots,
          isCurved: true,
          color: lineColor.withOpacity(0.6),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          showingIndicators: _touchedSpotIndex != null ? [_touchedSpotIndex!] : [],
        ),
      );
    }

    lineBars.add(
      LineChartBarData(
        spots: avgSpots,
        isCurved: true,
        color: Colors.red,
        barWidth: 3,
        isStrokeCapRound: true,
        dashArray: [5, 5],
        dotData: const FlDotData(show: true),
        showingIndicators: _touchedSpotIndex != null ? [_touchedSpotIndex!] : [],
      ),
    );

    List<DataRow> paceRows = [];
    widget.result.paceLegStyleStats.forEach((pace, stats) {
      if (stats.total > 0) {
        double nige = (stats.showCounts['逃げ'] ?? 0) / stats.total * 100;
        double senkou = (stats.showCounts['先行'] ?? 0) / stats.total * 100;
        double sashi = (stats.showCounts['差し'] ?? 0) / stats.total * 100;
        double oikomi = (stats.showCounts['追込'] ?? 0) / stats.total * 100;
        paceRows.add(DataRow(cells: [
          DataCell(Text('$pace\n(${stats.total}回)', style: const TextStyle(fontSize: 11))),
          DataCell(Text('${nige.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${senkou.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${sashi.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${oikomi.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
        ]));
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ラップタイム・ペース分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('過去の典型ペース: ${widget.result.typicalPace}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const SizedBox(height: 4),
                  Text('平均 前半3F: ${widget.result.averageFirst3F.toStringAsFixed(1)}秒 / 後半3F: ${widget.result.averageLast3F.toStringAsFixed(1)}秒', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('レース別ラップ推移', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  const Text('平均ラップ', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text('良', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.lightBlue, size: 16),
                  const SizedBox(width: 4),
                  const Text('稍重', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.brown, size: 16),
                  const SizedBox(width: 4),
                  const Text('重', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  const Text('不良', style: TextStyle(fontSize: 11))
                ]),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  gridData: const FlGridData(show: true, drawVerticalLine: true, drawHorizontalLine: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1.0,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          int idx = value.toInt();
                          if (idx >= 0 && idx < avgLaps.length) {
                            return Text('${idx + 1}F', style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(value.abs().toStringAsFixed(1), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  lineBarsData: lineBars,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: false,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                      if (!event.isInterestedForInteractions) return;

                      if (event is FlTapDownEvent) {
                        if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                          final spot = response.lineBarSpots!.first;
                          setState(() {
                            if (_touchedSpotIndex == spot.spotIndex) {
                              _touchedSpotIndex = null;
                            } else {
                              _touchedSpotIndex = spot.spotIndex;
                            }
                          });
                        } else {
                          setState(() {
                            _touchedSpotIndex = null;
                          });
                        }
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 0,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) => const LineTooltipItem('', TextStyle(fontSize: 0))).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),

            if (_touchedSpotIndex != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Builder(
                    builder: (context) {
                      List<Map<String, dynamic>> panelData = [];

                      if (_touchedSpotIndex! < avgLaps.length) {
                        double avgCum = 0;
                        for (int i = 0; i <= _touchedSpotIndex!; i++) {
                          avgCum += avgLaps[i];
                        }
                        panelData.add({
                          'isAverage': true,
                          'title': '平均',
                          'cum': avgCum,
                          'lap': avgLaps[_touchedSpotIndex!],
                          'color': Colors.red,
                        });
                      }

                      for (final race in widget.result.allRacesLapData) {
                        if (_touchedSpotIndex! >= race.lapTimes.length) continue;

                        double cum = 0;
                        for (int i = 0; i <= _touchedSpotIndex!; i++) {
                          cum += race.lapTimes[i];
                        }

                        Color textColor;
                        switch (race.trackCondition) {
                          case '良': textColor = Colors.green; break;
                          case '稍重': textColor = Colors.lightBlue; break;
                          case '重': textColor = Colors.brown; break;
                          case '不良': textColor = Colors.grey; break;
                          default: textColor = Colors.grey;
                        }

                        String yearStr = race.raceDate;
                        if (yearStr.contains('年')) {
                          yearStr = yearStr.substring(0, yearStr.indexOf('年') + 1);
                        }

                        bool isGoal = _touchedSpotIndex! == race.lapTimes.length - 1;

                        panelData.add({
                          'isAverage': false,
                          'title': yearStr,
                          'cum': cum,
                          'lap': race.lapTimes[_touchedSpotIndex!],
                          'color': textColor,
                          'isGoal': isGoal,
                          'winningHorseName': race.winningHorseName,
                          'last3F': race.last3F,
                        });
                      }

                      panelData.sort((a, b) => (a['cum'] as double).compareTo(b['cum'] as double));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_touchedSpotIndex! + 1}F目 通過詳細 (早い順)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          const SizedBox(height: 12),
                          ...panelData.map((data) {
                            final bool isAverage = data['isAverage'];
                            final Color color = data['color'];
                            final String title = data['title'];
                            final double cum = data['cum'];
                            final double lap = data['lap'];

                            if (isAverage) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text('通過: ${formatTime(cum)} / 区間: ${lap.toStringAsFixed(1)}秒', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              final bool isGoal = data['isGoal'];
                              final String winningHorseName = data['winningHorseName'];
                              final double last3F = data['last3F'];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        isGoal ? '$title\n(ゴール)' : title,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('通過: ${formatTime(cum)} / 区間: ${lap.toStringAsFixed(1)}秒', style: TextStyle(fontSize: 11, color: color)),
                                          if (isGoal) Text('$winningHorseName / 上がり: ${last3F.toStringAsFixed(1)}秒', style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }).toList(),
                        ],
                      );
                    }
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text('ペース別 脚質好走率 (3着内シェア)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('ペース')),
                  DataColumn(label: Text('逃げ')),
                  DataColumn(label: Text('先行')),
                  DataColumn(label: Text('差し')),
                  DataColumn(label: Text('追込')),
                ],
                rows: paceRows,
              ),
            ),
            if (widget.result.acceleratingRaces.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('加速ラップ記録レース (終盤失速なし)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...widget.result.acceleratingRaces.map((r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed, color: Colors.green),
                title: Text(r.raceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('前3F: ${r.first3F.toStringAsFixed(1)}秒 / 後3F: ${r.last3F.toStringAsFixed(1)}秒', style: const TextStyle(fontSize: 11)),
              )),
            ]
          ],
        ),
      ),
    );
  }
}