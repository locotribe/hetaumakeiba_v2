// lib/widgets/shutuba_tabs/race_simulation_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_simulation_params_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/simulation_params_calculator.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
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
  final Map<String, HorseSimulationParams> simulationParams;
  final List<PredictionHorseDetail> horses;

  const _RaceSimulationLoadResult({
    required this.diagram,
    required this.approachPaths,
    required this.raceDistance,
    required this.simulationData,
    required this.isLeftHanded,
    required this.trackTypeKey,
    required this.raceCourse,
    required this.simulationParams,
    required this.horses,
  });
}

class _RaceSimulationTabWidgetState extends State<RaceSimulationTabWidget>
    with AutomaticKeepAliveClientMixin {
  final HorseRepository _horseRepo = HorseRepository();
  final HorseSimulationParamsRepository _simParamsRepo =
      HorseSimulationParamsRepository();
  // [追加] 馬場状態補正用 (v2026.6.25)
  final TrackConditionRepository _trackConditionRepo =
      TrackConditionRepository();
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

    // [修正] raceId変更 or 更新ボタン押下後にlegStyleProfileが揃った場合に再ロード (v.13.43.0)
    final oldHasLegStyle =
        oldWidget.horses.any((h) => h.legStyleProfile != null);
    final newHasLegStyle =
        widget.horses.any((h) => h.legStyleProfile != null);

    if (widget.predictionRaceData.raceId != oldWidget.predictionRaceData.raceId ||
        (!oldHasLegStyle && newHasLegStyle)) {
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

  /// 馬場状態から速度補正係数を導出する（Cascade Fallback）。
  /// ① JRA公式 trackCondition → ② クッション値(芝)/含水率(ダート) → ③ 1.0（補正なし）
  static double _deriveTrackSpeedMultiplier({
    required String? trackConditionText,
    required bool isDirt,
    required TrackConditionRecord? record,
  }) {
    // ① JRA公式発表の馬場状態テキスト
    if (trackConditionText != null) {
      switch (trackConditionText) {
        case '良': return 1.00;
        case '稍重': return 1.03;
        case '重': return 1.06;
        case '不良': return 1.10;
      }
    }
    // ② TrackConditionRecord からの推定
    if (record != null) {
      if (isDirt) {
        final m = record.moistureDirtGoal;
        if (m != null) {
          if (m <= 9.0) return 1.00;   // 良(乾燥)
          if (m <= 13.0) return 1.03;  // 稍重相当
          if (m <= 16.0) return 1.06;  // 重相当
          return 1.10;                  // 不良相当
        }
      } else {
        // 芝: クッション値優先（良馬場内の速度差を区別できる唯一の指標）
        final c = record.cushionValue;
        if (c != null) {
          if (c >= 10.0) return 0.98;  // 高速良馬場
          if (c >= 9.0) return 1.00;   // 標準良
          if (c >= 8.0) return 1.02;   // 稍重傾向
          return 1.04;                  // 重傾向以上
        }
        // クッション値なし → 含水率で代替推定
        final m = record.moistureTurfGoal;
        if (m != null) {
          if (m <= 13.0) return 1.00;  // 良
          if (m <= 17.0) return 1.03;  // 稍重
          if (m <= 21.0) return 1.06;  // 重
          return 1.10;                  // 不良
        }
      }
    }
    // ③ データなし
    return 1.0;
  }

  Future<_RaceSimulationLoadResult?> _load() async {
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : null;
    final distance = int.tryParse(
        widget.predictionRaceData.distanceValue?.toString() ?? '');
    if (venueCode == null || distance == null) return null;

    final trackTypeKey = _mapToTrackTypeKey();

    // [追加] 馬場状態補正: prefix10でDBから当日のクッション値・含水率を取得 (v2026.6.25)
    final isDirt = trackTypeKey == 'dirt';
    TrackConditionRecord? trackConditionRecord;
    final raceIdStr = widget.predictionRaceData.raceId;
    if (raceIdStr.length >= 10) {
      trackConditionRecord = await _trackConditionRepo
          .getLatestTrackConditionByPrefix(raceIdStr.substring(0, 10));
    }
    final trackSpeedMultiplier = _deriveTrackSpeedMultiplier(
      trackConditionText: widget.predictionRaceData.trackCondition,
      isDirt: isDirt,
      record: trackConditionRecord,
    );

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

    final horsesForSim = activeHorses.every((h) => h.horseNumber == 0)
        ? RaceSimulationEngine.assignTempNumbers(activeHorses)
        : activeHorses;

    final allPastRecords = <String, List<HorseRaceRecord>>{};
    await Future.wait(horsesForSim.map((horse) async {
      allPastRecords[horse.horseId] =
          await _horseRepo.getHorsePerformanceRecords(horse.horseId);
    }));

    final horseIds = horsesForSim.map((h) => h.horseId).toList();
    final paramsByHorseId = await _simParamsRepo.getByHorseIds(horseIds);
    final simulationParams = <String, HorseSimulationParams>{};
    for (final horse in horsesForSim) {
      final params = paramsByHorseId[horse.horseId] ??
          SimulationParamsCalculator.calculate(
            horse.horseId,
            allPastRecords[horse.horseId] ?? [],
          );
      simulationParams[horse.horseNumber.toString()] = params;
    }

    final simulationData = await RaceSimulationEngine.build(
      raceData: widget.predictionRaceData,
      horses: horsesForSim,
      allPastRecords: allPastRecords,
      raceCourse: raceCourse,
      raceDistance: distance.toDouble(),
      simulationParams: simulationParams,
      // [追加] 馬場状態補正 (v2026.6.25)
      trackSpeedMultiplier: trackSpeedMultiplier,
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
      simulationParams: simulationParams,
      horses: horsesForSim,
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
            simulationParams: result.simulationParams,
            horses: result.horses,
          ),
        );
      },
    );
  }
}
