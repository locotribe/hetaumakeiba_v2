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

// [追加] 0-9b-2 重い取得(1回のみ)の結果をキャッシュする内部クラス (v.2026.7.27+26072705)
class _CachedSimInputs {
  final String venueCode;
  final int distance;
  final String trackTypeKey;
  final bool isDirt;
  final double trackSpeedMultiplier;
  final RaceCourseData? raceCourse;
  final CourseDiagramData diagram;
  final List<PredictionHorseDetail> horsesForSim;
  final Map<String, List<HorseRaceRecord>> allPastRecords;
  final Map<String, HorseSimulationParams> simulationParams;
  final String? predictedPace;
  final String? trackConditionText;
  final bool hasActualToday;
  final double? actualCushion;
  final double? actualMoisture;
  final String? actualDate;
  final double? predictedCushion;
  final double? predictedMoisture;
  final double? trendCushion;
  final double? trendMoisture;

  const _CachedSimInputs({
    required this.venueCode,
    required this.distance,
    required this.trackTypeKey,
    required this.isDirt,
    required this.trackSpeedMultiplier,
    required this.raceCourse,
    required this.diagram,
    required this.horsesForSim,
    required this.allPastRecords,
    required this.simulationParams,
    required this.predictedPace,
    required this.trackConditionText,
    required this.hasActualToday,
    required this.actualCushion,
    required this.actualMoisture,
    required this.actualDate,
    required this.predictedCushion,
    required this.predictedMoisture,
    required this.trendCushion,
    required this.trendMoisture,
  });
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

  // [追加] 0-9b-2 重い取得(Phase A)は1回のみ・build再実行(Phase B)はキャッシュ済み入力を使い回す (v.2026.7.27+26072705)
  Future<_CachedSimInputs?>? _inputsFuture;
  _CachedSimInputs? _cachedInputs;
  // [修正] 0-9b-2不具合修正 直前の表示結果を保持し、再ビルド中もスクロール領域ごと置換しないようにする (v.2026.7.27+26072706)
  _RaceSimulationLoadResult? _lastResult;
  bool _isRebuilding = false;

  // [修正] 0-9b-3 自由入力を廃止しペース手動選択に置き換え。クッション値/含水率のソース切替のみセッション内保持 (v.2026.7.27+26072707)
  TrackBiasSource _selectedSource = TrackBiasSource.actual;
  // [追加] 0-9b-3 ペース手動選択State。初期値はアプリ予想ペース（セッション内のみ保持） (v.2026.7.27+26072707)
  late String _selectedPace;

