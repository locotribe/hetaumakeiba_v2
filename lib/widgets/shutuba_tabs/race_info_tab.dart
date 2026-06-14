// lib/widgets/shutuba_tabs/race_info_tab.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/services/jma_weather_service.dart';
import 'package:hetaumakeiba_v2/services/open_meteo_service.dart';
import 'package:hetaumakeiba_v2/logic/analysis/weather_analyzer.dart';
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/logic/elevation_logic.dart';
// [追加] コース平面図表示 (v.1.0)
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/services/course_diagram_service.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/course_diagram_painter.dart';

class RaceInfoTabWidget extends StatefulWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function(int) buildGateNumber;
  final Widget Function(int, int) buildHorseNumber;

  const RaceInfoTabWidget({
    super.key,
    required this.predictionRaceData,
    required this.horses,
    required this.buildMarkDropdown,
    required this.buildGateNumber,
    required this.buildHorseNumber,
  });

  @override
  State<RaceInfoTabWidget> createState() => _RaceInfoTabWidgetState();
}

class _RaceInfoTabWidgetState extends State<RaceInfoTabWidget> with AutomaticKeepAliveClientMixin {
  final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();
  Future<TrackConditionRecord?>? _trackConditionFuture;
  Future<Map<String, String>?>? _jmaWeatherFuture;
  Future<Map<String, dynamic>?>? _pinpointWeatherFuture;

