// lib/widgets/shutuba_tabs/race_simulation_view.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/logic/elevation_logic.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_simulation_model.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/course_diagram_painter.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_camera_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_elevation_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_layer2_painter.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_painter.dart';

// [修正] 0-9b-3 自由入力(manual)を廃止し実測/予測/過去平均の3種に (v.2026.7.27+26072707)
enum TrackBiasSource { actual, predicted, trend }

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
  final Map<String, HorseSimulationParams> simulationParams;
  final List<PredictionHorseDetail> horses;
  // [追加] 0-9(b) 使用データカード表示用 (v.2026.7.27+26072703)
  final String? predictedPace;
  final String? trackConditionText;   // 馬場状態(良/稍重/重/不良)
  final double? cushionValue;         // 芝のみ
  final double? moistureValue;        // 芝:ゴール前芝含水 / ダート:ゴール前ダート含水
  final double trackBias;             // 0-9aの算出値(既定0.0)
  final String? trackConditionDate;   // 計測日（実測のときのみ非null）
  // [追加] 0-9b-1 クッション値/含水率の使用ソースラベル（実測(当日)/予測/過去平均） (v.2026.7.27+26072704)
  final String biasSourceLabel;
  // [追加] 0-9b-2 ソース切替用 (v.2026.7.27+26072705)
  final TrackBiasSource selectedSource;
  final bool hasActualToday;
  final ValueChanged<TrackBiasSource> onSourceChanged;
  // [追加] 0-9b-3 ペース手動選択用 (v.2026.7.27+26072707)
  final String selectedPace;
  final ValueChanged<String> onPaceChanged;

  const RaceSimulationView({
    super.key,
    required this.diagram,
    required this.simulationData,
    required this.raceDistance,
    this.approachPaths,
    required this.isLeftHanded,
    required this.trackTypeKey,
    this.raceCourse,
    this.simulationParams = const {},
    this.horses = const [],
    this.predictedPace,
    this.trackConditionText,
    this.cushionValue,
    this.moistureValue,
    this.trackBias = 0.0,
    this.trackConditionDate,
    this.biasSourceLabel = '—',
    this.selectedSource = TrackBiasSource.actual,
    this.hasActualToday = false,
    required this.onSourceChanged,
    this.selectedPace = 'ミドルペース',
    required this.onPaceChanged,
  });

  @override
  State<RaceSimulationView> createState() => _RaceSimulationViewState();
}