  // [追加] 0-9b-2不具合修正 スクロール位置を再ビルドをまたいで保持するコントローラー (v.2026.7.27+26072706)
  late final ScrollController _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // [追加] 0-9b-3 ペース手動選択の初期値はアプリ予想ペース (v.2026.7.27+26072707)
    _selectedPace = _appPredictedPace();
    _startLoad();
  }

  // [追加] 0-9b-3 アプリの予想ペースを取得（無ければミドルペース） (v.2026.7.27+26072707)
  String _appPredictedPace() {
    return widget.predictionRaceData.racePacePrediction?.predictedPace ??
        'ミドルペース';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        _cachedInputs = null;
        _lastResult = null;
        _isRebuilding = false;
        _selectedSource = TrackBiasSource.actual;
        // [修正] 0-9b-3 raceId変更時は新レースの予想ペースへリセット (v.2026.7.27+26072707)
        _selectedPace = _appPredictedPace();
        _startLoad();
      });
    }
  }

  // [追加] 0-9b-2 Phase A(重い取得)を起動し、完了後に自動ソース選択とPhase B(build)を1度だけ実行 (v.2026.7.27+26072705)
  void _startLoad() {
    final future = _fetchInputs();
    _inputsFuture = future;
    future.then((cached) {
      if (!mounted || cached == null) return;
      setState(() {
        _cachedInputs = cached;
        _selectedSource = _autoSelectSource(cached);
      });
      _triggerRebuild(cached);
    });
  }

  // [追加] 0-9b-2 0-9b-1と同じ優先順（実測(当日)>予測>過去平均）で初期ソースを決定 (v.2026.7.27+26072705)
  TrackBiasSource _autoSelectSource(_CachedSimInputs cached) {
    if (cached.hasActualToday) return TrackBiasSource.actual;
    if (cached.predictedMoisture != null) return TrackBiasSource.predicted;
    if (cached.trendCushion != null || cached.trendMoisture != null) {
      return TrackBiasSource.trend;
    }
    return TrackBiasSource.actual; // どのソースにも値がない場合のフォールバック('—'表示・trackBias=0)
  }

  // [修正] 0-9b-2不具合修正 Phase Bを実行し、完了後に直前の表示結果を差し替える（失敗時は直前の表示を維持） (v.2026.7.27+26072706)
  void _triggerRebuild(_CachedSimInputs cached) {
    setState(() {
      _isRebuilding = true;
    });
    _rebuild(cached).then((result) {
      if (!mounted) return;
      setState(() {
        _isRebuilding = false;
        if (result != null) {
          _lastResult = result;
        }
      });
    });
  }

  // [追加] 0-9b-2 ソース切替コールバック（再取得はせずPhase Bのみ再実行） (v.2026.7.27+26072705)
  void _onSourceChanged(TrackBiasSource source) {
    if (_cachedInputs == null) return;
    setState(() {
      _selectedSource = source;
    });
    _triggerRebuild(_cachedInputs!);
  }

  // [追加] 0-9b-3 ペース手動選択コールバック（再取得はせずPhase Bのみ再実行） (v.2026.7.27+26072707)
  void _onPaceChanged(String pace) {
    if (_cachedInputs == null) return;
    setState(() {
      _selectedPace = pace;
    });
    _triggerRebuild(_cachedInputs!);
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

  // [追加] 0-9b-2 Phase A: 重い取得(過去成績・コース図・パラメータ・馬場レコード・予測値・過去平均)を1回だけ行う (v.2026.7.27+26072705)
  Future<_CachedSimInputs?> _fetchInputs() async {
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

    // [追加] 0-9b-2 実測(当日)ソース候補値（トグル無効化判定にも使う） (v.2026.7.27+26072705)
    final bool hasActualToday = isDirt
        ? trackConditionRecord?.moistureDirtGoal != null
        : (trackConditionRecord?.cushionValue != null ||
            trackConditionRecord?.moistureTurfGoal != null);
    final double? actualCushion = trackConditionRecord?.cushionValue;
    final double? actualMoisture = isDirt
        ? trackConditionRecord?.moistureDirtGoal
        : trackConditionRecord?.moistureTurfGoal;
    final String? actualDate = trackConditionRecord?.date;

    // [追加] 0-9b-2 予測ソース候補値: weather_analyzerの既存算出結果を再利用（天気取得自体はshutuba_table_page.dartで1回のみ） (v.2026.7.27+26072705)
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
          predictedCushion = isDirt ? null : analysisResult.predictedCushion;
          predictedMoisture = analysisResult.predictedMoisture;
        }
      } catch (_) {
        predictedCushion = null;
        predictedMoisture = null;
      }
    }

    // [追加] 0-9b-2 過去平均ソース候補値: 当該競馬場の直近レコードから軽量算出 (v.2026.7.27+26072705)
    final recentRecords =
        await _trackConditionRepo.getRecentTrackConditionsForVenue(venueCode);
    final trendMap = {
      for (final r in recentRecords) r.trackConditionId.toString(): r
    };
    final trend = TrackConditionTrendAnalyzer().analyze(trendMap);
    final avgMoisture = isDirt ? trend.avgDirtMoisture : trend.avgTurfMoisture;
    final double? trendCushion =
        isDirt ? null : (trend.avgCushion > 0 ? trend.avgCushion : null);
    final double? trendMoisture = avgMoisture > 0 ? avgMoisture : null;

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

    return _CachedSimInputs(
      venueCode: venueCode,
      distance: distance,
      trackTypeKey: trackTypeKey,
      isDirt: isDirt,
      trackSpeedMultiplier: trackSpeedMultiplier,
      raceCourse: raceCourse,
      diagram: diagram,
      horsesForSim: horsesForSim,
      allPastRecords: allPastRecords,
      simulationParams: simulationParams,
      predictedPace: widget.predictionRaceData.racePacePrediction?.predictedPace,
      trackConditionText: widget.predictionRaceData.trackCondition,
      hasActualToday: hasActualToday,
      actualCushion: actualCushion,
      actualMoisture: actualMoisture,
      actualDate: actualDate,
      predictedCushion: predictedCushion,
      predictedMoisture: predictedMoisture,
      trendCushion: trendCushion,
      trendMoisture: trendMoisture,
    );
  }

  // [追加] 0-9b-2 Phase B: 選択中ソース(または自由入力)からtrackBiasを算出し、キャッシュ済み入力でRaceSimulationEngine.buildのみ再実行 (v.2026.7.27+26072705)
  Future<_RaceSimulationLoadResult?> _rebuild(_CachedSimInputs cached) async {
    double? selectedCushion;
    double? selectedMoisture;
    String? selectedDate;
    String biasSourceLabel;

    switch (_selectedSource) {
      case TrackBiasSource.actual:
        selectedCushion = cached.actualCushion;
        selectedMoisture = cached.actualMoisture;
        selectedDate = cached.actualDate;
        biasSourceLabel = '実測(当日)';
        break;
      case TrackBiasSource.predicted:
        selectedCushion = cached.predictedCushion;
        selectedMoisture = cached.predictedMoisture;
        biasSourceLabel = '予測';
        break;
      case TrackBiasSource.trend:
        selectedCushion = cached.trendCushion;
        selectedMoisture = cached.trendMoisture;
        biasSourceLabel = '過去平均';
        break;
    }

    final trackBias = (selectedCushion != null || selectedMoisture != null)
        ? RaceAnalyzer.calcTrackBias(
            cushionValue: selectedCushion,
            moistureTurfGoal: cached.isDirt ? null : selectedMoisture,
            moistureDirtGoal: cached.isDirt ? selectedMoisture : null,
            isDirt: cached.isDirt,
          )
        : 0.0;

    final simulationData = await RaceSimulationEngine.build(
      raceData: widget.predictionRaceData,
      horses: cached.horsesForSim,
      allPastRecords: cached.allPastRecords,
      raceCourse: cached.raceCourse,
      raceDistance: cached.distance.toDouble(),
      simulationParams: cached.simulationParams,
      // [追加] 馬場状態補正 (v2026.6.25)
      trackSpeedMultiplier: cached.trackSpeedMultiplier,
      // [追加] 0-9 馬場バイアス (v.2026.7.27+26072702)
      trackBias: trackBias,
      // [追加] 0-9b-3 ペース手動選択 (v.2026.7.27+26072707)
      paceOverride: _selectedPace,
    );
    if (simulationData == null) return null;

    return _RaceSimulationLoadResult(
      diagram: cached.diagram,
      approachPaths: cached.raceCourse?.approachPath,
      raceDistance: cached.distance.toDouble(),
      simulationData: simulationData,
      // raceCourse未取得時は右回り扱い（JRAは右回りコースが多数派）
      isLeftHanded: cached.raceCourse?.isLeftHanded ?? false,
      trackTypeKey: cached.trackTypeKey,
      raceCourse: cached.raceCourse,
      simulationParams: cached.simulationParams,
      horses: cached.horsesForSim,
      predictedPace: cached.predictedPace,
      trackConditionText: cached.trackConditionText,
      cushionValue: selectedCushion,
      moistureValue: selectedMoisture,
      trackBias: trackBias,
      trackConditionDate: selectedDate,
      biasSourceLabel: biasSourceLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<_CachedSimInputs?>(
      future: _inputsFuture,
      builder: (context, inputsSnapshot) {
        if (inputsSnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final cached = inputsSnapshot.data;
        if (cached == null) {
          return const Center(child: Text('展開シミュレーションを表示できません'));
        }
        // [修正] 0-9b-2不具合修正 直前の表示結果(_lastResult)が無い＝真の初回ロード待ちのときのみ
        // 全画面スピナーにする。ソース切替等の再ビルド中は前回の表示をそのまま保持する (v.2026.7.27+26072706)
        final result = _lastResult;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          // [修正] 0-9b-2不具合修正 State保持のControllerとPageStorageKeyでスクロール位置を維持 (v.2026.7.27+26072706)
          key: const PageStorageKey('race_simulation_scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [追加] 0-9b-2不具合修正 再ビルド中のみ表示する控えめなインライン表示 (v.2026.7.27+26072706)
              if (_isRebuilding)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              RaceSimulationView(
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
                // [追加] 0-9b-2 ソース切替の配線 (v.2026.7.27+26072705)
                selectedSource: _selectedSource,
                hasActualToday: cached.hasActualToday,
                onSourceChanged: _onSourceChanged,
                // [追加] 0-9b-3 ペース手動選択の配線 (v.2026.7.27+26072707)
                selectedPace: _selectedPace,
                onPaceChanged: _onPaceChanged,
              ),
            ],
          ),
        );
      },
    );
  }
}