  TrackConditionRecord? _currentTrackRecord;
  TrackConditionRecord? _cachedPrevRecord;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didUpdateWidget(RaceInfoTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.predictionRaceData.raceId != oldWidget.predictionRaceData.raceId) {
      _loadAllData();
    }
  }

  String _mapToTrackTypeKey() {
    final tt = widget.predictionRaceData.trackType ?? '';
    final dir = widget.predictionRaceData.direction ?? '';
    final inOut = widget.predictionRaceData.courseInOut ?? '';

    if (tt.contains('ダ')) return 'dirt';
    if (dir.contains('直')) return 'shiba_straight';
    if (inOut.contains('外')) return 'shiba_outer';
    if (inOut.contains('内')) return 'shiba_inner';
    return 'shiba';
  }

  String _getFormattedRaceTime() {
    final rawDate = widget.predictionRaceData.raceDate;
    final rawTime = widget.predictionRaceData.startTime ?? "未定";
    try {
      final dateMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(rawDate);
      if (dateMatch != null) {
        final year = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final day = int.parse(dateMatch.group(3)!);
        final dt = DateTime(year, month, day);
        const weekdays = ['', '月', '火', '水', '木', '金', '土', '日'];
        final w = weekdays[dt.weekday];
        return '$month/$day($w) $rawTime';
      }
    } catch(e) {}
    return rawTime;
  }

  bool _isWeatherLocked() {
    try {
      int year = DateTime.now().year;
      int month = DateTime.now().month;
      int day = DateTime.now().day;
      final dateMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(widget.predictionRaceData.raceDate);
      if (dateMatch != null) {
        year = int.parse(dateMatch.group(1)!);
        month = int.parse(dateMatch.group(2)!);
        day = int.parse(dateMatch.group(3)!);
      } else {
        return true;
      }
      final timeStr = widget.predictionRaceData.startTime ?? "15:00";
      final timeParts = timeStr.split(':');
      int hour = 15;
      int minute = 0;
      if (timeParts.length >= 2) {
        hour = int.tryParse(timeParts[0]) ?? 15;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }
      final raceDateTime = DateTime(year, month, day, hour, minute);
      final lockTime = raceDateTime.add(const Duration(hours: 1));
      return DateTime.now().isAfter(lockTime);
    } catch (e) {
      return true;
    }
  }

  void _loadAllData({bool forceRefresh = false}) {
    _loadTrackCondition();
    setState(() {
      final venue = widget.predictionRaceData.venue;
      final raceId = widget.predictionRaceData.raceId;
      final isLocked = _isWeatherLocked();

      _jmaWeatherFuture = JmaWeatherService.fetchWeatherAndPop(
          venue,
          raceId,
          forceRefresh: forceRefresh,
          isPastRace: isLocked
      );

      _pinpointWeatherFuture = OpenMeteoService.fetchDetailedWeather(
          venue,
          widget.predictionRaceData.raceDate,
          widget.predictionRaceData.startTime ?? "15:00",
          raceId,
          forceRefresh: forceRefresh,
          isPastRace: isLocked
      );
    });
  }

  void _loadTrackCondition() {
    if (widget.predictionRaceData.raceId.length >= 6) {
      final venueCode = widget.predictionRaceData.raceId.substring(4, 6);
      setState(() {
        _trackConditionFuture = _trackConditionRepo.getLatestTrackConditionsForEachCourse().then((records) {
          try {
            final newRecord = records.firstWhere((r) {
              final idStr = r.trackConditionId.toString();
              if (idStr.length >= 6) {
                return idStr.substring(4, 6) == venueCode;
              }
              return false;
            });

            if (_currentTrackRecord != null && _currentTrackRecord!.trackConditionId != newRecord.trackConditionId) {
              _cachedPrevRecord = _currentTrackRecord;
            }
            _currentTrackRecord = newRecord;

            return newRecord;
          } catch (e) {
            return null;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRaceHeader(context),
          const Divider(height: 1, thickness: 1),
          _buildSimpleShutubaList(context),
        ],
      ),
    );
  }

  Widget _buildRaceHeader(BuildContext context) {
    final gradeColor = getGradeColor(widget.predictionRaceData.raceGrade ?? '');

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.predictionRaceData.raceNumber}R',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.predictionRaceData.raceName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.predictionRaceData.raceGrade != null && widget.predictionRaceData.raceGrade!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.predictionRaceData.raceGrade!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12.0,
            runSpacing: 4.0,
            children: [
              Text('発走: ${widget.predictionRaceData.startTime ?? "-"}'),
              Text('${widget.predictionRaceData.trackType ?? ""}${widget.predictionRaceData.distanceValue ?? ""}m (${widget.predictionRaceData.direction ?? ""} ${widget.predictionRaceData.courseInOut ?? ""})'),
              Text('天候: ${widget.predictionRaceData.weather ?? "-"}'),
              Text('馬場: ${widget.predictionRaceData.trackCondition ?? "-"}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.predictionRaceData.venue} ${widget.predictionRaceData.holdingTimes ?? ""} ${widget.predictionRaceData.holdingDays ?? ""} / ${widget.predictionRaceData.raceCategory ?? ""} / ${widget.predictionRaceData.horseCount ?? ""}頭',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            '本賞金: ${widget.predictionRaceData.basePrize1st ?? "-"}, ${widget.predictionRaceData.basePrize2nd ?? "-"}, ${widget.predictionRaceData.basePrize3rd ?? "-"}, ${widget.predictionRaceData.basePrize4th ?? "-"}, ${widget.predictionRaceData.basePrize5th ?? "-"}万円',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          // [追加] コース平面図表示 (v.1.0)
          _buildCourseDiagramSection(),
          _buildElevationChartSection(),
          _buildDetailedTrackCondition(),
          const SizedBox(height: 12),
          _buildJmaWeather(),
          const SizedBox(height: 12),
          _buildPinpointWeather(),
        ],
      ),
    );
  }

  // [追加] コース平面図表示 (v.1.0)
  Widget _buildCourseDiagramSection() {
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : null;

    final distance = int.tryParse(widget.predictionRaceData.distanceValue?.toString() ?? '');

    if (venueCode == null || distance == null) return const SizedBox.shrink();

    final trackTypeKey = _mapToTrackTypeKey();

    // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
    // RaceCourseData.approachPathから合流点までの相対ベクトル(角度・距離)を取得し、Painterへ渡す
    var raceCourse = CourseElevations.findRaceCourse(venueCode, distance, trackTypeKey);
    if (raceCourse == null && trackTypeKey == 'shiba') {
      raceCourse = CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
    }
    final approachPaths = raceCourse?.approachPath;

    return FutureBuilder<CourseDiagramData?>(
      future: CourseDiagramService.instance.getCourseDiagram(venueCode, distance, trackTypeKey),
      builder: (context, snapshot) {
        final diagram = snapshot.data;
        if (diagram == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AspectRatio(
                aspectRatio: diagram.imageInfo.width / diagram.imageInfo.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(diagram.imageAsset, fit: BoxFit.contain),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CourseDiagramPainter(
                          diagram: diagram,
                          raceDistance: distance,
                          approachPaths: approachPaths, // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildElevationChartSection() {
    debugPrint('[Debug] raceId=${widget.predictionRaceData.raceId}, dist=${widget.predictionRaceData.distanceValue}, track=${widget.predictionRaceData.trackType}, venueCode=${widget.predictionRaceData.raceId.length >= 6 ? widget.predictionRaceData.raceId.substring(4, 6) : "null"}');
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : null;

    final distance = int.tryParse(widget.predictionRaceData.distanceValue?.toString() ?? '');

    if (venueCode == null || distance == null) return const SizedBox.shrink();

    final trackTypeKey = _mapToTrackTypeKey();
    debugPrint('[Debug] findRaceCourse params: venueCode=$venueCode, distance=$distance, trackTypeKey=$trackTypeKey, '
        'rawTrackType=${widget.predictionRaceData.trackType}, rawDirection=${widget.predictionRaceData.direction}, '
        'rawCourseInOut=${widget.predictionRaceData.courseInOut}, raceDetails1=${widget.predictionRaceData.raceDetails1}');
    var raceCourse = CourseElevations.findRaceCourse(venueCode, distance, trackTypeKey);

    // [追加] JRAのraceData01表記では内回りがデフォルトで明記されず、外回りのみ「外」が
    // 付与されるため、courseInOutに「外」「内」「直」のいずれも含まれない場合
    // (=trackTypeKeyが'shiba'のまま)で見つからない時は内回りとして再検索する。
    // 内外回りの区別がないコース(東京・小倉・福島・函館・札幌・中京)は
    // 'shiba'キーで一致するため、このフォールバックは発火しない。 (v.13.41.2)
    if (raceCourse == null && trackTypeKey == 'shiba') {
      raceCourse = CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
    }

    debugPrint('[Debug] findRaceCourse result: raceCourse=${raceCourse == null ? "null" : "${raceCourse.baseData.trackType} ${raceCourse.raceDistance}m"}');

    if (raceCourse == null) return const SizedBox.shrink();

    final drawData = ElevationLogic.generateRaceChartData(raceCourse);

    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 8, bottom: 4),
            child: SizedBox(
              height: 30,
              child: Row(
                children: drawData.displaySections.map((sec) {
                  final d = sec.endDistance - sec.startDistance;
                  return Expanded(
                    flex: (d * 10).toInt(),
                    child: Center(
                      child: Text(
                        ElevationLogic.translateSectionName(sec.name),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(
            height: 140,
            child: _buildRaceChart(raceCourse, drawData),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceChart(RaceCourseData race, ChartDrawData drawData) {
    final raceDist = race.raceDistance.toDouble();
    double minY = drawData.spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1.0;
    double maxY = drawData.spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1.5;

    final List<VerticalLine> vLines = [];
    final List<VerticalRangeAnnotation> ranges = [];
    final stripeColors = [Colors.black.withValues(alpha: 0.01), Colors.black.withValues(alpha: 0.03)];

    for (int i = 0; i < drawData.displaySections.length; i++) {
      final sec = drawData.displaySections[i];
      vLines.add(VerticalLine(x: sec.startDistance, color: Colors.black12, strokeWidth: 0.5, dashArray: [4, 4]));
      ranges.add(VerticalRangeAnnotation(x1: sec.startDistance, x2: sec.endDistance, color: stripeColors[i % 2]));
    }

    // 右回りコースはx軸が反転しているため、スタート(青)/ゴール(赤)の
    // ラインも左右を入れ替える。
    final startX = race.isLeftHanded ? 0.0 : raceDist;
    final goalX = race.isLeftHanded ? raceDist : 0.0;
    vLines.add(VerticalLine(x: startX, color: Colors.blueAccent.withValues(alpha: 0.5), strokeWidth: 2));
    vLines.add(VerticalLine(x: goalX, color: Colors.redAccent.withValues(alpha: 0.5), strokeWidth: 2));

    return LineChart(
      LineChartData(
        minX: 0, maxX: raceDist, minY: minY, maxY: maxY,
        gridData: FlGridData(
          show: true,
          verticalInterval: 200,
          horizontalInterval: 0.5,
          getDrawingVerticalLine: (_) => const FlLine(color: Colors.black12, strokeWidth: 0.5),
          getDrawingHorizontalLine: (value) {
            if (value % 1.0 == 0.0) {
              return FlLine(color: Colors.blueAccent.withValues(alpha: 0.3), strokeWidth: 0.8);
            }
            return const FlLine(color: Colors.black12, strokeWidth: 0.5, dashArray: [3, 3]);
          },
        ),
        rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: ranges),
        extraLinesData: ExtraLinesData(verticalLines: vLines),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 22, interval: 400,
              getTitlesWidget: (val, _) {
                if (val < 0 || val > raceDist) return const SizedBox.shrink();
                // 右回りコースはx軸が反転している(x=0がゴール側)ため、
                // 距離表示も「スタートからの距離」になるよう反転させる。
                final displayVal = race.isLeftHanded ? val : raceDist - val;
                return Text('${displayVal.toInt()}m', style: const TextStyle(color: Colors.black38, fontSize: 8));
              },
            ),
          ),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 0.5,
                  getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(1)}m', style: const TextStyle(color: Colors.black38, fontSize: 8))
              )
          ),
        ),
        lineBarsData: [LineChartBarData(
            spots: drawData.spots,
            isCurved: true,
            gradient: drawData.lineGradient,
            barWidth: 2.0,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: drawData.areaGradient)
        )],
        lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItems: (ss) => ss.map((s) {
                  // 右回りコースはx軸が反転している(x=0がゴール側)ため、
                  // ツールチップの距離表示も「スタートからの距離」になるよう反転させる。
                  final displayX = race.isLeftHanded ? s.x : raceDist - s.x;
                  return LineTooltipItem('${displayX.toInt()}m\n${s.y.toStringAsFixed(2)}m', const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold));
                }).toList()
            )
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
      ),
    );
  }

  Widget _buildDetailedTrackCondition() {
    if (_trackConditionFuture == null) return const SizedBox.shrink();

    return FutureBuilder<TrackConditionRecord?>(
      future: _trackConditionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('馬場詳細データを取得中...', style: TextStyle(fontSize: 12, color: Colors.black54)),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final record = snapshot.data!;
        final dateStr = record.date.replaceAll('-', '/');
        final venueName = '${widget.predictionRaceData.venue}競馬場';

        return Container(
          margin: const EdgeInsets.only(top: 12.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grass, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('$venueName ($dateStr)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('クッション値', '${record.cushionValue ?? "-"}'),
                  _buildTrackConditionItem('芝含水率 (G / 4C)', '${record.moistureTurfGoal ?? "-"}% / ${record.moistureTurf4c ?? "-"}%'),
                  _buildTrackConditionItem('ダ含水率 (G / 4C)', '${record.moistureDirtGoal ?? "-"}% / ${record.moistureDirt4c ?? "-"}%'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJmaWeather() {
    return FutureBuilder<Map<String, String>?>(
      future: _jmaWeatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.public, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('気象庁 広域天気概況', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  Text('${data['reportDatetime']} 発表', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data['overviewText'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyWeather(List<dynamic> dailyData) {
    if (dailyData.isEmpty) return const SizedBox.shrink();

    DateTime? raceDate;
    final rMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(widget.predictionRaceData.raceDate);
    if (rMatch != null) {
      raceDate = DateTime(int.parse(rMatch.group(1)!), int.parse(rMatch.group(2)!), int.parse(rMatch.group(3)!));
    }

    List<dynamic> targetWeekData = dailyData;
    if (raceDate != null) {
      final monday = raceDate.subtract(Duration(days: raceDate.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      targetWeekData = dailyData.where((d) {
        final dateDt = DateTime.tryParse(d['date']);
        if (dateDt == null) return false;
        final compareDate = DateTime(dateDt.year, dateDt.month, dateDt.day);
        return !compareDate.isBefore(monday) && !compareDate.isAfter(sunday);
      }).toList();
    }

    if (targetWeekData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📅 レース開催週の天候推移', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: targetWeekData.map((d) {
              final dateDt = DateTime.tryParse(d['date']);
              final dateStr = dateDt != null ? '${dateDt.month}/${dateDt.day}' : d['date'];
              final precip = (d['precipitationSum'] as num).toDouble();
              return Container(
                width: 55,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(WeatherAnalyzer.getWeatherText(d['weatherCode']).substring(0, 1), style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${d['tempMax'].toStringAsFixed(0)}/${d['tempMin'].toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(precip > 0 ? '${precip}mm' : '-', style: TextStyle(fontSize: 9, fontWeight: precip > 0 ? FontWeight.bold : FontWeight.normal, color: precip > 0 ? Colors.blue : Colors.black38)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // [追加] JRA発表予測の専用バッジUI (v.4.0)
  Widget _buildJraPredictionBadge(JraConditionPrediction prediction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: prediction.color.withOpacity(0.08),
        border: Border.all(color: prediction.color.withOpacity(0.6), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: prediction.color, size: 20),
          const SizedBox(width: 8),
          const Text("JRA公式 馬場予測:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(width: 8),
          Text(prediction.conditionText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: prediction.color)),
          if (prediction.leaningText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(prediction.leaningText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: prediction.color.withOpacity(0.8))),
            ),
        ],
      ),
    );
  }

  Widget _buildPinpointWeather() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _pinpointWeatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final current = data['current'];
        final raceTime = data['raceTime'];
        final List<dynamic> timeline = data['timeline'] ?? [];
        final List<dynamic> dailyData = data['daily'] ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.teal.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text('${widget.predictionRaceData.venue}競馬場 ピンポイント詳細', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ],
                  ),
                  if (_isWeatherLocked())
                    const Text('当時のデータ', style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Colors.teal),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _loadAllData(forceRefresh: true);
                      },
                    ),
                ],
              ),
              const Divider(),

              if (dailyData.isNotEmpty)
                _buildWeeklyWeather(dailyData),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('📍 現在の状況', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${current['time']} 現在)', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('天気', WeatherAnalyzer.getWeatherText(current['weatherCode'] ?? 0)),
                  _buildTrackConditionItem('気温', '${current['temp']}℃'),
                  _buildTrackConditionItem('湿度', '${current['humidity']}%'),
                  _buildTrackConditionItem('降水量', '${current['precipitation']} mm'),
                  _buildTrackConditionItem('風速', '${current['windSpeed']} m/s'),
                  _buildTrackConditionItem('風向き', current['windDirText']),
                ],
              ),
              const SizedBox(height: 12),
              Text('🏁 発走時刻 (${_getFormattedRaceTime()}) の予報', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('天気', WeatherAnalyzer.getWeatherText(raceTime['weatherCode'] ?? 0)),
                  _buildTrackConditionItem('気温', '${raceTime['temp']}℃'),
                  _buildTrackConditionItem('湿度', '${raceTime['humidity']}%'),
                  _buildTrackConditionItem('降水確率', '${raceTime['pop']}%'),
                  _buildTrackConditionItem('降水量', '${raceTime['precipitation']} mm'),
                  _buildTrackConditionItem('風速', '${raceTime['windSpeed']} m/s'),
                  _buildTrackConditionItem('風向き', data['windDirText']),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data['windAnalysis'],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('📊 馬場・展開インサイト', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${widget.predictionRaceData.startTime ?? "15:45"}の予報に基づく)',
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.normal)),
                ],
              ),
              const SizedBox(height: 8),

              FutureBuilder<TrackConditionRecord?>(
                future: _trackConditionFuture,
                builder: (context, trackSnapshot) {
                  final trackRecord = trackSnapshot.data;
                  final String venueCode = widget.predictionRaceData.raceId.length >= 6
                      ? widget.predictionRaceData.raceId.substring(4, 6)
                      : '00';

                  // [修正] 返却型 WeatherAnalysisResult の展開と UI統合 (v.4.0)
                  final analysisResult = WeatherAnalyzer.analyzeTrackConditionInsights(
                    venueCode: venueCode,
                    trackType: widget.predictionRaceData.trackType ?? '芝',
                    currentRecord: trackRecord,
                    cachedRecord: _cachedPrevRecord,
                    expectedPrecipitation: (raceTime['precipitation'] as num?)?.toDouble() ?? 0.0,
                    expectedRadiation: (raceTime['radiation'] as num?)?.toDouble() ?? 0.0,
                    expectedSoilMoisture: (raceTime['soilMoisture'] as num?)?.toDouble(),
                    dailyWeather: dailyData,
                    raceDateStr: widget.predictionRaceData.raceDate,
                  );

                  final insightsList = [
                    WeatherAnalyzer.analyzeTrackRecovery(raceTime['radiation'] ?? 0.0, raceTime['evap'] ?? 0.0),
                    WeatherAnalyzer.analyzeHorseStamina(raceTime['apparentTemp'] ?? 0.0, (raceTime['humidity'] ?? 0).toDouble()),
                    WeatherAnalyzer.analyzeRaceRisk((raceTime['gusts'] ?? 0.0) / 3.6, raceTime['visibility'] ?? 20.0),
                    ...analysisResult.insights,
                  ];

                  return Column(
                    children: [
                      // JRA予測バッジをインサイト一覧の先頭に表示
                      if (analysisResult.jraPrediction != null)
                        _buildJraPredictionBadge(analysisResult.jraPrediction!),

                      ...insightsList.map((insight) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: insight.color.withOpacity(0.05),
                          border: Border(left: BorderSide(color: insight.color, width: 4)),
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(insight.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: insight.color)),
                                Text(insight.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(insight.description, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
                          ],
                        ),
                      )),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              const Text('🕒 午後の時系列変化', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: timeline.map((t) {
                    final double precip = (t['precipitation'] as num?)?.toDouble() ?? 0.0;
                    return Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Text(t['time'], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(WeatherAnalyzer.getWeatherText(t['weatherCode'] ?? 0).substring(0, 1), style: const TextStyle(fontSize: 10, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('${t['temp']}℃', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${t['pop']}%', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          if (precip > 0)
                            Text('${precip}mm', style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
                          Text('${t['windSpeed']}m', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackConditionItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSimpleShutubaList(BuildContext context) {
    final List<PredictionHorseDetail> displayHorses = List.from(widget.horses);
    displayHorses.sort((a, b) {
      if (a.horseNumber > 0 && b.horseNumber > 0) {
        return a.horseNumber.compareTo(b.horseNumber);
      }
      if (a.horseNumber > 0 && b.horseNumber <= 0) return -1;
      if (a.horseNumber <= 0 && b.horseNumber > 0) return 1;
      return a.horseName.compareTo(b.horseName);
    });
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: displayHorses.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final horse = displayHorses[index];
        final bool isLowOdds = horse.odds != null && horse.odds! <= 9.9;
        final Color oddsColor = isLowOdds ? Colors.red : Colors.black87;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            children: [
              widget.buildHorseNumber(horse.horseNumber, horse.gateNumber),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: KeyedSubtree(
                  key: ValueKey('${horse.horseId}_${horse.userMark.hashCode}'),
                  child: widget.buildMarkDropdown(horse),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 13,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text('${horse.sexAndAge ?? ""} ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(horse.horseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 10,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${horse.jockey} ${horse.carriedWeight}kg', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(horse.odds != null ? '${horse.odds}倍' : '---', style: TextStyle(fontWeight: FontWeight.bold, color: oddsColor)),
                    const SizedBox(height: 2),
                    Text(horse.popularity != null ? '${horse.popularity}人気' : '---', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}