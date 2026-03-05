// lib/widgets/horse_stats_tabs/training_time_chart_tab.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

class TrainingTimeChartTab extends StatefulWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, List<TrainingTimeModel>> trainingDataMap;
  final Map<String, List<HorseRaceRecord>> pastRecordsMap;

  const TrainingTimeChartTab({
    super.key,
    required this.horses,
    required this.trainingDataMap,
    required this.pastRecordsMap,
  });

  @override
  State<TrainingTimeChartTab> createState() => _TrainingTimeChartTabState();
}

class _TrainingTimeChartTabState extends State<TrainingTimeChartTab> with SingleTickerProviderStateMixin {
  final Set<String> _selectedHorseIds = {};
  String _selectedPeriod = '3ヶ月';

  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  // 基準値
  static const double CHART_MIHO_HANRO = 54.5;
  static const double CHART_RITTO_HANRO = 53.5;
  static const double CHART_MIHO_WOOD = 83.0;
  static const double CHART_RITTO_WOOD = 82.0;

  final List<Color> _palette = [
    const Color(0xFF64B5F6), const Color(0xFFF06292), const Color(0xFF81C784),
    const Color(0xFFFFB74D), const Color(0xFFBA68C8), const Color(0xFF4DB6AC),
    const Color(0xFFFFF176),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.horses.isNotEmpty) {
      _selectedHorseIds.add(widget.horses.first.horseId);
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getHorseColor(String horseId) {
    int index = widget.horses.indexWhere((h) => h.horseId == horseId);
    if (index == -1) return Colors.white24;
    return _palette[index % _palette.length];
  }

  String _getHorseLocation(String horseId) {
    final tList = widget.trainingDataMap[horseId] ?? [];
    if (tList.isNotEmpty) {
      return tList.first.location.contains('栗東') ? '栗東' : '美浦';
    }
    return '美浦';
  }

  DateTime _parseDate(String dateStr) {
    try {
      if (dateStr.length == 8) {
        int year = int.parse(dateStr.substring(0, 4));
        int month = int.parse(dateStr.substring(4, 6));
        int day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }
      return DateTime.parse(dateStr.replaceAll('/', '-'));
    } catch (e) {
      return DateTime.now();
    }
  }

  String _getWeekday(DateTime date) {
    const days = ['月', '火', '水', '木', '金', '土', '日'];
    return days[date.weekday - 1];
  }

  List<double> _getCumulatives(TrainingTimeModel t) {
    List<double> c = [];
    if (t.trackType.contains('坂路')) {
      if (t.f4 != null && t.f4! > 0) c.add(t.f4!);
      if (t.f3 != null && t.f3! > 0) c.add(t.f3!);
      if (t.f2 != null && t.f2! > 0) c.add(t.f2!);
      if (t.f1 != null && t.f1! > 0) c.add(t.f1!);
    } else {
      if (t.f6 != null && t.f6! > 0) c.add(t.f6!);
      if (t.f5 != null && t.f5! > 0) c.add(t.f5!);
      if (t.f4 != null && t.f4! > 0) c.add(t.f4!);
      if (t.f3 != null && t.f3! > 0) c.add(t.f3!);
      if (t.f2 != null && t.f2! > 0) c.add(t.f2!);
      if (t.f1 != null && t.f1! > 0) c.add(t.f1!);
    }
    return c;
  }

  List<double> _getSplits(TrainingTimeModel t) {
    List<double> c = _getCumulatives(t);
    List<double> splits = [];
    for (int i = 0; i < c.length - 1; i++) {
      splits.add(c[i] - c[i + 1]);
    }
    if (c.isNotEmpty) splits.add(c.last);
    return splits;
  }

  double? _getDynamicBaseTime(TrainingTimeModel t, List<double> cumulatives) {
    if (cumulatives.isEmpty) return null;
    bool isMiho = t.location.contains('美浦');
    bool isHanro = t.trackType.contains('坂路');
    double firstVal = cumulatives.first;

    if (isHanro) {
      if (t.f4 != null && t.f4! > 0 && firstVal == t.f4) return isMiho ? 54.5 : 53.5;
    } else {
      if (t.f6 != null && t.f6! > 0 && firstVal == t.f6) return isMiho ? 83.0 : 82.0;
      if (t.f5 != null && t.f5! > 0 && firstVal == t.f5) return isMiho ? 67.0 : 66.0;
      if (t.f4 != null && t.f4! > 0 && firstVal == t.f4) return isMiho ? 52.0 : 51.0;
    }
    return null;
  }

  Widget _buildIntentBadge(TrainingTimeModel t, List<double> cumulatives) {
    if (cumulatives.isEmpty) return const SizedBox.shrink();
    bool isMiho = t.location.contains('美浦');
    bool isWood = t.trackType.contains('ウッド') || t.trackType.contains('W');
    double firstVal = cumulatives.first;
    List<Widget> badges = [];

    Widget createBadge(String text, Color color) {
      return Container(
        margin: const EdgeInsets.only(right: 6, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }

    if (isWood) {
      bool isF4Only = (t.f6 == null || t.f6 == 0) && (t.f5 == null || t.f5 == 0) && (t.f4 != null && t.f4! > 0 && firstVal == t.f4);
      bool isF5Over = (t.f6 != null && t.f6! > 0 && firstVal == t.f6) || (t.f5 != null && t.f5! > 0 && firstVal == t.f5);

      if (!isMiho && isF4Only) badges.add(createBadge('軽め調整(反応確認)', Colors.grey.shade400));
      else if (!isMiho && isF5Over) badges.add(createBadge('実戦的追い(スタミナ)', Colors.greenAccent));
      else if (isMiho && isF4Only) badges.add(createBadge('終い特化(キレ確認)', Colors.orangeAccent));
      else if (isMiho && isF5Over) badges.add(createBadge('標準的追い(総合力)', Colors.lightBlueAccent));
    }

    if (t.f1 != null && t.f1! > 0) {
      if ((!isMiho && t.f1! <= 11.4) || (isMiho && t.f1! <= 11.3)) {
        badges.add(createBadge('🔥 鬼脚', Colors.redAccent));
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(children: badges);
  }

  Widget _buildFullLapInfoWidget(TrainingTimeModel t) {
    List<double> cumulatives = _getCumulatives(t);
    if (cumulatives.isEmpty) return const Text('-', style: TextStyle(color: Colors.white70, fontSize: 13));

    String cumulativeStr = cumulatives.map((e) => e.toStringAsFixed(1)).join(' - ');

    List<double> splits = _getSplits(t);
    List<InlineSpan> spans = [];
    for (int i = 0; i < splits.length; i++) {
      spans.add(TextSpan(text: splits[i].toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));

      if (i < splits.length - 1) {
        double diff = splits[i + 1] - splits[i];
        String arrow;
        Color arrowColor;
        if (diff < -0.05) { arrow = ' ↗ '; arrowColor = Colors.redAccent; }
        else if (diff > 0.05) { arrow = ' ↘ '; arrowColor = Colors.lightBlueAccent; }
        else { arrow = ' → '; arrowColor = Colors.white70; }
        spans.add(TextSpan(text: arrow, style: TextStyle(color: arrowColor, fontWeight: FontWeight.bold)));
      }
    }

    if (splits.length >= 2) {
      double lastDiff = splits.last - splits[splits.length - 2];
      String finalArrow = lastDiff <= 0 ? '↗' : '↘';
      Color finalArrowColor = lastDiff <= 0 ? Colors.redAccent : Colors.lightBlueAccent;
      String diffStr = lastDiff > 0 ? '+${lastDiff.toStringAsFixed(1)}' : lastDiff.toStringAsFixed(1);
      spans.add(TextSpan(text: ' ($finalArrow $diffStr)', style: TextStyle(color: finalArrowColor, fontWeight: FontWeight.bold)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cumulativeStr, style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        RichText(text: TextSpan(style: const TextStyle(fontSize: 13, letterSpacing: 0.5), children: spans)),
      ],
    );
  }

  Widget _buildListLapInfoWidget(TrainingTimeModel t) {
    if (t.f2 != null && t.f1 != null && t.f2! > 0 && t.f1! > 0) {
      double split2F = t.f2! - t.f1!;
      double split1F = t.f1!;
      double diff = split1F - split2F;
      bool isAccel = diff <= 0;

      String mark = isAccel ? '↗' : '↘';
      String diffStr = diff > 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);
      Color arrowColor = isAccel ? Colors.redAccent : Colors.lightBlueAccent;

      return RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(text: '${split2F.toStringAsFixed(1)} → ${split1F.toStringAsFixed(1)} ', style: const TextStyle(color: Colors.white)),
            TextSpan(text: '($mark $diffStr)', style: TextStyle(color: arrowColor, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (t.f1 != null && t.f1! > 0) {
      return Text('${t.f1}秒', style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.right);
    }
    return const Text('-', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right);
  }

  // ★修正: ツールチップ用のラップ文字列をシンプル化（アイコンなし・横一列強制）
  String _getTooltipLapStr(TrainingTimeModel t) {
    List<double> splits = _getSplits(t);
    if (splits.isEmpty) return '-';
    // 改行を防ぐために、通常のスペースではなくノーブレークスペース（\u00A0）で繋ぐ
    return splits.map((e) => e.toStringAsFixed(1)).join('\u00A0-\u00A0');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.horses.isEmpty) return const Center(child: Text('出走馬データがありません'));

    return Column(
      children: [
        _buildControlPanel(),
        Expanded(
          child: Container(
            color: const Color(0xFF121212),
            child: _buildMainContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    final mihoHorses = widget.horses.where((h) => _getHorseLocation(h.horseId) == '美浦').toList();
    final rittoHorses = widget.horses.where((h) => _getHorseLocation(h.horseId) == '栗東').toList();

    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('比較する馬をタップ (複数可)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  dropdownColor: Colors.grey.shade800,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list, color: Colors.white70, size: 16),
                  items: const [
                    DropdownMenuItem(value: '1ヶ月', child: Text('直近1ヶ月')),
                    DropdownMenuItem(value: '3ヶ月', child: Text('直近3ヶ月')),
                    DropdownMenuItem(value: '半年', child: Text('直近半年')),
                    DropdownMenuItem(value: '1年', child: Text('直近1年')),
                    DropdownMenuItem(value: 'すべて', child: Text('全期間')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPeriod = val);
                  },
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mihoHorses.isNotEmpty) _buildHorseGroup('🟦 美浦', mihoHorses),
                if (mihoHorses.isNotEmpty && rittoHorses.isNotEmpty) const SizedBox(width: 16),
                if (rittoHorses.isNotEmpty) _buildHorseGroup('🟥 栗東', rittoHorses),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorseGroup(String groupName, List<PredictionHorseDetail> groupHorses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
          child: Text(groupName, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        Row(
          children: groupHorses.map((horse) {
            final isSelected = _selectedHorseIds.contains(horse.horseId);
            final horseColor = _getHorseColor(horse.horseId);
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: FilterChip(
                label: Text('${horse.horseNumber} ${horse.horseName}'),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0.0),
                visualDensity: const VisualDensity(horizontal: -2.0, vertical: -3.0),
                selected: isSelected,
                selectedColor: Colors.grey.shade800,
                backgroundColor: Colors.grey.shade800,
                checkmarkColor: horseColor,
                labelStyle: TextStyle(
                  color: isSelected ? horseColor : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(color: isSelected ? horseColor : Colors.transparent),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedHorseIds.add(horse.horseId);
                    } else {
                      if (_selectedHorseIds.length > 1) _selectedHorseIds.remove(horse.horseId);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    Map<String, List<TrainingTimeModel>> filteredTraining = {};
    Map<String, List<HorseRaceRecord>> filteredRaces = {};
    List<DateTime> allDates = [];

    DateTime? cutoffDate;
    if (_selectedPeriod != 'すべて') {
      List<DateTime> globalDates = [];
      for (var tList in widget.trainingDataMap.values) {
        globalDates.addAll(tList.map((t) => _parseDate(t.trainingDate)));
      }
      if (globalDates.isNotEmpty) {
        globalDates.sort();
        int days = 30;
        if (_selectedPeriod == '3ヶ月') days = 90;
        if (_selectedPeriod == '半年') days = 180;
        if (_selectedPeriod == '1年') days = 365;
        cutoffDate = globalDates.last.subtract(Duration(days: days));
      }
    }

    for (var horse in widget.horses) {
      var tList = widget.trainingDataMap[horse.horseId] ?? [];
      var rList = widget.pastRecordsMap[horse.horseId] ?? [];

      if (cutoffDate != null) {
        tList = tList.where((t) => _parseDate(t.trainingDate).isAfter(cutoffDate!)).toList();
        rList = rList.where((r) => _parseDate(r.date).isAfter(cutoffDate!)).toList();
      }

      filteredTraining[horse.horseId] = tList;
      filteredRaces[horse.horseId] = rList;

      allDates.addAll(tList.map((t) => _parseDate(t.trainingDate)));
      allDates.addAll(rList.map((r) => _parseDate(r.date)));
    }

    if (allDates.isEmpty) return const Center(child: Text('データがありません', style: TextStyle(color: Colors.white70)));

    allDates.sort();
    int bufferDays = _selectedPeriod == '1ヶ月' ? 2 : 7;
    final DateTime baseDate = allDates.first.subtract(Duration(days: bufferDays));
    final DateTime endDate = allDates.last.add(Duration(days: bufferDays));
    final double maxX = endDate.difference(baseDate).inDays.toDouble();

    double xInterval = 30;
    if (maxX <= 40) xInterval = 5;
    else if (maxX <= 100) xInterval = 15;
    else if (maxX <= 200) xInterval = 30;
    else if (maxX <= 400) xInterval = 60;
    else xInterval = 120;

    Map<String, List<FlSpot>> mihoHanro = {};
    Map<String, List<FlSpot>> rittoHanro = {};
    Map<String, List<FlSpot>> mihoWood = {};
    Map<String, List<FlSpot>> rittoWood = {};

    for (var horse in widget.horses) {
      mihoHanro[horse.horseId] = []; rittoHanro[horse.horseId] = [];
      mihoWood[horse.horseId] = []; rittoWood[horse.horseId] = [];

      for (var t in filteredTraining[horse.horseId]!) {
        double x = _parseDate(t.trainingDate).difference(baseDate).inDays.toDouble();
        bool isMiho = t.location.contains('美浦');
        bool isRitto = t.location.contains('栗東');
        bool isHanro = t.trackType.contains('坂路');
        bool isWood = t.trackType.contains('ウッド') || t.trackType.contains('W');

        if (isHanro && t.f4 != null && t.f4! > 0) {
          if (isMiho) mihoHanro[horse.horseId]!.add(FlSpot(x, -t.f4!));
          if (isRitto) rittoHanro[horse.horseId]!.add(FlSpot(x, -t.f4!));
        } else if (isWood && t.f6 != null && t.f6! > 0) {
          if (isMiho) mihoWood[horse.horseId]!.add(FlSpot(x, -t.f6!));
          if (isRitto) rittoWood[horse.horseId]!.add(FlSpot(x, -t.f6!));
        }
      }
      mihoHanro[horse.horseId]!.sort((a, b) => a.x.compareTo(b.x));
      rittoHanro[horse.horseId]!.sort((a, b) => a.x.compareTo(b.x));
      mihoWood[horse.horseId]!.sort((a, b) => a.x.compareTo(b.x));
      rittoWood[horse.horseId]!.sort((a, b) => a.x.compareTo(b.x));
    }

    List<double> calcYBounds(List<Map<String, List<FlSpot>>> maps, double baseLine) {
      double minVal = 0;
      double maxVal = -200;
      bool hasData = false;

      for (var map in maps) {
        for (var list in map.values) {
          for (var spot in list) {
            hasData = true;
            minVal = math.min(minVal, spot.y);
            maxVal = math.max(maxVal, spot.y);
          }
        }
      }
      if (!hasData) return [-baseLine - 2.0, -baseLine + 2.0];
      minVal = math.min(minVal, -baseLine);
      maxVal = math.max(maxVal, -baseLine);
      double span = maxVal - minVal;
      double pad = span < 2.0 ? 0.5 : 1.5;
      return [minVal - pad, maxVal + pad];
    }

    final hanroBounds = calcYBounds([mihoHanro, rittoHanro], math.min(CHART_MIHO_HANRO, CHART_RITTO_HANRO));
    final woodBounds = calcYBounds([mihoWood, rittoWood], math.min(CHART_MIHO_WOOD, CHART_RITTO_WOOD));

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('【坂路エリア】 4Fタイム'),
                      _buildChartCard('美浦 坂路', mihoHanro, hanroBounds[0], hanroBounds[1], maxX, baseDate, xInterval, '坂路', '美浦', CHART_MIHO_HANRO, filteredTraining),
                      const SizedBox(height: 16),
                      _buildChartCard('栗東 坂路', rittoHanro, hanroBounds[0], hanroBounds[1], maxX, baseDate, xInterval, '坂路', '栗東', CHART_RITTO_HANRO, filteredTraining),
                      const SizedBox(height: 24),
                      _buildSectionTitle('【ウッドエリア】 6Fタイム'),
                      _buildChartCard('美浦 ウッド', mihoWood, woodBounds[0], woodBounds[1], maxX, baseDate, xInterval, 'ウッド', '美浦', CHART_MIHO_WOOD, filteredTraining),
                      const SizedBox(height: 16),
                      _buildChartCard('栗東 ウッド', rittoWood, woodBounds[0], woodBounds[1], maxX, baseDate, xInterval, 'ウッド', '栗東', CHART_RITTO_WOOD, filteredTraining),
                    ],
                  );
                }
            ),
          ),
        ),
        _buildBottomDetailPanel(filteredTraining),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildChartCard(
      String title, Map<String, List<FlSpot>> dataMap, double minY, double maxY,
      double maxX, DateTime baseDate, double xInterval, String trackType, String locationGroup, double chartBaseTime,
      Map<String, List<TrainingTimeModel>> filteredTraining) {

    if (dataMap.values.every((list) => list.isEmpty)) return const SizedBox.shrink();

    List<LineChartBarData> lineBars = [];
    for (var horse in widget.horses) {
      final spots = dataMap[horse.horseId]!;
      if (spots.isEmpty) continue;

      final isSelected = _selectedHorseIds.contains(horse.horseId);
      final horseColor = _getHorseColor(horse.horseId);

      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: isSelected ? horseColor.withOpacity(_glowAnimation.value) : Colors.transparent,
          barWidth: isSelected ? 1.0 : 0.0,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              if (isSelected) {
                return FlDotCirclePainter(radius: 4.5, color: horseColor.withOpacity(_glowAnimation.value), strokeWidth: 1.0, strokeColor: Colors.black);
              } else {
                return FlDotCirclePainter(radius: 2.5, color: Colors.white24, strokeWidth: 0);
              }
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8, left: 0),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0, maxX: maxX, minY: minY, maxY: maxY,
                lineBarsData: lineBars,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: -chartBaseTime,
                      color: Colors.white54,
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        labelResolver: (_) => '基準 (${chartBaseTime}秒)',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        alignment: Alignment.bottomRight,
                      ),
                    ),
                  ],
                ),
                gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1), getDrawingVerticalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 22, interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                        final date = baseDate.add(Duration(days: value.toInt()));
                        String label = (xInterval >= 60) ? '${date.year}/${date.month}' : '${date.month}/${date.day}';
                        return Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(value.abs().toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 30,
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) => TouchedSpotIndicatorData(FlLine(color: barData.color?.withOpacity(1.0) ?? Colors.white, strokeWidth: 1.5, dashArray: [2, 2]), FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 6, color: barData.color?.withOpacity(1.0) ?? Colors.white)))).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 350,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        DateTime tDate = baseDate.add(Duration(days: spot.x.toInt()));
                        TrainingTimeModel? targetRecord;

                        for (var horseId in filteredTraining.keys) {
                          if (_getHorseLocation(horseId) != locationGroup) continue;
                          for (var t in filteredTraining[horseId]!) {
                            DateTime d = _parseDate(t.trainingDate);
                            if (d.year == tDate.year && d.month == tDate.month && d.day == tDate.day) {
                              double val = trackType == '坂路' ? (t.f4 ?? 0) : (t.f6 ?? 0);
                              if ((spot.y.abs() - val).abs() < 0.01) {
                                targetRecord = t;
                                break;
                              }
                            }
                          }
                          if (targetRecord != null) break;
                        }

                        String lapStr = '${spot.y.abs().toStringAsFixed(1)}秒';
                        String diffText = '';

                        if (targetRecord != null) {
                          lapStr = _getTooltipLapStr(targetRecord);
                          List<double> cumulatives = _getCumulatives(targetRecord);
                          double? dynamicBase = _getDynamicBaseTime(targetRecord, cumulatives);
                          if (dynamicBase != null) {
                            double diff = cumulatives.first - dynamicBase;
                            String sign = diff > 0 ? '+' : '';
                            // ★修正: ノーブレークスペース(\u00A0)で繋ぐことで絶対に改行させない
                            diffText = '\u00A0(基準差:\u00A0$sign${diff.toStringAsFixed(1)}秒)';
                          }
                        }

                        String text = '$lapStr$diffText';
                        return LineTooltipItem(
                            text,
                            TextStyle(
                              color: spot.bar.color?.withOpacity(1.0) ?? Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 11, // フォントサイズを少し大きくして見やすく
                            )
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestTrainingCard(TrainingTimeModel t, Color horseColor) {
    List<double> cumulatives = _getCumulatives(t);
    String totalStr = cumulatives.isNotEmpty ? cumulatives.first.toStringAsFixed(1) : '-';
    DateTime d = _parseDate(t.trainingDate);
    String weekday = _getWeekday(d);

    String diffText = '';
    Color diffColor = Colors.white70;
    double? dynamicBase = _getDynamicBaseTime(t, cumulatives);

    if (dynamicBase != null && cumulatives.isNotEmpty) {
      double diff = cumulatives.first - dynamicBase;
      String sign = diff > 0 ? '+' : '';
      diffText = '(基準差: $sign${diff.toStringAsFixed(1)}秒)';
      diffColor = diff < 0 ? Colors.redAccent.shade200 : (diff > 0 ? Colors.lightBlueAccent.shade200 : Colors.white70);
    } else if (cumulatives.isNotEmpty) {
      diffText = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(top: 6, bottom: 12),
      decoration: BoxDecoration(
          color: horseColor.withOpacity(0.05),
          border: Border.all(color: horseColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flash_on, color: horseColor, size: 14),
                  const SizedBox(width: 4),
                  Text('直近の追い切り (最新データ)', style: TextStyle(color: horseColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    const TextSpan(text: '全体: ', style: TextStyle(color: Colors.white70)),
                    TextSpan(text: '$totalStr秒 ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    TextSpan(text: diffText, style: TextStyle(color: diffColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${d.month}/${d.day}($weekday)  ${t.location}${t.trackType}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 8),
              _buildIntentBadge(t, cumulatives),
            ],
          ),
          const SizedBox(height: 6),
          _buildFullLapInfoWidget(t),
        ],
      ),
    );
  }

  Widget _buildBottomDetailPanel(Map<String, List<TrainingTimeModel>> filteredTraining) {
    if (_selectedHorseIds.isEmpty) return const SizedBox.shrink();

    return Expanded(
      flex: 5,
      child: Container(
        padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, -2))],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _selectedHorseIds.map((horseId) {
              final horseName = widget.horses.firstWhere((h) => h.horseId == horseId).horseName;
              final horseColor = _getHorseColor(horseId);
              final myTraining = filteredTraining[horseId] ?? [];

              var sorted = List<TrainingTimeModel>.from(myTraining)..sort((a, b) => _parseDate(b.trainingDate).compareTo(_parseDate(a.trainingDate)));
              var recent = sorted.take(5).toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: horseColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(horseName, style: TextStyle(color: horseColor, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (recent.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('表示期間内の調教データなし', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      )
                    else ...[
                      _buildLatestTrainingCard(recent.first, horseColor),

                      if (recent.length > 1) ...[
                        Row(
                          children: const [
                            Expanded(flex: 2, child: Text('日付', style: TextStyle(color: Colors.white54, fontSize: 11))),
                            Expanded(flex: 2, child: Text('コース', style: TextStyle(color: Colors.white54, fontSize: 11))),
                            Expanded(flex: 2, child: Text('全体', style: TextStyle(color: Colors.white54, fontSize: 11))),
                            Expanded(flex: 2, child: Text('基準差', style: TextStyle(color: Colors.white54, fontSize: 11))),
                            Expanded(flex: 4, child: Text('ラップ (2F→1F)', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.right)),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 8),
                        ...recent.skip(1).map((t) {
                          List<double> cumulatives = _getCumulatives(t);
                          String totalStr = cumulatives.isNotEmpty ? cumulatives.first.toStringAsFixed(1) : '-';

                          DateTime d = _parseDate(t.trainingDate);
                          String weekday = _getWeekday(d);

                          String diffText = '-';
                          Color diffColor = Colors.white70;
                          double? dynamicBase = _getDynamicBaseTime(t, cumulatives);

                          if (dynamicBase != null && cumulatives.isNotEmpty) {
                            double diff = cumulatives.first - dynamicBase;
                            String sign = diff > 0 ? '+' : '';
                            diffText = '$sign${diff.toStringAsFixed(1)}';
                            diffColor = diff < 0 ? Colors.redAccent.shade200 : (diff > 0 ? Colors.lightBlueAccent.shade200 : Colors.white70);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('${d.month}/${d.day}($weekday)', style: const TextStyle(color: Colors.white, fontSize: 11))),
                                Expanded(flex: 2, child: Text('${t.location}${t.trackType}', style: const TextStyle(color: Colors.white, fontSize: 11))),
                                Expanded(flex: 2, child: Text(totalStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text(diffText, style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 4, child: _buildListLapInfoWidget(t)),
                              ],
                            ),
                          );
                        }).toList(),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text('これ以前の履歴はありません', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        )
                      ],
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}