// lib/widgets/shutuba_tabs/race_simulation_view.dart
// [改修] 展開予想アニメーション デュアルビュー設計 (v.2.0)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/course_diagram_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_camera_painter.dart';
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

  const RaceSimulationView({
    super.key,
    required this.diagram,
    required this.simulationData,
    required this.raceDistance,
    this.approachPaths,
    required this.isLeftHanded,
    required this.trackTypeKey,
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

        // ── 下部: メインカメラビュー ──
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
                  // コース描画の検証中は馬番号マーカーを一時OFF。
                  // 後で独立レイヤーとして復活させる。
                  showHorseMarkers: false,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ],
    );
  }
}
