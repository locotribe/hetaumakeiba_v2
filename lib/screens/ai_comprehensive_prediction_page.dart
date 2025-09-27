// lib/screens/ai_comprehensive_prediction_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/summary_generator.dart';
import 'package:hetaumakeiba_v2/logic/ai/condition_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_settings_page.dart';
import 'package:hetaumakeiba_v2/services/ai_prediction_service.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

import '../widgets/themed_tab_bar.dart';

class _HorseNumberDotPainter extends FlDotPainter {
  final Color color;
  final String horseNumber;
  final double radius;

  _HorseNumberDotPainter(this.color, this.horseNumber, {this.radius = 9});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset center) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(
      text: horseNumber,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(radius * 2, radius * 2);
  }


  @override
  List<Object?> get props => [color, horseNumber, radius];


  @override
  Color get mainColor => color;


  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    return this;
  }


  FlDotPainter copyWith({
    Color? color,
    String? horseNumber,
    double? radius,
  }) {
    return _HorseNumberDotPainter(
      color ?? this.color,
      horseNumber ?? this.horseNumber,
      radius: radius ?? this.radius,
    );
  }
}

class ComprehensivePredictionPage extends StatefulWidget {
  final PredictionRaceData raceData;
  final String raceId;

  const ComprehensivePredictionPage({
    super.key,
    required this.raceData,
    required this.raceId,
  });

  @override
  State<ComprehensivePredictionPage> createState() => _ComprehensivePredictionPageState();
}

