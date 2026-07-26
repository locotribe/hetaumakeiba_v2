// lib/widgets/shutuba_tabs/race_simulation_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_simulation_params_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/cross_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/weather_analyzer.dart';
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
  // [追加] 0-9b-1 使用データカードの予測/過去平均ソース用（shutuba_table_page.dartから共有、天気取得の二重化を防ぐ） (v.2026.7.27+26072704)
  final Future<TrackConditionRecord?>? trackConditionFuture;
  final Future<Map<String, dynamic>?>? pinpointWeatherFuture;
  final TrackConditionRecord? cachedPrevRecord;

  const RaceSimulationTabWidget({
    super.key,
    required this.predictionRaceData,
    required this.horses,
    this.trackConditionFuture,
    this.pinpointWeatherFuture,
    this.cachedPrevRecord,
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
  // [追加] 0-9(b) 使用データカード表示用 (v.2026.7.27+26072703)
  final String? predictedPace;
  final String? trackConditionText;
  final double? cushionValue;
  final double? moistureValue;
  final double trackBias;
  final String? trackConditionDate;
  // [追加] 0-9b-1 クッション値/含水率の使用ソースラベル（実測(当日)/予測/過去平均） (v.2026.7.27+26072704)
  final String biasSourceLabel;

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
    this.predictedPace,
    this.trackConditionText,
    this.cushionValue,
    this.moistureValue,
    this.trackBias = 0.0,
    this.trackConditionDate,
    this.biasSourceLabel = '—',
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
    // [追加] 0-9b-1 トラックバイアス算出値の4ソース自動選択（優先順: 実測(当日)→予測→過去平均） (v.2026.7.27+26072704)
    double? selectedCushion;
    double? selectedMoisture;
    String? selectedDate;
    String biasSourceLabel = '—';

    final bool hasActualToday = isDirt
        ? trackConditionRecord?.moistureDirtGoal != null
        : (trackConditionRecord?.cushionValue != null ||
            trackConditionRecord?.moistureTurfGoal != null);

    if (hasActualToday) {
      // 1. 実測(当日): 既存のprefix10一致レコード(前週等へのフォールバックはしない)
      selectedCushion = trackConditionRecord?.cushionValue;
      selectedMoisture = isDirt
          ? trackConditionRecord?.moistureDirtGoal
          : trackConditionRecord?.moistureTurfGoal;
      biasSourceLabel = '実測(当日)';
      selectedDate = trackConditionRecord?.date;
    } else {
      // 2. 予測: weather_analyzerの既存算出結果を再利用（天気取得自体はshutuba_table_page.dartで1回のみ）
      double? predictedCushion;
      double? predictedMoisture;
      if (widget.pinpointWeatherFuture != null &&
          widget.trackConditionFuture != null) {
        try {
          final pinpointData = await widget.pinpointWeatherFuture;
          final baselineRecord = await widget.trackConditionFuture;
          final raceTime = pinpointData?['raceTime'];
          if (raceTime != null && baselineRecord != null) {
            final analysisResult = WeatherAnalyzer.analyzeTrackConditionInsights(
              venueCode: venueCode,
              trackType: widget.predictionRaceData.trackType ?? '芝',
              currentRecord: baselineRecord,
              cachedRecord: widget.cachedPrevRecord,
              expectedPrecipitation:
                  (raceTime['precipitation'] as num?)?.toDouble() ?? 0.0,
              expectedRadiation:
                  (raceTime['radiation'] as num?)?.toDouble() ?? 0.0,
              expectedSoilMoisture:
                  (raceTime['soilMoisture'] as num?)?.toDouble(),
              dailyWeather: pinpointData?['daily'] ?? const [],
              raceDateStr: widget.predictionRaceData.raceDate,
            );
            predictedCushion = analysisResult.predictedCushion;
            predictedMoisture = analysisResult.predictedMoisture;
          }
        } catch (_) {
          predictedCushion = null;
          predictedMoisture = null;
        }
      }

      if (predictedMoisture != null) {
        selectedCushion = isDirt ? null : predictedCushion;
        selectedMoisture = predictedMoisture;
        biasSourceLabel = '予測';
      } else {
        // 3. 過去平均: 当該競馬場の直近レコードから新規に軽量算出
        final recentRecords = await _trackConditionRepo
            .getRecentTrackConditionsForVenue(venueCode);
        final trendMap = {
          for (final r in recentRecords) r.trackConditionId.toString(): r
        };
        final trend = TrackConditionTrendAnalyzer().analyze(trendMap);
        final avgMoisture =
            isDirt ? trend.avgDirtMoisture : trend.avgTurfMoisture;
        if (avgMoisture > 0 || trend.avgCushion > 0) {
          selectedCushion =
              isDirt ? null : (trend.avgCushion > 0 ? trend.avgCushion : null);
          selectedMoisture = avgMoisture > 0 ? avgMoisture : null;
          biasSourceLabel = '過去平均';
        }
      }
    }

    final trackBias = (selectedCushion != null || selectedMoisture != null)
        ? RaceAnalyzer.calcTrackBias(
            cushionValue: selectedCushion,
            moistureTurfGoal: isDirt ? null : selectedMoisture,
            moistureDirtGoal: isDirt ? selectedMoisture : null,
            isDirt: isDirt,
          )
        : 0.0;

    // [追加] 0-9(b) 使用データカード表示用の値を用意 (v.2026.7.27+26072703)
    final predictedPace =
        widget.predictionRaceData.racePacePrediction?.predictedPace;
    final trackConditionText = widget.predictionRaceData.trackCondition;
    final cushionValue = selectedCushion;
    final moistureValue = selectedMoisture;
    final trackConditionDate = selectedDate;

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
      // [追加] 0-9 馬場バイアス (v.2026.7.27+26072702)
      trackBias: trackBias,
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
      predictedPace: predictedPace,
      trackConditionText: trackConditionText,
      cushionValue: cushionValue,
      moistureValue: moistureValue,
      trackBias: trackBias,
      trackConditionDate: trackConditionDate,
      biasSourceLabel: biasSourceLabel,
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
            predictedPace: result.predictedPace,
            trackConditionText: result.trackConditionText,
            cushionValue: result.cushionValue,
            moistureValue: result.moistureValue,
            trackBias: result.trackBias,
            trackConditionDate: result.trackConditionDate,
            biasSourceLabel: result.biasSourceLabel,
          ),
        );
      },
    );
  }
}
