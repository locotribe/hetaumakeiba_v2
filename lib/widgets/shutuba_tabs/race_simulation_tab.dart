// lib/widgets/shutuba_tabs/race_simulation_tab.dart
// [追加] 展開予想アニメーション機能(MVP)のタブ (v.1.0)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/services/course_diagram_service.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_view.dart';

/// 「展開シミュ」タブ：コース平面図上で展開予想アニメーションを表示する。
class RaceSimulationTabWidget extends StatefulWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;

  const RaceSimulationTabWidget({
    super.key,
    required this.predictionRaceData,
    required this.horses,
  });

  @override
  State<RaceSimulationTabWidget> createState() =>
      _RaceSimulationTabWidgetState();
}

class _RaceSimulationLoadResult {
  final CourseDiagramData diagram;
  final List<CourseApproach>? approachPaths;
  final double raceDistance;
  final RaceSimulationData simulationData;
  final bool isLeftHanded;
  final String trackTypeKey;
  final RaceCourseData? raceCourse;

  const _RaceSimulationLoadResult({
    required this.diagram,
    required this.approachPaths,
    required this.raceDistance,
    required this.simulationData,
    required this.isLeftHanded,
    required this.trackTypeKey,
    required this.raceCourse,
  });
}

class _RaceSimulationTabWidgetState extends State<RaceSimulationTabWidget>
    with AutomaticKeepAliveClientMixin {
  final HorseRepository _horseRepo = HorseRepository();
  late Future<_RaceSimulationLoadResult?> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(RaceSimulationTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.predictionRaceData.raceId != oldWidget.predictionRaceData.raceId) {
      setState(() {
        _future = _load();
      });
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

  Future<_RaceSimulationLoadResult?> _load() async {
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : null;
    final distance = int.tryParse(
        widget.predictionRaceData.distanceValue?.toString() ?? '');
    if (venueCode == null || distance == null) return null;

    final trackTypeKey = _mapToTrackTypeKey();

    var raceCourse =
        CourseElevations.findRaceCourse(venueCode, distance, trackTypeKey);
    if (raceCourse == null && trackTypeKey == 'shiba') {
      raceCourse =
          CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
    }

    final diagram = await CourseDiagramService.instance
        .getCourseDiagram(venueCode, distance, trackTypeKey);
    if (diagram == null) return null;

    final activeHorses = widget.horses.where((h) => !h.isScratched).toList();
    if (activeHorses.isEmpty) return null;

    final allPastRecords = <String, List<HorseRaceRecord>>{};
    await Future.wait(activeHorses.map((horse) async {
      allPastRecords[horse.horseId] =
          await _horseRepo.getHorsePerformanceRecords(horse.horseId);
    }));

    final simulationData = await RaceSimulationEngine.build(
      raceData: widget.predictionRaceData,
      horses: activeHorses,
      allPastRecords: allPastRecords,
      raceCourse: raceCourse,
      raceDistance: distance.toDouble(),
    );
    if (simulationData == null) return null;

    return _RaceSimulationLoadResult(
      diagram: diagram,
      approachPaths: raceCourse?.approachPath,
      raceDistance: distance.toDouble(),
      simulationData: simulationData,
      // raceCourse未取得時は右回り扱い（JRAは右回りコースが多数派）
      isLeftHanded: raceCourse?.isLeftHanded ?? false,
      trackTypeKey: trackTypeKey,
      raceCourse: raceCourse,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<_RaceSimulationLoadResult?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data;
        if (result == null) {
          return const Center(child: Text('展開シミュレーションを表示できません'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: RaceSimulationView(
            diagram: result.diagram,
            simulationData: result.simulationData,
            raceDistance: result.raceDistance,
            approachPaths: result.approachPaths,
            isLeftHanded: result.isLeftHanded,
            trackTypeKey: result.trackTypeKey,
            raceCourse: result.raceCourse,
          ),
        );
      },
    );
  }
}