class _ComprehensivePredictionPageState extends State<ComprehensivePredictionPage>
    with SingleTickerProviderStateMixin {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  late List<PredictionHorseDetail> _sortedHorses;
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AiPredictionService _predictionService = AiPredictionService();
  int? _touchedSpotIndex;

  late Future<Map<String, dynamic>> _pageDataFuture;

  @override
  void initState() {
    super.initState();
    _sortedHorses = List.from(widget.raceData.horses);
    _tabController = TabController(length: 4, vsync: this);
    _pageDataFuture = _loadPageData();
  }

  Future<void> _handleTuneAndRecalculate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AiPredictionSettingsPage(raceId: widget.raceId),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI予測を再計算しています...')),
      );
      await _predictionService.calculatePredictionScores(widget.raceData, widget.raceId);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI予測を更新しました。')),
      );
      setState(() {
        _pageDataFuture = _loadPageData();
      });
    }
  }

  Future<Map<String, dynamic>> _loadPageData() async {
    var predictions = await _dbHelper.getAiPredictionsForRace(widget.raceId);

    if (predictions.isEmpty) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('AI総合予測'),
          content: const Text('このレースのAI予測をまだ行っていません。\nデフォルト設定（バランス重視）で予測を計算しますか？\n（計算には少し時間がかかります）'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('戻る'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('tune'),
              child: const Text('チューニング'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('yes'),
              child: const Text('はい'),
            ),
          ],
        ),
      );

      if (result == 'yes' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI予測を計算しています...')),
        );
        await _predictionService.calculatePredictionScores(widget.raceData, widget.raceId);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        predictions = await _dbHelper.getAiPredictionsForRace(widget.raceId);
      } else if (result == 'tune' && mounted) {
        await _handleTuneAndRecalculate();
        predictions = await _dbHelper.getAiPredictionsForRace(widget.raceId);
      } else {
        if (mounted) Navigator.of(context).pop();
        throw Exception('予測がキャンセルされました。');
      }
    }

    if (predictions.isEmpty) {
      throw Exception('予測データの生成に失敗しました。');
    }

    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    for (var horse in widget.raceData.horses) {
      allPastRecords[horse.horseId] = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
    }

    final overallScores = {for (var p in predictions) p.horseId: p.overallScore};
    final summary = SummaryGenerator.generatePredictionSummary(widget.raceData, overallScores, allPastRecords);
    final Map<String, dynamic> analysisDetails = {};
    for (var p in predictions) {
      if (p.analysisDetailsJson != null) {
        analysisDetails[p.horseId] = json.decode(p.analysisDetailsJson!);
      }
    }

    final Map<String, String> legStyles = {};
    for (var horse in widget.raceData.horses) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];
      legStyles[horse.horseId] = LegStyleAnalyzer.getRunningStyle(pastRecords).primaryStyle;
    }

    final statisticsService = StatisticsService();
    final pastRaceResults = await statisticsService.fetchPastRacesForAnalysis(widget.raceData.raceName, widget.raceData.raceId);

    widget.raceData.racePacePrediction = RaceAnalyzer.predictRacePace(widget.raceData.horses, allPastRecords, pastRaceResults);

    final raceStats = await _dbHelper.getRaceStatistics(widget.raceData.raceId);

    CoursePreset? coursePreset;
    final dbHelper = DatabaseHelper();
    final venueCode = RaceAnalyzer.venueCodeMap[widget.raceData.venue];
    String trackType = '';
    String distance = '';
    final raceInfo = widget.raceData.raceDetails1 ?? '';
    if (raceInfo.contains('障')) {
      trackType = 'obstacle';
    } else if (raceInfo.contains('ダ')) {
      trackType = 'dirt';
    } else {
      trackType = 'shiba';
    }
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      distance = distanceMatch.group(1)!;
    }
    final courseId = '${venueCode}_${trackType}_$distance';
    coursePreset = await dbHelper.getCoursePreset(courseId);

    for (var horse in widget.raceData.horses) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];
      horse.conditionFit = ConditionAnalyzer.analyzeConditionFit(
        horse: horse,
        raceData: widget.raceData,
        pastRecords: pastRecords,
        raceStats: raceStats,
      );
    }

    return {
      'predictions': predictions,
      'predictionSummary': summary,
      'analysisDetails': analysisDetails,
      'legStyles': legStyles,
      'coursePreset': coursePreset,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getRankFromScore(double score) {
    if (score >= 90) return 'S';
    if (score >= 85) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 75) return 'B+';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C+';
    if (score >= 50) return 'C';
    return 'D';
  }

  void _sortHorses(Map<String, double> overallScores, Map<String, double> expectedValues) {
    _sortedHorses.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 2:
          final scoreA = overallScores[a.horseId] ?? 0.0;
          final scoreB = overallScores[b.horseId] ?? 0.0;
          result = scoreB.compareTo(scoreA);
          break;
        case 3:
          final valueA = expectedValues[a.horseId] ?? -1.0;
          final valueB = expectedValues[b.horseId] ?? -1.0;
          result = valueB.compareTo(valueA);
          break;
        case 0:
        default:
          result = a.horseNumber.compareTo(b.horseNumber);
          break;
      }
      return _sortAscending ? result : -result;
    });
  }

  Color _getGateColor(int gateNumber) {
    switch (gateNumber) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink.shade200;
      default: return Colors.grey;
    }
  }

  Color _getTextColorForGate(int gateNumber) {
    switch (gateNumber) {
      case 1:
      case 5:
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _pageDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('データ読み込みエラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('データがありません。'));
        }

        final pageData = snapshot.data!;
        final List<AiPrediction> predictions = pageData['predictions'];
        final String predictionSummary = pageData['predictionSummary'];
        final Map<String, dynamic> analysisDetails = pageData['analysisDetails'];
        final Map<String, String> legStyles = pageData['legStyles'];
        final CoursePreset? coursePreset = pageData['coursePreset'];

        final overallScores = {for (var p in predictions) p.horseId: p.overallScore};
        final expectedValues = {for (var p in predictions) p.horseId: p.expectedValue};

        _sortHorses(overallScores, expectedValues);

        return Column(
          children: [
            Container(
              child: ThemedTabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: '展開予想'),
                  Tab(text: '推奨馬'),
                  Tab(text: '複合適性'),
                  Tab(text: '全馬リスト'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSummaryTab(predictionSummary, legStyles, overallScores, coursePreset),
                  _buildRecommendationTab(overallScores, expectedValues),
                  _buildConditionFitTab(),
                  _buildAllHorsesListCard(analysisDetails, overallScores, expectedValues),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryTab(String predictionSummary, Map<String, String> legStyles, Map<String, double> overallScores, CoursePreset? coursePreset) {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        _buildRaceSummaryCard(predictionSummary, legStyles, overallScores, coursePreset),
      ],
    );
  }

  Widget _buildRecommendationTab(Map<String, double> overallScores, Map<String, double> expectedValues) {
    final hitFocusHorses = [...widget.raceData.horses]
      ..sort((a, b) {
        final scoreA = overallScores[a.horseId] ?? 0.0;
        final scoreB = overallScores[b.horseId] ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

    final recoveryFocusHorses = [...widget.raceData.horses]
        .where((h) => (expectedValues[h.horseId] ?? -1.0) > 0)
        .toList()
      ..sort((a, b) {
        final valueA = expectedValues[a.horseId] ?? -1.0;
        final valueB = expectedValues[b.horseId] ?? -1.0;
        return valueB.compareTo(valueA);
      });

    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        _buildDualPredictionCard(hitFocusHorses.take(3).toList(),
            recoveryFocusHorses.take(3).toList(), overallScores, expectedValues),
      ],
    );
  }

  Widget _buildRaceSummaryCard(String predictionSummary, Map<String, String> legStyles, Map<String, double> overallScores, CoursePreset? coursePreset) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.raceData.raceName,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _handleTuneAndRecalculate,
                  icon: const Icon(Icons.tune),
                  label: const Text('AIチューニング'),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              'AI展開予想 解説',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              predictionSummary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            if (coursePreset != null)
              Container(
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                    color: Colors.lightGreen.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, size: 16, color: Colors.green.shade800,),
                        const SizedBox(width: 4),
                        Text(
                          'コースのキーポイント',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.green.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coursePreset.keyPoints,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('能力・人気', style: TextStyle(fontWeight: FontWeight.bold)),
                        _buildHelpIcon('能力・人気', '横軸が『人気』、縦軸がAIの『総合評価スコア』です。右上にいる馬ほど『人気と実力を兼ね備えた馬』、左上にいる馬ほど『人気はないがAI評価が高い妙味のある馬』と分析できます。'),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 250,
                    child: _buildAbilityPopularityTab(overallScores, legStyles),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilityPopularityTab(Map<String, double> overallScores, Map<String, String> legStyles) {
    final spots = widget.raceData.horses.map((horse) {
      final score = overallScores[horse.horseId] ?? 0.0;
      final popularity = horse.popularity?.toDouble() ?? (widget.raceData.horses.length + 1).toDouble();
      final style = legStyles[horse.horseId] ?? '不明';
      return ScatterSpot(
        popularity,
        score,
        dotPainter: _HorseNumberDotPainter(
          _getColorForLegStyle(style),
          horse.horseNumber.toString(),
          radius: 9,
        ),
      );
    }).toList();

    final scores = overallScores.values;
    double minScore = scores.isNotEmpty ? scores.reduce(min) : 0;
    double maxScore = scores.isNotEmpty ? scores.reduce(max) : 100;
    const padding = 2.0;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: 0,
                maxX: widget.raceData.horses.length + 2,
                minY: (minScore - padding).floorToDouble(),
                maxY: (maxScore + 2).ceilToDouble(),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(axisNameWidget: Text('人気 →')),
                  leftTitles: AxisTitles(axisNameWidget: Text('スコア →')),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
                showingTooltipIndicators: _touchedSpotIndex != null ? [_touchedSpotIndex!] : [],
                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (event, response) {
                    if (response == null || response.touchedSpot == null) {
                      if (_touchedSpotIndex != null) {
                        setState(() {
                          _touchedSpotIndex = null;
                        });
                      }
                      return;
                    }
                    if (event is FlTapUpEvent) {
                      final spotIndex = response.touchedSpot!.spotIndex;
                      setState(() {
                        if (_touchedSpotIndex == spotIndex) {
                          _touchedSpotIndex = null;
                        } else {
                          _touchedSpotIndex = spotIndex;
                        }
                      });
                    }
                  },
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (spot) => Colors.black.withAlpha(204),
                    tooltipRoundedRadius: 4,
                    tooltipPadding: const EdgeInsets.all(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpot) {
                      final horse = widget.raceData.horses[spots.indexOf(touchedSpot)];
                      return ScatterTooltipItem(
                        '${horse.horseNumber} ${horse.horseName}\nスコア: ${touchedSpot.y.toStringAsFixed(1)}\n人気: ${touchedSpot.x.toInt()}番',
                        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        bottomMargin: 10,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(_getColorForLegStyle('逃げ'), '逃げ'),
              _buildLegendItem(_getColorForLegStyle('先行'), '先行'),
              _buildLegendItem(_getColorForLegStyle('差し'), '差し'),
              _buildLegendItem(_getColorForLegStyle('追込'), '追込'),
              _buildLegendItem(_getColorForLegStyle('不明'), '不明'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Color _getColorForLegStyle(String style) {
    switch (style) {
      case '逃げ': return Colors.red;
      case '先行': return Colors.blue;
      case '差し': return Colors.orange;
      case '追込': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildDualPredictionCard(List<PredictionHorseDetail> hitHorses, List<PredictionHorseDetail> recoveryHorses, Map<String, double> overallScores, Map<String, double> expectedValues) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('的中重視 (◎〇▲)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                _buildHelpIcon('的中重視 (◎〇▲)', 'コース適性や騎手との相性、近走の安定感などを総合的に評価した『総合評価スコア』が高い順に選出しています。堅実な的中を狙う場合の参考にしてください。'),
              ],
            ),
            _buildPredictionColumnContent(hitHorses, true, overallScores, expectedValues),
            const Divider(height: 24),
            Row(
              children: [
                Text('回収率重視 (穴妙激)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                _buildHelpIcon('回収率重視 (穴妙激)', 'AIが算出した勝率と、実際のオッズを比較して『馬券的な妙味（期待値）』が高い順に選出しています。人気薄の馬が選ばれやすく、高配当を狙う場合の参考にしてください。'),
              ],
            ),
            _buildPredictionColumnContent(recoveryHorses, false, overallScores, expectedValues),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionColumnContent(List<PredictionHorseDetail> horses, bool isHitFocus, Map<String, double> overallScores, Map<String, double> expectedValues) {
    const marks = ['◎', '〇', '▲'];
    const recoveryMarks = ['穴', '妙', '激'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (horses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('推奨馬なし', style: TextStyle(color: Colors.grey)),
          )
        else
          ...List.generate(min(horses.length, 3), (index) {
            final horse = horses[index];
            final mark = isHitFocus ? marks[index] : recoveryMarks[index];
            return _buildRecommendedHorseTile(horse, mark, isHitFocus, overallScores, expectedValues);
          }),
      ],
    );
  }

  Widget _buildRecommendedHorseTile(PredictionHorseDetail horse, String mark, bool isHitFocus, Map<String, double> overallScores, Map<String, double> expectedValues) {
    final score = overallScores[horse.horseId] ?? 0.0;
    final expectedValue = expectedValues[horse.horseId] ?? -1.0;

    final totalScore = overallScores.values.fold(0.0, (sum, s) => sum + s);
    final appWinRate = totalScore > 0 ? (score / totalScore) * 100 : 0.0;
    final marketWinRate = horse.odds != null && horse.odds! > 0 ? (1.0 / horse.odds!) * 100 * 0.75 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(mark, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (isHitFocus)
                Text('総合スコア: ${score.toStringAsFixed(1)}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold))
              else
                Text('期待値: ${expectedValue.toStringAsFixed(2)}', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${horse.horseNumber} ${horse.horseName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (isHitFocus)
            const Row(
              children: [
                Chip(label: Text('#コース巧者', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                SizedBox(width: 4),
                Chip(label: Text('#騎手得意', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
              ],
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                  'アプリ勝率${appWinRate.toStringAsFixed(1)}% > 市場勝率${marketWinRate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllHorsesListCard(Map<String, dynamic> analysisDetails, Map<String, double> overallScores, Map<String, double> expectedValues) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: DataTable2(
          columnSpacing: 16.0,
          horizontalMargin: 0,
          minWidth: 650,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columns: [
            DataColumn2(
              label: const Text('馬番'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortHorses(overallScores, expectedValues);
                });
              },
            ),
            const DataColumn2(label: Text('馬名'), fixedWidth: 150),
            DataColumn2(
              label: Wrap(
                spacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('総合評価'),
                  _buildHelpIcon('総合評価', '脚質、コース適性、馬場状態、騎手との相性など、複数の要素を総合的に評価したスコアです。各要素の重視度は『AIチューニング』設定で変更できます。'),
                ],
              ),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortHorses(overallScores, expectedValues);
                });
              },
            ),
            DataColumn2(
              label: Wrap(
                spacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('期待値'),
                  _buildHelpIcon('期待値', 'AIが算出した『この馬が勝つ確率』と、単勝オッズから逆算した『市場が考える勝率』を比較した指標です。1.0を超えると、オッズの割にAIからの評価が高く、馬券的な妙味があると判断できます。'),
                ],
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                  _sortHorses(overallScores, expectedValues);
                });
              },
            ),
            const DataColumn2(label: Text('先行力'), numeric: true),
            const DataColumn2(label: Text('瞬発力'), numeric: true),
            const DataColumn2(label: Text('スタミナ'), numeric: true),
          ],
          rows: _sortedHorses.map((horse) {
            final score = overallScores[horse.horseId] ?? 0.0;
            final rank = _getRankFromScore(score);
            final expectedValue = expectedValues[horse.horseId] ?? -1.0;
            final details = analysisDetails[horse.horseId] ?? {};
            final earlySpeed = details['earlySpeedScore'] ?? 0.0;
            final finishingKick = details['finishingKickScore'] ?? 0.0;
            final stamina = details['staminaScore'] ?? 0.0;

            return DataRow(
              cells: [
                DataCell(
                  Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getGateColor(horse.gateNumber),
                        border: horse.gateNumber == 1 ? Border.all(color: Colors.grey) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        horse.horseNumber.toString(),
                        style: TextStyle(
                          color: _getTextColorForGate(horse.gateNumber),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(Text(horse.horseName)),
                DataCell(Text('$rank (${score.toStringAsFixed(1)})')),
                DataCell(Text(expectedValue.toStringAsFixed(2))),
                DataCell(_buildScoreIndicator(earlySpeed)),
                DataCell(_buildScoreIndicator(finishingKick)),
                DataCell(_buildScoreIndicator(stamina)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(double score) {
    return Tooltip(
      message: score.toStringAsFixed(1),
      child: Container(
        width: 60,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: FractionallySizedBox(
          widthFactor: score / 100,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.red, Colors.green, score / 100),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionFitTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DataTable2(
        columnSpacing: 2.0,
        horizontalMargin: 12,
        minWidth: 800,
        columns: const [
          DataColumn2(label: Text('馬番'), fixedWidth: 40),
          DataColumn2(label: Text('馬名'), fixedWidth: 160),
          DataColumn2(label: Text('馬場'), fixedWidth: 80),
          DataColumn2(label: Text('ペース'), fixedWidth: 80),
          DataColumn2(label: Text('斤量'), fixedWidth: 80),
          DataColumn2(label: Text('枠順'), fixedWidth: 80),
        ],
        rows: widget.raceData.horses.map((horse) {
          return DataRow(cells: [
            DataCell(
              Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getGateColor(horse.gateNumber),
                    border: horse.gateNumber == 1 ? Border.all(color: Colors.grey) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    horse.horseNumber.toString(),
                    style: TextStyle(
                      color: _getTextColorForGate(horse.gateNumber),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataCell(Text(horse.horseName)),
            DataCell(_buildFitCell(horse.conditionFit?.trackFit)),
            DataCell(_buildFitCell(horse.conditionFit?.paceFit)),
            DataCell(_buildFitCell(horse.conditionFit?.weightFit)),
            DataCell(_buildFitCell(horse.conditionFit?.gateFit)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildFitCell(FitnessRating? rating) {
    rating ??= FitnessRating.unknown;
    return Text(
      _getRatingText(rating),
      style: TextStyle(
        color: _getRatingColor(rating),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _getRatingText(FitnessRating rating) {
    switch (rating) {
      case FitnessRating.excellent: return '◎ 絶好';
      case FitnessRating.good: return '〇 好条件';
      case FitnessRating.average: return '△ 普通';
      case FitnessRating.poor: return '✕ 割引';
      case FitnessRating.unknown: return '－ データなし';
    }
  }

  Color _getRatingColor(FitnessRating rating) {
    switch (rating) {
      case FitnessRating.excellent: return Colors.red;
      case FitnessRating.good: return Colors.orange;
      case FitnessRating.average: return Colors.black87;
      case FitnessRating.poor: return Colors.blue;
      case FitnessRating.unknown: return Colors.grey;
    }
  }

  Widget _buildHelpIcon(String title, String content) {
    return IconButton(
      icon: Icon(Icons.help_outline, color: Colors.grey.shade500, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
        );
      },
    );
  }
}