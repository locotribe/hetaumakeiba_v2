// lib/widgets/shutuba_tabs/race_simulation_view.dart
// [改修] 展開予想アニメーション デュアルビュー設計 (v.2.0)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/logic/elevation_logic.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/course_diagram_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_camera_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_elevation_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_painter.dart';

/// 展開予想アニメーションのデュアルビュー表示ウィジェット。
///
/// 上部に全体俯瞰マップ（コース平面図＋先頭馬の光るドット）、
/// 下部にメインカメラビュー（進行方向固定・自動ズームした馬群表示）を表示する。
class RaceSimulationView extends StatefulWidget {
  final CourseDiagramData diagram;
  final RaceSimulationData simulationData;
  final double raceDistance;
  final List<CourseApproach>? approachPaths;
  final bool isLeftHanded;
  final String trackTypeKey;
  final RaceCourseData? raceCourse;

  const RaceSimulationView({
    super.key,
    required this.diagram,
    required this.simulationData,
    required this.raceDistance,
    this.approachPaths,
    required this.isLeftHanded,
    required this.trackTypeKey,
    this.raceCourse,
  });

  @override
  State<RaceSimulationView> createState() => _RaceSimulationViewState();
}

class _RaceSimulationViewState extends State<RaceSimulationView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final CourseApproach? _approach;
  late final Path _trackPath;
  late final Path _infieldPath;
  late final Path _railPath;
  late final ChartDrawData? _elevationData;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.simulationData.totalTime * 1000).round(),
      ),
    );
    _controller.addStatusListener(_onStatusChanged);

    _approach =
        (widget.approachPaths != null && widget.approachPaths!.isNotEmpty)
            ? widget.approachPaths!.first
            : null;
    _trackPath = RaceSimulationCameraPainter.buildTrackPath(
      coords: widget.diagram.coords,
      raceDistance: widget.raceDistance,
      approach: _approach,
    );
    _infieldPath = RaceSimulationCameraPainter.buildInfieldPath(
      coords: widget.diagram.coords,
    );
    _railPath = RaceSimulationCameraPainter.buildRailPath(
      coords: widget.diagram.coords,
    );
    _elevationData = widget.raceCourse != null
        ? ElevationLogic.generateRaceChartData(widget.raceCourse!)
        : null;
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    if (_controller.isAnimating) {
      _controller.stop();
    } else {
      if (_controller.status == AnimationStatus.completed) {
        _controller.value = 0.0;
      }
      _controller.forward();
    }
  }

  /// currentTime時点での先頭馬(distanceFromGoal最小)のdistanceFromGoalを
  /// 求める。ミニマップ([RaceSimulationMinimapPainter])・メインカメラ
  /// ([RaceSimulationCameraPainter])と同一の基準であり、高低差グラフの
  /// 光る点をこれらと同じコース上の地点に同期させるために使う。
  double _leaderDistanceFromGoal(double currentTime) {
    double minDist = double.infinity;
    for (final track in widget.simulationData.horseTracks) {
      final frame = track.frameAt(
        currentTime,
        widget.diagram.coords,
        widget.raceDistance,
        _approach,
        RaceSimulationEngine.laneSpacingPx,
        RaceSimulationEngine.innerMarginPx,
      );
      if (frame.distanceFromGoal < minDist) minDist = frame.distanceFromGoal;
    }
    return minDist;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 上部: 全体俯瞰マップ ──
        Container(
          margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: AspectRatio(
            aspectRatio:
                widget.diagram.imageInfo.width / widget.diagram.imageInfo.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(widget.diagram.imageAsset, fit: BoxFit.contain),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: CourseDiagramPainter(
                      diagram: widget.diagram,
                      raceDistance: widget.raceDistance.round(),
                      approachPaths: widget.approachPaths,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final currentTime =
                          _controller.value * widget.simulationData.totalTime;
                      return CustomPaint(
                        painter: RaceSimulationMinimapPainter(
                          diagram: widget.diagram,
                          raceDistance: widget.raceDistance,
                          approach: _approach,
                          simulationData: widget.simulationData,
                          currentTime: currentTime,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 高低差グラフ(現在位置の光る点を同期表示) ──
        if (_elevationData != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 18,
                  child: Row(
                    children: _elevationData!.displaySections.map((sec) {
                      final d = sec.endDistance - sec.startDistance;
                      return Expanded(
                        flex: (d * 10).toInt(),
                        child: Center(
                          child: Text(
                            ElevationLogic.translateSectionName(sec.name),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final currentTime =
                          _controller.value * widget.simulationData.totalTime;
                      return CustomPaint(
                        painter: RaceSimulationElevationPainter(
                          drawData: _elevationData!,
                          sections: _elevationData!.displaySections,
                          raceDistance: widget.raceDistance,
                          isLeftHanded: widget.isLeftHanded,
                          currentDistanceFromGoal:
                              _leaderDistanceFromGoal(currentTime),
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // ── メインカメラビュー ──
        Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final currentTime =
                  _controller.value * widget.simulationData.totalTime;
              return CustomPaint(
                painter: RaceSimulationCameraPainter(
                  coords: widget.diagram.coords,
                  raceDistance: widget.raceDistance,
                  approach: _approach,
                  simulationData: widget.simulationData,
                  currentTime: currentTime,
                  isLeftHanded: widget.isLeftHanded,
                  trackTypeKey: widget.trackTypeKey,
                  trackPath: _trackPath,
                  infieldPath: _infieldPath,
                  railPath: _railPath,
                  raceCourse: widget.raceCourse,
                  // コース描画の検証中は馬番号マーカーを一時OFF。
                  // 後で独立レイヤーとして復活させる。
                  showHorseMarkers: false,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),

        // ── 再生コントロール ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_controller.isAnimating ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Slider(
                      value: _controller.value,
                      onChanged: (v) {
                        _controller.stop();
                        _controller.value = v;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
