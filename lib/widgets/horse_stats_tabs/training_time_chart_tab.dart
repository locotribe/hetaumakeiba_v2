// lib/widgets/horse_stats_tabs/training_time_chart_tab.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
// [追加] 調教タブ改修Step6: netkeiba の調教（評価データの参照に使う） (v.2026.9.23+26092303)
// [修正] 調教タイム個別データ移植Step3: 下部詳細パネル撤去に伴い、突き合わせ/表示用/コース分類/レース画面の import を削除 (v.2026.9.25+26092503)
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
// [追加] 調教タイムタブUI調整(微修正): 下部リストのドットに枠色を使う (v.2026.9.25+26092504)
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

class TrainingTimeChartTab extends StatefulWidget {
  final List<PredictionHorseDetail> horses;
  final Map<String, List<TrainingTimeModel>> trainingDataMap;
  final Map<String, List<HorseRaceRecord>> pastRecordsMap;
  // [追加] 調教タブ改修Step6: netkeiba の調教（レース日より前）と今回のレース (v.2026.9.23+26092303)
  final Map<String, List<NetkeibaTrainingSession>> netkeibaTrainingMap;
  final String raceName;
  final String raceDate;

  const TrainingTimeChartTab({
    super.key,
    required this.horses,
    required this.trainingDataMap,
    required this.pastRecordsMap,
    this.netkeibaTrainingMap = const {},
    this.raceName = '',
    this.raceDate = '',
  });

  @override
  State<TrainingTimeChartTab> createState() => _TrainingTimeChartTabState();
}

class _TrainingTimeChartTabState extends State<TrainingTimeChartTab> with SingleTickerProviderStateMixin {
  final Set<String> _selectedHorseIds = {};
  String _selectedPeriod = '3ヶ月';

  // [追加] 調教タイムタブUI調整: タップで確定する読み取り対象（未タップ時はnull=下部バー非表示） (v.2026.9.25+26092504)
  String? _readoutLocation; // '美浦' / '栗東'
  String? _readoutTrack;    // '坂路' / 'ウッド'
  DateTime? _readoutDate;   // タップ点の日付（基準日）
  static const int READOUT_WINDOW_DAYS = 10; // 近接窓（±10日）。UIセッションで調整可

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

  // [追加] 調教タイムタブUI調整: 下部読み取りバー用ヘルパ (v.2026.9.25+26092504)
  String _fmtMd(DateTime d) => '${d.month}/${d.day}';

  // [追加] 調教タイムタブUI調整: 読み取り対象トラックと一致するか (v.2026.9.25+26092504)
  bool _matchReadoutTrack(TrainingTimeModel t) {
    if (_readoutTrack == '坂路') return t.trackType.contains('坂路');
    return t.trackType.contains('ウッド') || t.trackType.contains('W');
  }

  // [追加] 調教タイムタブUI調整: 指定ハロン(fN)の累計タイム（>0のみ、無ければnull） (v.2026.9.25+26092504)
  double? _cumForFurlong(TrainingTimeModel t, int f) {
    double? v;
    switch (f) {
      case 6: v = t.f6; break;
      case 5: v = t.f5; break;
      case 4: v = t.f4; break;
      case 3: v = t.f3; break;
      case 2: v = t.f2; break;
      case 1: v = t.f1; break;
    }
    return (v != null && v > 0) ? v : null;
  }

  // [追加] 調教タイムタブUI調整: 各ハロンの1Fラップを算出（算出不可はnull）。lap(f)= f>1 ? cum(f)-cum(f-1) : cum(1) (v.2026.9.25+26092504)
  List<double?> _readoutLaps(TrainingTimeModel t, List<int> furlongs) {
    final List<double?> laps = [];
    for (final f in furlongs) {
      if (f > 1) {
        final cur = _cumForFurlong(t, f);
        final nxt = _cumForFurlong(t, f - 1);
        laps.add((cur != null && nxt != null) ? cur - nxt : null);
      } else {
        laps.add(_cumForFurlong(t, 1));
      }
    }
    return laps;
  }

