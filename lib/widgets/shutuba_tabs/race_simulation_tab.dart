// lib/widgets/shutuba_tabs/race_simulation_tab.dart
// [修正] 展開シミュゲーム式移植Step4b: 全面的に作り直した。計算を順位スコアの方式からゲーム式エンジン(多数回)に替え、
// 「シミュ／評価」の切り替えと評価(相対評価)を外した。画面は「再生・結果」「条件」「ステータス」のチップで切り替える。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の6章・7章 (v.2026.10.27+26102705)
// [修正] 展開シミュゲーム式移植Step5: 旧方式のエンジンを消したので、仮の馬番は GameRaceInputs.assignTempNumbers を使い、再生の旧方式の引数を外した (v.2026.10.27+26102709)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_simulation_params_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_speed_index_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/cross_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/early_position_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_ability_builder.dart';
// [追加] 展開シミュ改良Step2 (v.2026.10.28+26102802)
import 'package:hetaumakeiba_v2/logic/analysis/game_aptitude.dart';
// [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
import 'package:hetaumakeiba_v2/logic/analysis/game_course_rail.dart';
// [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
import 'package:hetaumakeiba_v2/logic/analysis/game_form.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_form_inputs.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_display.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_inputs.dart';
// [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
import 'package:hetaumakeiba_v2/logic/analysis/game_race_reasons.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_reference.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_simulator.dart';
// [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
import 'package:hetaumakeiba_v2/logic/analysis/game_race_tuning.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_finish_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/simulation_params_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/weather_analyzer.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
// [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/services/course_diagram_service.dart';
import 'package:hetaumakeiba_v2/services/race_entrant_data_service.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
// [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/game_sim_panels.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_view.dart';

/// 「展開シミュ」タブ：ゲーム式エンジンで多数回走らせ、勝率・複勝率と平均の走りの再生を出す。
class RaceSimulationTabWidget extends StatefulWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  // 馬場のデータの「予測」用(shutuba_table_page.dart から共有し、天気の取得を二重にしない)
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

/// 重い読み込み(1回だけ)の結果。
class _GameSimInputs {
  final int distance;
  final bool isDirt;
  final String trackTypeKey;
  final RaceCourseData? raceCourse;
  final CourseDiagramData diagram;
  final GameRaceCourse course;

  /// 走らせる馬(馬番の順。枠順の発表前は仮の馬番)
  final List<PredictionHorseDetail> horses;
  final bool gatesConfirmed;
  final List<GameHorseAbility> abilities;
  final List<double?> staminaIndexes;

  /// [追加] 展開シミュ改良Step7b: ステータスの表示用の能力値(調子を含まない地力。abilities は調子をかけた走らせる値) (v.2026.10.30+26103006)
  final List<GameHorseAbility> displayAbilities;

  /// [追加] 展開シミュ改良Step7b: 馬ごとの調子(調教から出した5段階) (v.2026.10.30+26103006)
  final List<GameFormResult> forms;

  /// [追加] 展開シミュ改良Step3(案C): 使用コースと内の馬場の傷み。表に無いレースは null (v.2026.10.28+26102803)
  final GameCourseRailInfo? railInfo;

  /// [追加] 展開シミュ改良Step3(案D): 出走馬の顔ぶれから当てた、いつものペースからのずれ(秒。正 = 遅い)。当てられなければ null (v.2026.10.28+26102803)
  final double? paceDeviation;

  /// [追加] 展開シミュ改良Step3: このレースのエンジンの設定の調整 (v.2026.10.28+26102803)
  /// [修正] 展開シミュ改良Step4: GameRaceTuning.of の決め直した値(勝率・3着以内率の補正も含む) (v.2026.10.29+26102901)
  final GameRaceTuning tuning;

  /// [追加] 展開シミュ改良Step5b(案E): なぜこの勝率か の材料。終盤の速度加算の内訳・適性の項・適性の重み (v.2026.10.29+26102903)
  final List<GameSpeedParts> speedParts;
  final List<Map<String, double>> aptitudeTerms;
  final Map<String, double> aptitudeWeights;

  /// 同じレース名・同じ競馬場・芝ダ・距離の過去レース(新しい順)
  final List<GamePastRaceTime> pastRaces;

  /// 当日に発表された馬場状態。無ければ null
  final String? officialGoing;
  final bool hasActualToday;
  final double? actualCushion;
  final double? actualMoisture;
  final double? predictedCushion;
  final double? predictedMoisture;
  final double? trendCushion;
  final double? trendMoisture;

  const _GameSimInputs({
    required this.distance,
    required this.isDirt,
    required this.trackTypeKey,
    required this.raceCourse,
    required this.diagram,
    required this.course,
    required this.horses,
    required this.gatesConfirmed,
    required this.abilities,
    required this.staminaIndexes,
    // [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
    required this.displayAbilities,
    required this.forms,
    // [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
    required this.railInfo,
    required this.paceDeviation,
    required this.tuning,
    // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
    required this.speedParts,
    required this.aptitudeTerms,
    required this.aptitudeWeights,
    required this.pastRaces,
    required this.officialGoing,
    required this.hasActualToday,
    required this.actualCushion,
    required this.actualMoisture,
    required this.predictedCushion,
    required this.predictedMoisture,
    required this.trendCushion,
    required this.trendMoisture,
  });

  bool get hasPredicted => predictedCushion != null || predictedMoisture != null;
  bool get hasTrend => trendCushion != null || trendMoisture != null;
}

/// 今出している100回の結果と、そのときの条件。
class _ShownResult {
  final GameRaceSummary summary;

  /// 走らせたときのペース倍率
  final double paceMult;

  /// 走らせたときの馬場状態
  final String going;

  /// 同じ馬場状態で、既定のペースで走らせたときの勝ち時計の平均(ゲームの単位)。時計の換算の基準
  final double baselineWinnerTime;

  /// [追加] 展開シミュゲーム式移植Step4c: 同じ馬場状態で、既定のペースで走らせたときの先頭の1000m通過の平均(ゲームの単位)。
  /// 過去の1000m通過が無いときのスライダーの範囲の基準 (v.2026.10.27+26102706)
  final double? baselineLeader1000;

  const _ShownResult({
    required this.summary,
    required this.paceMult,
    required this.going,
    required this.baselineWinnerTime,
    required this.baselineLeader1000,
  });
}