class _RaceSimulationViewState extends State<RaceSimulationView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<CourseApproach>? _approach;
  late final Path _trackPath;
  late final Path _infieldPath;
  late final Path _railPath;
  late final ChartDrawData? _elevationData;

  // [追加] リアルタイム速度化: 再生倍速。デフォルト8x(2000m≈15秒) (v2026.6.25)
  double _playbackSpeed = 8.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (widget.simulationData.totalTime * 1000 / _playbackSpeed).round(),
      ),
    );
    _controller.addStatusListener(_onStatusChanged);

    _approach = widget.approachPaths;
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

  // [追加] リアルタイム速度化: 再生倍速を切り替える。再生中の場合は現在位置を保持してそのまま継続 (v2026.6.25)
  void _setPlaybackSpeed(double speed) {
    final wasAnimating = _controller.isAnimating;
    final currentValue = _controller.value;
    _controller.stop();
    _controller.duration = Duration(
      milliseconds:
          (widget.simulationData.totalTime * 1000 / speed).round(),
    );
    setState(() {
      _playbackSpeed = speed;
    });
    _controller.value = currentValue;
    if (wasAnimating) _controller.forward();
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
              return Stack(
                children: [
                  // Layer1: コース形状・内ラチ・ゴールライン等（変更なし）
                  CustomPaint(
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
                      showHorseMarkers: false,
                    ),
                    size: Size.infinite,
                  ),
                  // Layer2: 進行距離×横位置座標系の馬番マーカーオーバーレイ
                  CustomPaint(
                    painter: RaceSimulationLayer2Painter(
                      coords: widget.diagram.coords,
                      raceDistance: widget.raceDistance,
                      approach: _approach,
                      simulationData: widget.simulationData,
                      currentTime: currentTime,
                      isLeftHanded: widget.isLeftHanded,
                      simulationParams: widget.simulationParams,
                      raceCourse: widget.raceCourse,
                    ),
                    size: Size.infinite,
                  ),
                ],
              );
            },
          ),
        ),

        // ── 残り距離表示(先頭馬基準・周回によるリセットなし) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final currentTime =
                  _controller.value * widget.simulationData.totalTime;
              final remaining = _leaderDistanceFromGoal(currentTime).round();
              return Text(
                '残り ${remaining}m',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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

        // [追加] リアルタイム速度化: 再生速度セレクター (v2026.6.25)
        Padding(
          padding: const EdgeInsets.only(left: 52.0, right: 8.0, bottom: 8.0),
          child: Row(
            children: [
              const Text('速度:',
                  style: TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(width: 6),
              for (final speed in [4.0, 8.0, 16.0])
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: _playbackSpeed == speed
                            ? Colors.green.shade700
                            : Colors.grey.shade400,
                      ),
                      foregroundColor: _playbackSpeed == speed
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                    onPressed: () => _setPlaybackSpeed(speed),
                    child: Text('${speed.toInt()}x',
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
        ),

        // [追加] 0-9(b) 使用データカード（展開予想の根拠を常時表示） (v.2026.7.27+26072703)
        Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '使用データ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              // [追加] 0-9b-2 クッション値/含水率のソース切替トグル (v.2026.7.27+26072705)
              _buildSourceToggle(),
              const SizedBox(height: 4),
              _buildDataRow('予想ペース', widget.predictedPace ?? '—'),
              // [追加] 0-9b-3 ペース手動選択（スロー/ミドル/ハイ。初期値はアプリ予想ペース） (v.2026.7.27+26072707)
              _buildPaceSelector(),
              const SizedBox(height: 4),
              _buildDataRow('距離・コース', _buildCourseLabel()),
              _buildDataRow('馬場状態', widget.trackConditionText ?? '—'),
              _buildDataRow(
                'クッション値',
                widget.trackTypeKey == 'dirt'
                    ? '—'
                    : (widget.cushionValue != null
                        ? '${widget.cushionValue!.toStringAsFixed(1)}（${widget.biasSourceLabel}）'
                        : '—'),
              ),
              _buildDataRow(
                '含水率',
                widget.moistureValue != null
                    ? '${widget.moistureValue!.toStringAsFixed(1)}%（${widget.biasSourceLabel}）'
                    : '—',
              ),
              _buildDataRow(
                'トラックバイアス',
                '${widget.trackBias.toStringAsFixed(2)}（${_trackBiasLabel(widget.trackBias)}）',
              ),
              // [修正] 0-9b-1 計測日は実測のときのみ表示（予測・過去平均・なしのときは行自体を出さない） (v.2026.7.27+26072704)
              if (widget.trackConditionDate != null)
                _buildDataRow('計測日', widget.trackConditionDate!),
            ],
          ),
        ),

        // ── ステータス表（シークバー下）──
        if (widget.horses.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(),
                const Divider(height: 1),
                ...widget.horses.map((horse) {
                  final params =
                      widget.simulationParams[horse.horseNumber.toString()];
                  return _buildStatusRow(horse, params);
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusHeader() {
    const style = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      child: Row(
        children: [
          SizedBox(width: 22, child: Text('#', style: style)),
          Expanded(flex: 3, child: Text('馬名', style: style)),
          SizedBox(
              width: 30,
              child: Text('脚質', style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('テン', style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('終い', style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('スタ', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      PredictionHorseDetail horse, HorseSimulationParams? params) {
    const numStyle =
        TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
    const nameStyle = TextStyle(fontSize: 10);
    const legStyleTextStyle =
        TextStyle(fontSize: 9, color: Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
              width: 22,
              child: Text(horse.horseNumber.toString(), style: numStyle)),
          Expanded(
              flex: 3,
              child: Text(horse.horseName,
                  style: nameStyle, overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 30,
              child: Text(params?.legStyle ?? '不明',
                  style: legStyleTextStyle, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: _buildBar(params?.tenAccelIndex ?? 0, Colors.orange)),
          Expanded(
              flex: 2,
              child: _buildBar(params?.finishingPower ?? 0, Colors.blue)),
          Expanded(
              flex: 2,
              child: _buildBar(params?.staminaIndex ?? 0, Colors.green)),
        ],
      ),
    );
  }

  // [追加] 0-9b-2 クッション値/含水率のソース切替トグルを組み立てる (v.2026.7.27+26072705)
  Widget _buildSourceToggle() {
    const options = <TrackBiasSource, String>{
      TrackBiasSource.actual: '実測(当日)',
      TrackBiasSource.predicted: '予測',
      TrackBiasSource.trend: '過去平均',
    };
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: options.entries.map((entry) {
        final source = entry.key;
        final isSelected = widget.selectedSource == source;
        final isEnabled =
            source != TrackBiasSource.actual || widget.hasActualToday;
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: !isEnabled
                  ? Colors.grey.shade300
                  : (isSelected ? Colors.green.shade700 : Colors.grey.shade400),
            ),
            foregroundColor: !isEnabled
                ? Colors.grey.shade400
                : (isSelected ? Colors.green.shade700 : Colors.grey.shade600),
          ),
          onPressed: isEnabled ? () => widget.onSourceChanged(source) : null,
          child: Text(entry.value, style: const TextStyle(fontSize: 10)),
        );
      }).toList(),
    );
  }

  // [追加] 0-9b-3 ペース手動選択（スロー/ミドル/ハイ の3ボタン。自動ボタンは無し） (v.2026.7.27+26072707)
  Widget _buildPaceSelector() {
    const options = <String, String>{
      'スローペース': 'スロー',
      'ミドルペース': 'ミドル',
      'ハイペース': 'ハイ',
    };
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: options.entries.map((entry) {
        final pace = entry.key;
        final isSelected = widget.selectedPace == pace;
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade400,
            ),
            foregroundColor:
                isSelected ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          onPressed: () => widget.onPaceChanged(pace),
          child: Text(entry.value, style: const TextStyle(fontSize: 10)),
        );
      }).toList(),
    );
  }

  // [追加] 0-9(b) 使用データカード: ラベル:値の1行を組み立てる (v.2026.7.27+26072703)
  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [追加] 0-9(b) 使用データカード: 距離・コース表記を組み立てる (v.2026.7.27+26072703)
  String _buildCourseLabel() {
    final surface = widget.trackTypeKey == 'dirt' ? 'ダ' : '芝';
    final distanceText = '$surface${widget.raceDistance.round()}m';
    if (widget.trackTypeKey == 'shiba_straight') {
      return '$distanceText・直線';
    }
    final direction = widget.isLeftHanded ? '左' : '右';
    String inOut = '';
    if (widget.trackTypeKey == 'shiba_outer') inOut = '外';
    if (widget.trackTypeKey == 'shiba_inner') inOut = '内';
    return inOut.isEmpty
        ? '$distanceText・$direction'
        : '$distanceText・$direction・$inOut';
  }

  // [追加] 0-9(b) トラックバイアス値→ラベル変換 (v.2026.7.27+26072703)
  String _trackBiasLabel(double b) {
    if (b >= 0.5) return '前有利';
    if (b >= 0.15) return 'やや前有利';
    if (b > -0.15) return 'フラット';
    if (b > -0.5) return 'やや差し有利';
    return '差し有利';
  }

  Widget _buildBar(double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}