  // [追加] 調教タイムタブUI調整: ラップのトレンド（前ハロン比）。-1=加速(赤)/0=横ばい(灰)/1=減速(青) (v.2026.9.25+26092504)
  int _lapTrend(double? cur, double? prev) {
    if (cur == null || prev == null) return 0;
    final d = cur - prev;
    if (d < -0.05) return -1;
    if (d > 0.05) return 1;
    return 0;
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
                    if (val != null) {
                      // [修正] 調教タイムタブUI調整: 期間変更時は古い基準日をクリア (v.2026.9.25+26092504)
                      setState(() {
                        _selectedPeriod = val;
                        _readoutLocation = null;
                        _readoutTrack = null;
                        _readoutDate = null;
                      });
                    }
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

    // [修正] 調教タブ改修Step6: 基準より slowCap 秒以上遅い軽めの時計は縦軸の範囲計算から除く。
    // 範囲外の点はグラフの枠で切り取る（LineChartData の clipData） (v.2026.9.23+26092303)
    List<double> calcYBounds(List<Map<String, List<FlSpot>>> maps, double baseLine, double slowCap) {
      double minVal = 0;
      double maxVal = -200;
      bool hasData = false;
      final double slowest = -(baseLine + slowCap);

      for (var map in maps) {
        for (var list in map.values) {
          for (var spot in list) {
            if (spot.y < slowest) continue;
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

    final hanroBounds = calcYBounds([mihoHanro, rittoHanro], math.min(CHART_MIHO_HANRO, CHART_RITTO_HANRO), 15.0);
    final woodBounds = calcYBounds([mihoWood, rittoWood], math.min(CHART_MIHO_WOOD, CHART_RITTO_WOOD), 20.0);

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
                      _buildChartCard('美浦 坂路', mihoHanro, hanroBounds[0], hanroBounds[1], maxX, baseDate, xInterval, '坂路', '美浦', CHART_MIHO_HANRO, filteredTraining, filteredRaces),
                      const SizedBox(height: 16),
                      _buildChartCard('栗東 坂路', rittoHanro, hanroBounds[0], hanroBounds[1], maxX, baseDate, xInterval, '坂路', '栗東', CHART_RITTO_HANRO, filteredTraining, filteredRaces),
                      const SizedBox(height: 24),
                      _buildSectionTitle('【ウッドエリア】 6Fタイム'),
                      _buildChartCard('美浦 ウッド', mihoWood, woodBounds[0], woodBounds[1], maxX, baseDate, xInterval, 'ウッド', '美浦', CHART_MIHO_WOOD, filteredTraining, filteredRaces),
                      const SizedBox(height: 16),
                      _buildChartCard('栗東 ウッド', rittoWood, woodBounds[0], woodBounds[1], maxX, baseDate, xInterval, 'ウッド', '栗東', CHART_RITTO_WOOD, filteredTraining, filteredRaces),
                    ],
                  );
                }
            ),
          ),
        ),
        // [追加] 調教タイムタブUI調整: 画面下部の固定読み取りバー（未タップ時は非表示） (v.2026.9.25+26092504)
        if (_readoutDate != null) _buildReadoutBar(filteredTraining),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  // [追加] 調教タイムタブUI調整: 画面下部の固定読み取りバー（タップ地点付近の選択馬を縦リスト表で比較） (v.2026.9.25+26092504)
  Widget _buildReadoutBar(Map<String, List<TrainingTimeModel>> filteredTraining) {
    final String furLabel = _readoutTrack == '坂路' ? '4F' : '6F';
    final List<int> furlongs = _readoutTrack == '坂路' ? [4, 3, 2, 1] : [6, 5, 4, 3, 2, 1];
    const double labelW = 76;
    const double overallW = 58;
    const double cellW = 46;
    const Color accelColor = Color(0xFFF06292); // 加速=赤
    const Color decelColor = Color(0xFF64B5F6); // 減速=青

    final List<Widget> rows = [];

    // 列見出し行（全体・各ハロン）
    rows.add(Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          const SizedBox(width: labelW),
          const SizedBox(width: overallW, child: Text('全体', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 10))),
          ...furlongs.map((f) => SizedBox(width: cellW, child: Text('${f}F', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10)))),
        ],
      ),
    ));

    for (var horse in widget.horses) {
      if (!_selectedHorseIds.contains(horse.horseId)) continue;
      if (_getHorseLocation(horse.horseId) != _readoutLocation) continue;

      final list = (filteredTraining[horse.horseId] ?? []).where(_matchReadoutTrack).toList();
      if (list.isEmpty) continue;

      TrainingTimeModel? nearest;
      int bestDiff = 1 << 30;
      for (var t in list) {
        final diffDays = _parseDate(t.trainingDate).difference(_readoutDate!).inDays.abs();
        if (diffDays < bestDiff) {
          bestDiff = diffDays;
          nearest = t;
        }
      }
      if (nearest == null || bestDiff > READOUT_WINDOW_DAYS) continue;

      final cum = _getCumulatives(nearest);
      if (cum.isEmpty) continue;
      final double overall = cum.first;
      final double? base = _getDynamicBaseTime(nearest, cum);
      final double? diff = base != null ? cum.first - base : null;
      final Color diffColor = diff == null ? Colors.white54 : (diff < 0 ? accelColor : decelColor);
      final String diffStr = diff == null ? '' : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}';
      // [修正] 調教タイムタブUI調整(微修正): ドット色は枠色（未発表=パレット色にフォールバック）、馬名は頭3文字 (v.2026.9.25+26092504)
      final Color dotColor = horse.gateNumber >= 1 ? horse.gateNumber.gateBackgroundColor : _getHorseColor(horse.horseId);
      final String shortName = horse.horseName.length <= 3 ? horse.horseName : horse.horseName.substring(0, 3);
      final List<double?> laps = _readoutLaps(nearest, furlongs);

      final List<Widget> lapCells = [];
      for (int i = 0; i < furlongs.length; i++) {
        final double? lap = laps[i];
        final String txt = lap == null ? '-' : lap.toStringAsFixed(1);
        String arrow = '';
        Color aColor = Colors.white38;
        if (i > 0 && lap != null) {
          final int tr = _lapTrend(lap, laps[i - 1]);
          if (tr < 0) {
            arrow = '↗';
            aColor = accelColor;
          } else if (tr > 0) {
            arrow = '↘';
            aColor = decelColor;
          } else {
            arrow = '→';
            aColor = Colors.white38;
          }
        }
        lapCells.add(SizedBox(
          width: cellW,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(txt, style: const TextStyle(color: Colors.white, fontSize: 12)),
              if (arrow.isNotEmpty)
                Text(arrow, style: TextStyle(color: aColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ));
      }

      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: labelW,
              child: Row(
                children: [
                  // [修正] 調教タイムタブUI調整(微修正): 枠色ドット（枠2=黒が暗背景で埋もれないよう細い白枠線） (v.2026.9.25+26092504)
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 0.5))),
                  Expanded(
                    child: Text('${horse.horseNumber} $shortName',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: overallW,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(overall.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (diffStr.isNotEmpty)
                    Text(diffStr, style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ...lapCells,
          ],
        ),
      ));
    }

    final bool hasHorseRow = rows.length > 1; // 見出し行＋馬1行以上

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: const Border(top: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              '$_readoutLocation $_readoutTrack $furLabel ・ ${_fmtMd(_readoutDate!)} 付近',
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          if (!hasHorseRow)
            const Text('近くにデータがありません', style: TextStyle(color: Colors.white38, fontSize: 11))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: rows,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
      String title, Map<String, List<FlSpot>> dataMap, double minY, double maxY,
      double maxX, DateTime baseDate, double xInterval, String trackType, String locationGroup, double chartBaseTime,
      Map<String, List<TrainingTimeModel>> filteredTraining, Map<String, List<HorseRaceRecord>> filteredRaces) {

    if (dataMap.values.every((list) => list.isEmpty)) return const SizedBox.shrink();

    // [追加] 調教タイムタブUI調整: このグラフに出ている選択馬の過去走日を馬色の縦点線で表示（視覚目印のみ） (v.2026.9.25+26092504)
    List<VerticalLine> raceLines = [];
    for (var horse in widget.horses) {
      if (!_selectedHorseIds.contains(horse.horseId)) continue;
      if (_getHorseLocation(horse.horseId) != locationGroup) continue;
      final rList = filteredRaces[horse.horseId] ?? [];
      final rColor = _getHorseColor(horse.horseId);
      for (var r in rList) {
        final rx = _parseDate(r.date).difference(baseDate).inDays.toDouble();
        raceLines.add(VerticalLine(
          x: rx,
          color: rColor.withValues(alpha: 0.28),
          strokeWidth: 1.0,
          dashArray: [3, 3],
        ));
      }
    }

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
                // [追加] 調教タブ改修Step6: 縦軸の範囲外（軽めの遅い時計）の点を枠で切り取る (v.2026.9.23+26092303)
                clipData: const FlClipData.all(),
                lineBarsData: lineBars,
                extraLinesData: ExtraLinesData(
                  // [追加] 調教タイムタブUI調整: レース開催日の縦点線（馬色） (v.2026.9.25+26092504)
                  verticalLines: raceLines,
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
                  // [追加] 調教タイムタブUI調整: タップ点を下部バーへ確定（location/track/基準日を保存） (v.2026.9.25+26092504)
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (!event.isInterestedForInteractions) return;
                    if (event is FlTapDownEvent) {
                      if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                        final spot = response.lineBarSpots!.first;
                        final d = baseDate.add(Duration(days: spot.x.round()));
                        setState(() {
                          _readoutLocation = locationGroup;
                          _readoutTrack = trackType;
                          _readoutDate = d;
                        });
                      }
                    }
                  },
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) => TouchedSpotIndicatorData(FlLine(color: barData.color?.withOpacity(1.0) ?? Colors.white, strokeWidth: 1.5, dashArray: [2, 2]), FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 6, color: barData.color?.withOpacity(1.0) ?? Colors.white)))).toList();
                  },
                  // [修正] 調教タイムタブUI調整: 浮動テキストツールチップを廃止（読み取りは下部バーへ一本化） (v.2026.9.25+26092504)
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 0,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) => const LineTooltipItem('', TextStyle(fontSize: 0))).toList();
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
}