class _RaceSimulationTabWidgetState extends State<RaceSimulationTabWidget>
    with AutomaticKeepAliveClientMixin {
  final HorseSimulationParamsRepository _simParamsRepo =
      HorseSimulationParamsRepository();
  final HorseSpeedIndexRepository _speedIndexRepo = HorseSpeedIndexRepository();
  final TrackConditionRepository _trackConditionRepo =
      TrackConditionRepository();
  final RaceRepository _raceRepo = RaceRepository();

  /// 走らせる回数
  static const int _runs = GameRaceSimulator.defaultRuns;

  /// スライダーの範囲を、初期値から最低でもこの秒数は外へ取る
  static const double _sliderPad = 0.5;

  /// 1000m通過からペース倍率を求めるときの補正の強さ(通過の比のこの乗数)。
  /// 比そのまま(1乗)だと、ねらいの約75%しか動かない。1.3乗で、ねらい±2.5秒でも0.2秒以内に入った(試験台の東京芝2000m・ダート1600mで実測)
  static const double _paceCorrectionPower = 1.3;

  /// 過去の1000m通過が無いときの、1000m通過のスライダーの幅(シミュの値から ± 秒)
  static const double _first1000FallbackHalf = 3.0;

  Future<_GameSimInputs?>? _inputsFuture;
  _GameSimInputs? _inputs;

  TrackBiasSource _source = TrackBiasSource.actual;
  String _going = '良';
  double? _cushion;
  double? _winnerSeconds;

  /// 1000m通過のスライダーで選んだ値(秒)。null のときは今の結果の値を出す
  double? _first1000Target;

  _ShownResult? _shown;
  bool _isRunning = false;
  String? _runError;

  /// [追加] 展開シミュ改良Step5b(案E): 計算中の途中の結果(終わった組の分)。計算中でなければ null (v.2026.10.29+26102903)
  GameRaceProgress? _progress;

  /// [追加] 展開シミュ改良Step5b: 計算の番号。古い計算の途中の結果を出さないために使う (v.2026.10.29+26102903)
  int _runToken = 0;

  /// 再生に出している1回
  RaceSimulationData? _playData;

  /// [追加] 展開シミュゲーム式移植Step4c: 再生に出している1回の記録(「この再生の結果」の表に使う) (v.2026.10.27+26102706)
  GameRaceRunResult? _playRun;
  int _playId = 0;
  int _altCount = 0;
  bool _isAltRun = false;

  /// 出している区分(0=再生・結果、1=条件、2=ステータス)
  int _section = 0;

  static const List<String> _sectionLabels = ['再生・結果', '条件', 'ステータス'];

  /// 枠順の発表前に再生と表で使う枠番(白で統一し、枠の色をつけない)
  static const int _plainGate = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(RaceSimulationTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // レースが変わったとき、または脚質の情報が後から揃ったときに読み直す
    final oldHasLegStyle =
        oldWidget.horses.any((h) => h.legStyleProfile != null);
    final newHasLegStyle =
        widget.horses.any((h) => h.legStyleProfile != null);
    if (widget.predictionRaceData.raceId != oldWidget.predictionRaceData.raceId ||
        (!oldHasLegStyle && newHasLegStyle)) {
      setState(() {
        _inputs = null;
        _shown = null;
        _playData = null;
        _first1000Target = null;
        _winnerSeconds = null;
        _cushion = null;
        _runError = null;
        _isRunning = false;
        // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
        _progress = null;
        _runToken++;
        _startLoad();
      });
    }
  }

  int get _seed => GameRaceInputs.seedOf(widget.predictionRaceData.raceId);

  void _startLoad() {
    final future = _fetchInputs();
    _inputsFuture = future;
    future.then((inputs) {
      if (!mounted || inputs == null || _inputsFuture != future) return;
      setState(() {
        _inputs = inputs;
        _source = _autoSelectSource(inputs);
        _cushion = _cushionOf(inputs, _source);
        _going = _goingDefaultOf(inputs, _source);
        _winnerSeconds = _defaultWinnerOf(inputs, _going, _cushion);
      });
      _run();
    });
  }

  /// 馬場のデータの初期値。実測(当日) > 予測 > 過去平均 の順
  TrackBiasSource _autoSelectSource(_GameSimInputs inputs) {
    if (inputs.hasActualToday) return TrackBiasSource.actual;
    if (inputs.hasPredicted) return TrackBiasSource.predicted;
    if (inputs.hasTrend) return TrackBiasSource.trend;
    return TrackBiasSource.actual;
  }

  double? _moistureOf(_GameSimInputs inputs, TrackBiasSource source) {
    switch (source) {
      case TrackBiasSource.actual:
        return inputs.actualMoisture;
      case TrackBiasSource.predicted:
        return inputs.predictedMoisture;
      case TrackBiasSource.trend:
        return inputs.trendMoisture;
    }
  }

  /// その馬場のデータのクッション値。芝だけ。無ければ過去レースの平均、それも無ければ null
  double? _cushionOf(_GameSimInputs inputs, TrackBiasSource source) {
    if (inputs.isDirt) return null;
    final double? v;
    switch (source) {
      case TrackBiasSource.actual:
        v = inputs.actualCushion;
        break;
      case TrackBiasSource.predicted:
        v = inputs.predictedCushion;
        break;
      case TrackBiasSource.trend:
        v = inputs.trendCushion;
        break;
    }
    final valid = GameRaceInputs.validCushion(v);
    if (valid != null) return valid;
    final past = [
      for (final r in inputs.pastRaces)
        if (GameRaceInputs.validCushion(r.cushion) != null) r.cushion!
    ];
    if (past.isEmpty) return null;
    final mean = past.reduce((a, b) => a + b) / past.length;
    return (mean * 10).round() / 10.0;
  }

  /// 馬場状態の初期値。当日の発表 > 馬場のデータの含水率から見込む馬場 > 良
  String _goingDefaultOf(_GameSimInputs inputs, TrackBiasSource source) {
    return inputs.officialGoing ??
        GameRaceInputs.goingOfMoisture(
            _moistureOf(inputs, source), inputs.isDirt) ??
        '良';
  }

  GameRaceReference? _referenceOf(
      _GameSimInputs inputs, String going, double? cushion) {
    return GameRaceReference.fromPastRaces(
          inputs.pastRaces,
          distance: inputs.distance,
          isDirt: inputs.isDirt,
          going: going,
          cushion: cushion,
        ) ??
        GameRaceReference.fallback(
          distance: inputs.distance,
          isDirt: inputs.isDirt,
          year: parseRaceDateForSpeedIndex(widget.predictionRaceData.raceDate)
                  ?.year ??
              DateTime.now().year,
          venueName: widget.predictionRaceData.venue,
          going: going,
        );
  }

  /// 走破タイムの初期値(秒)。過去レースも基準タイムも無ければ、シミュの時計のまま(結果が出るまでは null)
  double? _defaultWinnerOf(
      _GameSimInputs inputs, String going, double? cushion) {
    final ref = _referenceOf(inputs, going, cushion);
    if (ref != null) return (ref.defaultWinnerSeconds * 10).round() / 10.0;
    return _shown?.baselineWinnerTime;
  }

  // [修正] 展開シミュ改良Step3: 芝・ダートの設定に、このレースの調整(内の馬場・砂かぶり・傷み・当てたペース)を入れる (v.2026.10.28+26102803)
  // [修正] 展開シミュ改良Step4: GameRaceTuning.of で決め直した値(ペース倍率を含む)を効かせる (v.2026.10.29+26102901)
  GameRaceConfig _baseConfigOf(_GameSimInputs inputs) => inputs.tuning.apply(
        inputs.isDirt ? GameRaceConfig.dirt : GameRaceConfig.turf,
        rail: inputs.railInfo,
        paceDeviation: inputs.paceDeviation,
      );

  // [修正] 展開シミュ改良Step3(案D): 回ごとにペースを散らす幅 [paceScatterSd] を渡せるようにした(既定は散らさない) (v.2026.10.28+26102803)
  // [修正] 展開シミュ改良Step5b(案E): 20回ずつの組に分けて別スレッドで同時に走らせ、終わった組から途中の結果を出す(GameRaceSimulator.runParallel)。
  // 組ごとに乱数の種を変えるので、同じレースでも勝率の数字は改良Step4 までと少し変わる (v.2026.10.29+26102903)
  Future<GameRaceSummary> _simulate(
      _GameSimInputs inputs, GameRaceConfig config, int seed, int runs,
      {double paceScatterSd = 0.0}) {
    final token = _runToken;
    return GameRaceSimulator.runParallel(
      distance: inputs.distance.toDouble(),
      abilities: inputs.abilities,
      config: config,
      seed: seed,
      // [修正] 展開シミュ改良Step4: 勝率・3着以内率の補正は、このレースの調整に値があればそれを使う (v.2026.10.29+26102901)
      winCalibration: inputs.tuning.winCalibration ??
          (inputs.isDirt
              ? GameRaceSimulator.winCalibrationDirt
              : GameRaceSimulator.winCalibrationTurf),
      top3Calibration: inputs.tuning.top3Calibration ??
          (inputs.isDirt
              ? GameRaceSimulator.top3CalibrationDirt
              : GameRaceSimulator.top3CalibrationTurf),
      course: inputs.course,
      runs: runs,
      // [追加] 展開シミュ改良Step3(案D) (v.2026.10.28+26102803)
      paceScatterSd: paceScatterSd,
      // [追加] 展開シミュ改良Step5b: 途中の結果 (v.2026.10.29+26102903)
      onProgress: (p) {
        if (!mounted || token != _runToken) return;
        setState(() => _progress = p);
      },
    );
  }

  /// 今の条件で走らせる。馬場状態が変わっていれば、まず既定のペースで走らせて時計の基準を取り直す。
  /// 1000m通過が選ばれていれば、そこからペース倍率を求めてもう一度走らせる。
  Future<void> _run({bool showResult = false}) async {
    final inputs = _inputs;
    if (inputs == null || _isRunning) return;
    final going = _going;
    final target = _first1000Target;
    setState(() {
      _isRunning = true;
      _runError = null;
      // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
      _progress = null;
      _runToken++;
    });
    try {
      final base = _baseConfigOf(inputs);
      final groundHp = GameRaceInputs.groundHpOf(going, inputs.isDirt);
      final shown = _shown;
      GameRaceSummary summary;
      double paceMult;
      double baselineWinner;
      double? baselineLeader;
      if (shown == null || shown.going != going) {
        summary =
            // [修正] 展開シミュ改良Step3(案D): 既定のペースで走らせるときだけ、回ごとにペースを散らす(1000m通過を選んだときは散らさない) (v.2026.10.28+26102803)
            await _simulate(inputs, base.copyWith(groundHp: groundHp), _seed, _runs,
                paceScatterSd: inputs.tuning.paceScatterSd);
        paceMult = base.paceMult;
        baselineWinner = summary.meanWinnerTime;
        baselineLeader = summary.meanLeader1000;
      } else {
        summary = shown.summary;
        paceMult = shown.paceMult;
        baselineWinner = shown.baselineWinnerTime;
        baselineLeader = shown.baselineLeader1000;
      }
      if (!mounted) return;
      final winnerSeconds = _winnerSeconds ?? baselineWinner;
      final leader = summary.meanLeader1000;
      if (target != null && leader != null) {
        final scale = winnerSeconds / baselineWinner;
        paceMult = paceMult *
            math.pow(leader * scale / target, _paceCorrectionPower).toDouble();
        summary = await _simulate(
          inputs,
          base.copyWith(paceMult: paceMult, groundHp: groundHp),
          _seed,
          _runs,
        );
      }
      if (!mounted) return;
      setState(() {
        _shown = _ShownResult(
          summary: summary,
          paceMult: paceMult,
          going: going,
          baselineWinnerTime: baselineWinner,
          baselineLeader1000: baselineLeader,
        );
        _winnerSeconds ??= (baselineWinner * 10).round() / 10.0;
        if (_first1000Target == target) _first1000Target = null;
        _isRunning = false;
        // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
        _progress = null;
        _isAltRun = false;
        if (showResult) _section = 0;
        // [修正] 展開シミュゲーム式移植Step4c: 再生の既定を、代表の1回から平均の走りに替えた (v.2026.10.27+26102706)
        _setPlayback(inputs, summary.averageRun);
      });
    } catch (e) {
      debugPrint('展開シミュ: 走らせるのに失敗: $e');
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
        _progress = null;
        _runError = 'シミュレーションに失敗しました';
      });
    }
  }

  /// 同じ条件で1回だけ走らせ、再生と「この再生の結果」の表をその回に替える(全回の結果の表はそのまま)
  Future<void> _showAnotherRun() async {
    final inputs = _inputs;
    final shown = _shown;
    if (inputs == null || shown == null || _isRunning) return;
    setState(() => _isRunning = true);
    try {
      _altCount++;
      final one = await _simulate(
        inputs,
        _baseConfigOf(inputs).copyWith(
          paceMult: shown.paceMult,
          groundHp: GameRaceInputs.groundHpOf(shown.going, inputs.isDirt),
        ),
        _seed + 1000 + _altCount,
        1,
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isAltRun = true;
        _setPlayback(inputs, one.representative);
      });
    } catch (e) {
      debugPrint('展開シミュ: 別の回を走らせるのに失敗: $e');
      if (!mounted) return;
      setState(() => _isRunning = false);
    }
  }

  // [修正] 展開シミュゲーム式移植Step4c: 戻す先を代表の1回から平均の走りに替えた (v.2026.10.27+26102706)
  void _showAverage() {
    final inputs = _inputs;
    final shown = _shown;
    if (inputs == null || shown == null) return;
    setState(() {
      _isAltRun = false;
      _setPlayback(inputs, shown.summary.averageRun);
    });
  }

  /// 1回ぶんの記録を、今の再生の形にする(setState の中で呼ぶ)
  void _setPlayback(_GameSimInputs inputs, GameRaceRunResult run) {
    final points = GameRaceInputs.withOverrun(GameRaceDisplay.trackPointsOf(
      run,
      distance: inputs.distance.toDouble(),
      timeScale: _timeScale ?? 1.0,
    ));
    _playData = RaceSimulationData(
      horseTracks: [
        for (int i = 0; i < inputs.horses.length; i++)
          RaceSimHorseTrack(
            horseNumber: inputs.horses[i].horseNumber.toString(),
            gateNumber: _gateOf(inputs, i),
            snapshots: [
              for (final p in points[i])
                RaceSimSnapshot(
                  time: p.time,
                  distanceFromGoal: p.distanceFromGoal,
                  laneRank: p.laneRank,
                ),
            ],
          ),
      ],
      developmentTexts: const {},
      totalTime: GameRaceDisplay.totalTimeOf(points),
    );
    _playRun = run;
    _playId++;
  }

  int _gateOf(_GameSimInputs inputs, int i) =>
      inputs.gatesConfirmed ? inputs.horses[i].gateNumber : _plainGate;

  /// ゲームの時間から実時間への倍率。結果が出るまでは null
  double? get _timeScale {
    final shown = _shown;
    final w = _winnerSeconds;
    if (shown == null || w == null) return null;
    return w / shown.baselineWinnerTime;
  }

  bool get _isPending {
    final shown = _shown;
    if (shown == null) return false;
    return shown.going != _going || _first1000Target != null;
  }

  void _onSourceChanged(TrackBiasSource source) {
    final inputs = _inputs;
    if (inputs == null) return;
    setState(() {
      _source = source;
      _cushion = _cushionOf(inputs, source) ?? _cushion;
      _going = _goingDefaultOf(inputs, source);
      _winnerSeconds = _defaultWinnerOf(inputs, _going, _cushion);
    });
  }

  void _onGoingChanged(String going) {
    final inputs = _inputs;
    if (inputs == null) return;
    setState(() {
      _going = going;
      if (!inputs.isDirt) {
        final fromSource = _cushionOfSourceOnly(inputs);
        _cushion = (going == _goingDefaultOf(inputs, _source) &&
                fromSource != null)
            ? fromSource
            : (GameRaceInputs.typicalCushion[going] ?? _cushion);
      }
      _winnerSeconds = _defaultWinnerOf(inputs, going, _cushion);
    });
  }

  void _onCushionChanged(double cushion) {
    final inputs = _inputs;
    if (inputs == null) return;
    setState(() {
      _cushion = (cushion * 10).round() / 10.0;
      _winnerSeconds = _defaultWinnerOf(inputs, _going, _cushion);
    });
  }

  // ───────────────────────── 読み込み ─────────────────────────

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

  /// [追加] 展開シミュ改良Step7b: 過去走のレース結果(上がりの順位を作る)。読めなかった分は無いものとして続ける (v.2026.10.30+26103006)
  Future<Map<String, RaceResult>> _loadPastResults(List<String> raceIds) async {
    final out = <String, RaceResult>{};
    try {
      for (final chunk in GameFormInputs.chunksOf(raceIds)) {
        out.addAll(await _raceRepo.getMultipleRaceResults(chunk));
      }
    } catch (e) {
      debugPrint('展開シミュ: 調子の過去走のレース結果の読み込みに失敗: $e');
    }
    return out;
  }

  /// 重い読み込み(過去成績・コース図・指数・騎手成績・馬場のデータ・同じレースの過去の時計)を1回だけ行う
  Future<_GameSimInputs?> _fetchInputs() async {
    final race = widget.predictionRaceData;
    final venueCode = race.raceId.length >= 6 ? race.raceId.substring(4, 6) : null;
    final distance = int.tryParse(race.distanceValue?.toString() ?? '');
    if (venueCode == null || distance == null) return null;

    final trackTypeKey = _mapToTrackTypeKey();
    final isDirt = trackTypeKey == 'dirt';

    // 馬場のデータ: 実測(当日)
    TrackConditionRecord? record;
    if (race.raceId.length >= 10) {
      record = await _trackConditionRepo.getTrackConditionForRace(
        raceId: race.raceId,
        raceDate: race.raceDate,
      );
    }
    final hasActualToday = isDirt
        ? record?.moistureDirtGoal != null
        : (record?.cushionValue != null || record?.moistureTurfGoal != null);
    final actualCushion =
        isDirt ? null : GameRaceInputs.validCushion(record?.cushionValue);
    final actualMoisture =
        isDirt ? record?.moistureDirtGoal : record?.moistureTurfGoal;

    // 馬場のデータ: 予測(天気の取得は shutuba_table_page.dart で1回だけ)
    double? predictedCushion;
    double? predictedMoisture;
    if (widget.pinpointWeatherFuture != null &&
        widget.trackConditionFuture != null) {
      try {
        final pinpointData = await widget.pinpointWeatherFuture;
        final baselineRecord = await widget.trackConditionFuture;
        final raceTime = pinpointData?['raceTime'];
        if (raceTime != null && baselineRecord != null) {
          final analysis = WeatherAnalyzer.analyzeTrackConditionInsights(
            venueCode: venueCode,
            trackType: race.trackType ?? '芝',
            currentRecord: baselineRecord,
            cachedRecord: widget.cachedPrevRecord,
            expectedPrecipitation:
                (raceTime['precipitation'] as num?)?.toDouble() ?? 0.0,
            expectedRadiation: (raceTime['radiation'] as num?)?.toDouble() ?? 0.0,
            expectedSoilMoisture: (raceTime['soilMoisture'] as num?)?.toDouble(),
            dailyWeather: pinpointData?['daily'] ?? const [],
            raceDateStr: race.raceDate,
          );
          predictedCushion = isDirt
              ? null
              : GameRaceInputs.validCushion(analysis.predictedCushion);
          predictedMoisture = analysis.predictedMoisture;
        }
      } catch (_) {
        predictedCushion = null;
        predictedMoisture = null;
      }
    }

    // 馬場のデータ: 過去平均(その競馬場の直近の記録)
    final recentRecords =
        await _trackConditionRepo.getRecentTrackConditionsForVenue(venueCode);
    final trend = TrackConditionTrendAnalyzer().analyze({
      for (final r in recentRecords) r.trackConditionId.toString(): r
    });
    final avgMoisture = isDirt ? trend.avgDirtMoisture : trend.avgTurfMoisture;
    final double? trendCushion =
        isDirt ? null : GameRaceInputs.validCushion(trend.avgCushion);
    final double? trendMoisture = avgMoisture > 0 ? avgMoisture : null;

    // コース
    var raceCourse =
        CourseElevations.findRaceCourse(venueCode, distance, trackTypeKey);
    if (raceCourse == null && trackTypeKey == 'shiba') {
      raceCourse =
          CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
    }
    final diagram = await CourseDiagramService.instance
        .getCourseDiagram(venueCode, distance, trackTypeKey);
    if (diagram == null) return null;
    final course = raceCourse != null
        ? GameRaceCourse.fromRaceCourseData(raceCourse)
        : GameRaceCourse.flat;

    // 出走馬(馬番の順。ゲートの位置は並びの順で決まる)
    final activeHorses = widget.horses.where((h) => !h.isScratched).toList();
    if (activeHorses.isEmpty) return null;
    final gatesConfirmed = !activeHorses.every((h) => h.horseNumber == 0);
    final horses = (gatesConfirmed
        ? List<PredictionHorseDetail>.from(activeHorses)
        : GameRaceInputs.assignTempNumbers(activeHorses))
      ..sort((a, b) => a.horseNumber.compareTo(b.horseNumber));

    // 戦績と騎手成績(今回のレース日より前の走だけ)
    final entrantData = await RaceEntrantDataService.instance.load(race);
    final records = <String, List<HorseRaceRecord>>{
      for (final h in horses) h.horseId: entrantData.recordsOf(h.horseId),
    };
    final horseIds = horses.map((h) => h.horseId).toList();
    final paramsByHorseId = await _simParamsRepo.getByHorseIds(horseIds);
    final speedIndexByHorseId = await _speedIndexRepo.getByHorseIds(horseIds);
    final asOf = parseRaceDateForSpeedIndex(race.raceDate);

    // [追加] 展開シミュ改良Step7b: 調子(調教から出す5段階)。過去走のレース結果から、レースの中での上がりの順位を作る (v.2026.10.30+26103006)
    final pastResults =
        await _loadPastResults(GameFormInputs.raceIdsOf(records.values));
    final forms = GameFormInputs.formsOf(
      horseIds: [for (final h in horses) h.horseId],
      records: records,
      trainings: entrantData.pakaraTrainingByHorse,
      raceYmd: toYyyymmdd(race.raceDate) ?? '',
      results: pastResults,
    );

    // [追加] 展開シミュ改良Step2(案B): 適性の点数の材料(過去走の距離・芝ダ・着順、休み、年齢・性別、今回の馬体重)と、斤量 (v.2026.10.28+26102802)
    final aptitudeRaws = [
      for (final h in horses)
        GameAptitude.rawOf(
          records[h.horseId] ?? const <HorseRaceRecord>[],
          raceDay: asOf,
          distance: distance,
          isDirt: isDirt,
          sexAndAge: h.sexAndAge,
          horseWeight: h.horseWeight,
        ),
    ];
    // [修正] 展開シミュ改良Step5b: 適性の項は、なぜこの勝率か にも使うので残す (v.2026.10.29+26102903)
    final aptitudeTerms = GameAptitude.termsOf(aptitudeRaws, distance);
    final aptitudeScores = GameAptitude.scoresOf(
      aptitudeTerms,
      GameAptitude.weightsOf(isDirt: isDirt),
    );

    final sources = <GameAbilitySource>[];
    final staminaIndexes = <double?>[];
    // [修正] 展開シミュ改良Step2: 馬の番号が要るので、for の形を変えた (v.2026.10.28+26102802)
    for (int i = 0; i < horses.length; i++) {
      final h = horses[i];
      final rec = records[h.horseId] ?? const <HorseRaceRecord>[];
      final params = paramsByHorseId[h.horseId] ??
          SimulationParamsCalculator.calculate(h.horseId, rec);
      final speedIndex = speedIndexByHorseId[h.horseId] ??
          SpeedIndexCalculator.calculate(h.horseId, rec, asOf: asOf);
      final kick = RaceFinishCalculator.calculateKick(rec);
      final early = EarlyPositionCalculator.calculate(
        rec,
        styleDistribution: h.legStyleProfile?.styleDistribution ??
            const <String, double>{},
        primaryStyle: h.legStyleProfile?.primaryStyle,
      );
      final jockey = entrantData.jockeyStats[h.jockeyId];
      final hasSpeedIndex = speedIndex.sampleCount > 0;
      sources.add(GameAbilitySource(
        speedIndex: hasSpeedIndex ? speedIndex.recentAvgIndex : null,
        speedIndexConfidence: hasSpeedIndex ? speedIndex.confidence : null,
        earlyRate: early.rate,
        kickSeconds: kick.kickSeconds,
        staminaIndex: params.staminaIndex,
        jockeyShowRate: GameRaceInputs.jockeyShowRateOf(jockey?.overallStats),
        // [追加] 展開シミュ改良Step2: 適性の点数と斤量(斤量が0以下は分からない扱い) (v.2026.10.28+26102802)
        aptitudeScore: aptitudeScores[i],
        carriedWeight: h.carriedWeight > 0 ? h.carriedWeight : null,
        pastCarriedWeight: aptitudeRaws[i].pastCarriedWeight,
        // [追加] 展開シミュ改良Step7b: 調子(やる気)の倍率 (v.2026.10.30+26103006)
        formMultiplier: forms[i].multiplier,
      ));
      staminaIndexes.add(params.staminaIndex);
    }
    // [修正] 展開シミュ改良Step2: 能力値の調整を渡す (v.2026.10.28+26102802)
    // [修正] 展開シミュ改良Step4: GameAbilityTuning.of で決め直した値を効かせる (v.2026.10.29+26102901)
    final abilities = GameAbilityBuilder.build(
      sources,
      tuning: GameAbilityTuning.of(isDirt: isDirt),
      distance: distance.toDouble(),
    );
    // [追加] 展開シミュ改良Step7b: ステータスの表示は、調子を含まない地力の値 (v.2026.10.30+26103006)
    final displayAbilities = GameAbilityBuilder.build(
      sources,
      tuning: GameAbilityTuning.of(isDirt: isDirt).withoutForm(),
      distance: distance.toDouble(),
    );

    // 同じレース名の過去レースの時計(失敗しても過去の時計なしで続ける)
    final pastRaces = <GamePastRaceTime>[];
    try {
      if (race.raceName.trim().isNotEmpty) {
        final found = await _raceRepo.searchRaceResultsByName(race.raceName.trim());
        final matched = GameRaceInputs.latestRaces([
          for (final r in found)
            if (GameRaceInputs.pastRaceTimeOf(
                  r,
                  venueCode: venueCode,
                  distance: distance,
                  isDirt: isDirt,
                  before: asOf,
                  excludeRaceId: race.raceId,
                ) !=
                null)
              r,
        ]);
        for (final r in matched) {
          final t = GameRaceInputs.pastRaceTimeOf(
            r,
            venueCode: venueCode,
            distance: distance,
            isDirt: isDirt,
            before: asOf,
            excludeRaceId: race.raceId,
          )!;
          double? cushion;
          if (!isDirt && r.raceId.length >= 10) {
            final tc = await _trackConditionRepo.getTrackConditionForRace(
              raceId: r.raceId,
              raceDate: r.raceDate,
            );
            cushion = GameRaceInputs.validCushion(tc?.cushionValue);
          }
          pastRaces.add(GamePastRaceTime(
            raceId: t.raceId,
            winnerSeconds: t.winnerSeconds,
            first1000Seconds: t.first1000Seconds,
            going: t.going,
            cushion: cushion,
          ));
        }
      }
    } catch (e) {
      debugPrint('展開シミュ: 過去レースの時計の読み込みに失敗: $e');
    }

    return _GameSimInputs(
      distance: distance,
      isDirt: isDirt,
      trackTypeKey: trackTypeKey,
      raceCourse: raceCourse,
      diagram: diagram,
      course: course,
      horses: horses,
      gatesConfirmed: gatesConfirmed,
      abilities: abilities,
      staminaIndexes: staminaIndexes,
      // [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
      displayAbilities: displayAbilities,
      forms: forms,
      // [追加] 展開シミュ改良Step3 (v.2026.10.28+26102803)
      // [修正] 展開シミュ改良Step8: 使用コースは出馬表のコースの表記(courseInOut。例 '外 B')から読む (v.2026.10.30+26103007)
      railInfo: GameCourseRail.infoOf(race.raceId, race.courseInOut),
      paceDeviation: GamePacePredictor.deviationOf(sources, isDirt: isDirt),
      tuning: GameRaceTuning.of(isDirt: isDirt),
      // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
      speedParts: GameAbilityBuilder.speedPartsOf(
        sources,
        tuning: GameAbilityTuning.of(isDirt: isDirt),
        distance: distance.toDouble(),
      ),
      aptitudeTerms: aptitudeTerms,
      aptitudeWeights: GameAptitude.weightsOf(isDirt: isDirt),
      pastRaces: pastRaces,
      officialGoing: GameRaceReference.normalizeGoing(race.trackCondition),
      hasActualToday: hasActualToday,
      actualCushion: actualCushion,
      actualMoisture: actualMoisture,
      predictedCushion: predictedCushion,
      predictedMoisture: predictedMoisture,
      trendCushion: trendCushion,
      trendMoisture: trendMoisture,
    );
  }

  // ───────────────────────── 画面 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<_GameSimInputs?>(
      future: _inputsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // [修正] 展開シミュゲーム式移植Step4c: 読み込み中も文字を出す (v.2026.10.27+26102706)
          return _buildLoading();
        }
        final inputs = snapshot.data;
        if (inputs == null) {
          return const Center(child: Text('展開シミュレーションを表示できません'));
        }
        final shown = _shown;
        if (shown == null || _playData == null) {
          if (_runError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_runError!),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _run, child: const Text('もう一度')),
                ],
              ),
            );
          }
          // [修正] 展開シミュ改良Step5b(案E): 最初の計算中は、途中の結果があれば表だけ先に出す (v.2026.10.29+26102903)
          final progress = _progress;
          if (progress != null) return _buildProgressOnly(inputs, progress);
          return _buildLoading();
        }
        final scale = _timeScale ?? 1.0;
        final playRun = _playRun;
        // [修正] 展開シミュ改良Step5b: 馬ごとの値を作る所を _viewsOf に分けた (v.2026.10.29+26102903)
        final views = _viewsOf(inputs, shown.summary.horses);
        // [追加] 展開シミュ改良Step5b(案E): 計算し直している間は、結果の表に途中の結果を出す (v.2026.10.29+26102903)
        final progress = _isRunning ? _progress : null;
        return Container(
          color: const Color(0xFFF1F6EF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionChips(),
              if (_isRunning) const LinearProgressIndicator(minHeight: 2),
              if (_runError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                  child: Text(_runError!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              Expanded(
                child: IndexedStack(
                  index: _section,
                  sizing: StackFit.expand,
                  children: [
                    _sectionScroll(0, [
                      _buildPlaybackCard(inputs),
                      // [追加] 展開シミュゲーム式移植Step4c: 再生している1回の着順の表。「別の回を見る」で一緒に入れ替わる (v.2026.10.27+26102706)
                      if (playRun != null)
                        GameSimRunResultCard(
                          horses: views,
                          rows: GameRaceDisplay.runRowsOf(
                            playRun,
                            checkpoints: shown.summary.checkpoints,
                            timeScale: scale,
                          ),
                          note: _isAltRun ? '別の1回' : '平均の走り',
                          footnote: _isAltRun
                              ? null
                              : '時計は各馬の全回の平均。下の「勝ち時計」は勝った馬の時計の平均なので、少し速い。',
                          checkpointHeader: GameRaceInputs.checkpointHeaderOf(
                              inputs.course.corners.length),
                          cornerCount: inputs.course.corners.length,
                        ),
                      // [修正] 展開シミュ改良Step5b(案E): 計算し直している間は途中の結果。散らしたペースの幅の1行を足した (v.2026.10.29+26102903)
                      progress != null
                          ? _progressCard(inputs, progress)
                          : GameSimResultCard(
                              horses: views,
                              runs: shown.summary.runs,
                              timesText: _timesTextOf(shown),
                              paceText: _paceTextOf(shown),
                              checkpointHeader: GameRaceInputs.checkpointHeaderOf(
                                  inputs.course.corners.length),
                              cornerCount: inputs.course.corners.length,
                            ),
                      // [追加] 展開シミュ改良Step5b(案E): なぜこの勝率か (v.2026.10.29+26102903)
                      if (progress == null)
                        GameSimReasonCard(
                          horses: views,
                          reasons: GameRaceReasons.of(
                            parts: inputs.speedParts,
                            aptitudeTerms: inputs.aptitudeTerms,
                            aptitudeWeights: inputs.aptitudeWeights,
                            horses: shown.summary.horses,
                            distance: inputs.distance.toDouble(),
                            isDirt: inputs.isDirt,
                          ),
                          // [追加] 展開シミュ改良Step7b: 調子の得・損 (v.2026.10.30+26103006)
                          formReasons: GameRaceReasons.formOf(
                            parts: inputs.speedParts,
                            forms: inputs.forms,
                            distance: inputs.distance.toDouble(),
                          ),
                        ),
                    ]),
                    _sectionScroll(1, [_buildConditionCard(inputs, shown)]),
                    _sectionScroll(2, [GameSimStatusCard(horses: views)]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// [追加] 展開シミュ改良Step5b: 馬ごとの画面の値 (v.2026.10.29+26102903)
  List<GameSimHorseView> _viewsOf(
      _GameSimInputs inputs, List<GameHorseSummary> summaries) {
    return [
      for (int i = 0; i < inputs.horses.length; i++)
        GameSimHorseView(
          horseNumber: inputs.horses[i].horseNumber,
          gateNumber: _gateOf(inputs, i),
          horseName: inputs.horses[i].horseName,
          // [修正] 展開シミュ改良Step7b: 表示は調子を含まない地力の値。調子は form で別に出す (v.2026.10.30+26103006)
          ability: inputs.displayAbilities[i],
          staminaIndex: inputs.staminaIndexes[i],
          summary: i < summaries.length ? summaries[i] : null,
          form: inputs.forms[i],
        ),
    ];
  }

  /// [追加] 展開シミュ改良Step5b(案E): 途中の結果の表(時計は計算が終わってから) (v.2026.10.29+26102903)
  Widget _progressCard(_GameSimInputs inputs, GameRaceProgress progress) {
    return GameSimResultCard(
      horses: _viewsOf(inputs, progress.horses),
      runs: progress.runsDone,
      timesText: '計算しています… 時計・再生・なぜこの勝率か は${progress.runsTotal}回の計算が終わってから出る。',
      note: '途中の結果 ${progress.runsDone}/${progress.runsTotal}回',
      checkpointHeader:
          GameRaceInputs.checkpointHeaderOf(inputs.course.corners.length),
      cornerCount: inputs.course.corners.length,
    );
  }

  /// [追加] 展開シミュ改良Step5b(案E): 最初の計算中に、途中の結果の表だけを出す (v.2026.10.29+26102903)
  Widget _buildProgressOnly(_GameSimInputs inputs, GameRaceProgress progress) {
    return Container(
      color: const Color(0xFFF1F6EF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
              minHeight: 2, value: progress.runsDone / progress.runsTotal),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: _progressCard(inputs, progress),
            ),
          ),
        ],
      ),
    );
  }

  /// [追加] 展開シミュ改良Step5b(案E): 回ごとに散らしたペースの幅(先頭の1000m通過の、中央の8割の回の範囲)。散らしていなければ null (v.2026.10.29+26102903)
  String? _paceTextOf(_ShownResult shown) {
    final s = shown.summary;
    if (s.paceOffsets.isEmpty) return null;
    final scale = _timeScale ?? 1.0;
    final xs = <double>[
      for (final x in s.runLeader1000)
        if (x != null) x * scale
    ]..sort();
    if (xs.length < 2) return null;
    final lo = xs[((xs.length - 1) * 0.1).round()];
    final hi = xs[((xs.length - 1) * 0.9).round()];
    return 'ペースは回ごとに散らした: 1000m ${lo.toStringAsFixed(1)}〜${hi.toStringAsFixed(1)}(8割の回)';
  }

  /// [追加] 展開シミュゲーム式移植Step4c: 読み込み中とシミュレーション中(結果がまだ無いとき)の表示 (v.2026.10.27+26102706)
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('展開をシミュレーションしています…',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  /// 区分の切り替えチップ(画面のいちばん上。スクロールしても残る)
  Widget _buildSectionChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Wrap(
        spacing: 8,
        children: [
          for (int k = 0; k < _sectionLabels.length; k++)
            ChoiceChip(
              label: Text(_sectionLabels[k], style: const TextStyle(fontSize: 12)),
              selected: _section == k,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _section = k),
            ),
        ],
      ),
    );
  }

  /// 区分ごとのスクロール(位置は区分ごとに残る)
  Widget _sectionScroll(int k, List<Widget> children) {
    return SingleChildScrollView(
      key: PageStorageKey('race_simulation_scroll_$k'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildPlaybackCard(_GameSimInputs inputs) {
    return GameSimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_isAltRun ? '別の1回を再生' : '平均の走りを再生',
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isAltRun ? '同じ条件でシミュレーションし直した1回' : '各馬の全回の平均の走り',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: GameSimColors.subText),
                ),
              ),
            ],
          ),
          if (!inputs.gatesConfirmed)
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text('枠順の発表前なので、馬番は仮(馬名の順)',
                  style: TextStyle(fontSize: 11, color: GameSimColors.subText)),
            ),
          const SizedBox(height: 6),
          RaceSimulationView(
            key: ValueKey('game_sim_play_$_playId'),
            diagram: inputs.diagram,
            simulationData: _playData!,
            raceDistance: inputs.distance.toDouble(),
            approachPaths: inputs.raceCourse?.approachPath,
            // コースデータが無いときは右回り扱い(JRAは右回りが多い)
            isLeftHanded: inputs.raceCourse?.isLeftHanded ?? false,
            trackTypeKey: inputs.trackTypeKey,
            raceCourse: inputs.raceCourse,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isAltRun)
                TextButton(
                  onPressed: _isRunning ? null : _showAverage,
                  child: const Text('平均の走りに戻す', style: TextStyle(fontSize: 12)),
                ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GameSimColors.primary,
                  side: const BorderSide(color: GameSimColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _isRunning ? null : _showAnotherRun,
                child: const Text('別の回を見る', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timesTextOf(_ShownResult shown) {
    final scale = _timeScale ?? 1.0;
    final s = shown.summary;
    final parts = <String>[
      '勝ち時計 ${GameRaceReference.formatTime(s.meanWinnerTime * scale)}',
      if (s.meanLeader1000 != null)
        '1000m ${(s.meanLeader1000! * scale).toStringAsFixed(1)}',
      '上がり ${(s.meanWinnerLast600 * scale).toStringAsFixed(1)}',
    ];
    return parts.join(' ・ ');
  }

  // [修正] 展開シミュゲーム式移植Step4c: スライダーの範囲を、動かしている今の値ではなく初期値から作る。
  // 今の値から作っていたため、端まで動かすたびに範囲が広がっていた (v.2026.10.27+26102706)
  /// [lo]〜[hi] を、初期値 [initial] ± [_sliderPad] が入るように広げ、0.1秒刻みに丸める
  (double, double) _rangeOf(double lo, double hi, double initial) {
    final a = lo < initial - _sliderPad ? lo : initial - _sliderPad;
    final b = hi > initial + _sliderPad ? hi : initial + _sliderPad;
    return ((a * 10).floor() / 10.0, (b * 10).ceil() / 10.0);
  }

  String _sourceLabelOf(TrackBiasSource source) {
    switch (source) {
      case TrackBiasSource.actual:
        return '実測(当日)';
      case TrackBiasSource.predicted:
        return '予測';
      case TrackBiasSource.trend:
        return '過去平均';
    }
  }

  Widget _buildConditionCard(_GameSimInputs inputs, _ShownResult shown) {
    final ref = _referenceOf(inputs, _going, _cushion);
    final scale = _timeScale ?? 1.0;
    final winner = _winnerSeconds ?? shown.baselineWinnerTime;
    // 走破タイムの初期値(今の馬場状態・クッション値)。範囲はこの値と過去レースから作り、動かしても変わらない
    final winnerInitial =
        _defaultWinnerOf(inputs, _going, _cushion) ?? shown.baselineWinnerTime;

    // 走破タイム
    final double wLo;
    final double wHi;
    final String winnerNote;
    if (ref != null && !ref.isFallback) {
      wLo = ref.sliderWinnerMin;
      wHi = ref.sliderWinnerMax;
      winnerNote = '過去(同じレース名・${ref.races.length}レース): '
          '最速 ${GameRaceReference.formatTime(ref.winnerMin)} ・ '
          '平均 ${GameRaceReference.formatTime(ref.winnerMean)} ・ '
          '最遅 ${GameRaceReference.formatTime(ref.winnerMax)}。'
          '初期値は馬場状態・クッション値をそろえた平均。';
    } else if (ref != null) {
      wLo = ref.sliderWinnerMin;
      wHi = ref.sliderWinnerMax;
      winnerNote = '同じレースの過去の時計が足りないので、スピード指数の基準タイム(OP級)を初期値にした。';
    } else {
      wLo = shown.baselineWinnerTime - 2.0;
      wHi = shown.baselineWinnerTime + 2.0;
      winnerNote = '基準にする時計が無いので、シミュの時計をそのまま初期値にした。';
    }
    final (winnerMin, winnerMax) = _rangeOf(wLo, wHi, winnerInitial);

    // 1000m通過
    final leader = shown.summary.meanLeader1000;
    final double? first1000 =
        leader == null ? null : (_first1000Target ?? leader * scale);
    // 1000m通過の初期値(既定のペースで走らせたときの通過を、走破タイムの初期値で換算した値)
    final baseLeader = shown.baselineLeader1000;
    final double? first1000Initial = baseLeader == null
        ? first1000
        : baseLeader * winnerInitial / shown.baselineWinnerTime;
    double f1Min = 0.0;
    double f1Max = 0.0;
    String first1000Note = '初期値は面子から出たシミュのペース。';
    if (first1000 != null && first1000Initial != null) {
      final double lo;
      final double hi;
      if (ref != null &&
          ref.sliderFirst1000Min != null &&
          ref.sliderFirst1000Max != null) {
        lo = ref.sliderFirst1000Min!;
        hi = ref.sliderFirst1000Max!;
        first1000Note = '過去: 最速 ${ref.first1000Min!.toStringAsFixed(1)} ・ '
            '平均 ${ref.first1000Mean!.toStringAsFixed(1)} ・ '
            '最遅 ${ref.first1000Max!.toStringAsFixed(1)}。$first1000Note';
      } else {
        lo = first1000Initial - _first1000FallbackHalf;
        hi = first1000Initial + _first1000FallbackHalf;
      }
      (f1Min, f1Max) = _rangeOf(lo, hi, first1000Initial);
    }

    // クッション値
    double cMin = 0.0;
    double cMax = 0.0;
    if (_cushion != null) {
      (cMin, cMax) = GameRaceInputs.cushionRangeOf(inputs.pastRaces, [
        _cushion,
        inputs.actualCushion,
        inputs.predictedCushion,
        inputs.trendCushion,
      ]);
    }
    // [修正] 展開シミュゲーム式移植Step4c: 馬場状態のボタンで入れた値のときは「良のよくある値」などと出す (v.2026.10.27+26102706)
    final sourceCushion = inputs.isDirt ? null : _cushionOfSourceOnly(inputs);
    final String cushionLabel;
    if (sourceCushion != null && sourceCushion == _cushion) {
      cushionLabel = _sourceLabelOf(_source);
    } else if (GameRaceInputs.typicalCushion[_going] == _cushion) {
      cushionLabel = '$_goingのよくある値';
    } else if (sourceCushion == null && _cushionOf(inputs, _source) == _cushion) {
      cushionLabel = '過去レースの平均';
    } else {
      cushionLabel = '手で変更';
    }

    // 馬場状態の説明
    final String goingNote;
    if (inputs.officialGoing != null) {
      goingNote = '初期値は当日の発表(${inputs.officialGoing})。';
    } else if (_moistureOf(inputs, _source) != null) {
      goingNote = '初期値は${_sourceLabelOf(_source)}の含水率から見込んだ馬場。';
    } else {
      goingNote = '馬場のデータが無いので、初期値は良。';
    }

    return GameSimConditionCard(
      winnerNote: winnerNote,
      // [修正] 展開シミュゲーム式移植Step4c: 値はスライダーの範囲の中に収めて出す (v.2026.10.27+26102706)
      winnerSeconds: winner.clamp(winnerMin, winnerMax).toDouble(),
      winnerMin: winnerMin,
      winnerMax: winnerMax,
      onWinnerChanged: (v) =>
          setState(() => _winnerSeconds = (v * 10).round() / 10.0),
      first1000Seconds: first1000?.clamp(f1Min, f1Max).toDouble(),
      first1000Min: f1Min,
      first1000Max: f1Max,
      first1000Note: first1000Note,
      onFirst1000Changed: (v) =>
          setState(() => _first1000Target = (v * 10).round() / 10.0),
      cushion: _cushion,
      cushionMin: cMin,
      cushionMax: cMax,
      cushionSourceLabel: cushionLabel,
      onCushionChanged: _onCushionChanged,
      going: _going,
      goingNote: '$goingNote 重・不良はスタミナの消費が増える(ゲームの値)。',
      onGoingChanged: _onGoingChanged,
      source: _source,
      hasActual: inputs.hasActualToday,
      hasPredicted: inputs.hasPredicted,
      hasTrend: inputs.hasTrend,
      onSourceChanged: _onSourceChanged,
      isRunning: _isRunning,
      isPending: _isPending,
      onRun: () => _run(showResult: true),
    );
  }

  /// 選んでいる馬場のデータそのもののクッション値(過去レースの平均で埋めない)
  double? _cushionOfSourceOnly(_GameSimInputs inputs) {
    final double? v;
    switch (_source) {
      case TrackBiasSource.actual:
        v = inputs.actualCushion;
        break;
      case TrackBiasSource.predicted:
        v = inputs.predictedCushion;
        break;
      case TrackBiasSource.trend:
        v = inputs.trendCushion;
        break;
    }
    return GameRaceInputs.validCushion(v);
  }
}