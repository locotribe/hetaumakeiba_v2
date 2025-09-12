// lib/screens/comprehensive_prediction_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/ai_prediction_analyzer.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/services/jockey_analysis_service.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:data_table_2/data_table_2.dart';

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
  final Map<String, double> overallScores;
  final Map<String, double> expectedValues;

  const ComprehensivePredictionPage({
    super.key,
    required this.raceData,
    required this.overallScores,
    required this.expectedValues,
  });

  @override
  State<ComprehensivePredictionPage> createState() => _ComprehensivePredictionPageState();
}

class _ComprehensivePredictionPageState extends State<ComprehensivePredictionPage>
    with SingleTickerProviderStateMixin {
  // ソート用の状態変数
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  // ソート対象の馬リスト
  late List<PredictionHorseDetail> _sortedHorses;
  late TabController _tabController;
  Map<String, String> _legStyles = {};
  Map<String, String> _raceDevelopment = {};
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _predictionSummary = '';
  Map<String, double> _earlySpeedScores = {};
  Map<String, double> _finishingKickScores = {};
  Map<String, double> _staminaScores = {};
  Map<String, List<HorseRaceRecord>> _allPastRecords = {};
  int? _touchedSpotIndex;
  final JockeyAnalysisService _jockeyAnalysisService = JockeyAnalysisService();
  Map<String, JockeyStats> _jockeyStats = {};

  @override
  void initState() {
    super.initState();
    _sortedHorses = List.from(widget.raceData.horses);
    _sortHorses();
    _tabController = TabController(length: 5, vsync: this);
    _calculateLegStylesAndDevelopment();
    _calculateDetailedScores();
    _loadJockeyAnalysisData();
  }

  Future<void> _loadJockeyAnalysisData() async {
    final jockeyIds = widget.raceData.horses.map((h) => h.jockeyId).toList();
    final stats = await _jockeyAnalysisService.analyzeAllJockeys(jockeyIds, raceData: widget.raceData);
    if (mounted) {
      setState(() {
        _jockeyStats = stats;
      });
    }
  }

  void _generateSummary() {
    setState(() {
      _predictionSummary = AiPredictionAnalyzer.generatePredictionSummary(
          widget.raceData, widget.overallScores, _allPastRecords);
    });
  }

  Future<void> _calculateDetailedScores() async {
    final Map<String, double> earlySpeedScores = {};
    final Map<String, double> finishingKickScores = {};
    final Map<String, double> staminaScores = {};

    for (var horse in widget.raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(
          horse.horseId);
      earlySpeedScores[horse.horseId] =
          AiPredictionAnalyzer.evaluateEarlySpeedFit(
              horse, widget.raceData, pastRecords);
      finishingKickScores[horse.horseId] =
          AiPredictionAnalyzer.evaluateFinishingKickFit(
              horse, widget.raceData, pastRecords);
      staminaScores[horse.horseId] = AiPredictionAnalyzer.evaluateStaminaFit(
          horse, widget.raceData, pastRecords);
    }

    if (mounted) {
      setState(() {
        _earlySpeedScores = earlySpeedScores;
        _finishingKickScores = finishingKickScores;
        _staminaScores = staminaScores;
      });
    }
  }

  void _calculateLegStylesAndDevelopment() async {
    final raceStats = await _dbHelper.getRaceStatistics(widget.raceData.raceId);

    final Map<String, String> legStyles = {};
    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    for (var horse in widget.raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(
          horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;
      legStyles[horse.horseId] =
          AiPredictionAnalyzer.getRunningStyle(pastRecords);

      horse.conditionFit = AiPredictionAnalyzer.analyzeConditionFit(
        horse: horse,
        raceData: widget.raceData,
        pastRecords: pastRecords,
        raceStats: raceStats,
      );
    }

    final statisticsService = StatisticsService();
    final pastRaceResults = await statisticsService.fetchPastRacesForAnalysis(
        widget.raceData.raceName, widget.raceData.raceId);
    final cornersToPredict = <String>{};
    for (final result in pastRaceResults) {
      for (final cornerPassage in result.cornerPassages) {
        final cornerName = cornerPassage
            .split(':')
            .first
            .trim();
        // 1-2コーナーのような表記を統一
        if (cornerName.contains('1') || cornerName.contains('2')) {
          cornersToPredict.add('1-2コーナー');
        } else if (cornerName.contains('3')) {
          cornersToPredict.add('3コーナー');
        } else if (cornerName.contains('4')) {
          cornersToPredict.add('4コーナー');
        }
      }
    }
    final sortedCorners = cornersToPredict.toList()
      ..sort();

    final development = AiPredictionAnalyzer.simulateRaceDevelopment(
        widget.raceData,
        legStyles,
        allPastRecords,
        sortedCorners.isNotEmpty ? sortedCorners : [
          '1-2コーナー',
          '3コーナー',
          '4コーナー'
        ]
    );
    if (mounted) {
      setState(() {
        _legStyles = legStyles;
        _raceDevelopment = development;
        _allPastRecords = allPastRecords;
        _generateSummary();
      });
    }
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

  void _sortHorses() {
    _sortedHorses.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 2: // 総合スコア
          final scoreA = widget.overallScores[a.horseId] ?? 0.0;
          final scoreB = widget.overallScores[b.horseId] ?? 0.0;
          result = scoreB.compareTo(scoreA); // 降順がデフォルト
          break;
        case 3: // 期待値
          final valueA = widget.expectedValues[a.horseId] ?? -1.0;
          final valueB = widget.expectedValues[b.horseId] ?? -1.0;
          result = valueB.compareTo(valueA); // 降順がデフォルト
          break;
        case 0: // 馬番 (デフォルト)
        default:
          result = a.horseNumber.compareTo(b.horseNumber);
          break;
      }
      return _sortAscending ? result : -result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI総合予測'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '総合評価'),
            Tab(text: '推奨馬'),
            Tab(text: '騎手特性'),
            Tab(text: '複合適性'),
            Tab(text: '全馬リスト'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildRecommendationTab(),
          _buildJockeyStatsTab(),
          _buildConditionFitTab(),
          _buildAllHorsesListCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        _buildRaceSummaryCard(),
      ],
    );
  }

  Widget _buildRecommendationTab() {
    final hitFocusHorses = [...widget.raceData.horses]
      ..sort((a, b) {
        final scoreA = widget.overallScores[a.horseId] ?? 0.0;
        final scoreB = widget.overallScores[b.horseId] ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

    final recoveryFocusHorses = [...widget.raceData.horses]
        .where((h) => (widget.expectedValues[h.horseId] ?? -1.0) > 0)
        .toList()
      ..sort((a, b) {
        final valueA = widget.expectedValues[a.horseId] ?? -1.0;
        final valueB = widget.expectedValues[b.horseId] ?? -1.0;
        return valueB.compareTo(valueA);
      });

    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        _buildDualPredictionCard(hitFocusHorses.take(3).toList(),
            recoveryFocusHorses.take(3).toList()),
      ],
    );
  }

  // エリア1: レース全体予測サマリー
  Widget _buildRaceSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.raceData.raceName, style: Theme
                .of(context)
                .textTheme
                .titleLarge),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('予測ペース',
                    widget.raceData.racePacePrediction?.predictedPace ??
                        '不明'),
                _buildSummaryItem('有利な脚質',
                    widget.raceData.racePacePrediction?.advantageousStyle ??
                        '不明'),
              ],
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
              child: DefaultTabController(
                length: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: Colors.grey.shade100,
                      child: TabBar(
                        labelColor: Theme
                            .of(context)
                            .primaryColorDark,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Theme
                            .of(context)
                            .primaryColor,
                        tabs: const [
                          Tab(text: '脚質構成'),
                          Tab(text: 'コーナー予測'),
                          Tab(text: '能力・人気'),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 250, // TabBarViewの高さを指定
                      child: TabBarView(
                        children: [
                          _buildLegStyleCompositionTab(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListView(
                              children: _raceDevelopment.entries.map((entry) {
                                return _buildCornerPredictionDisplay(
                                    entry.key, entry.value);
                              }).toList(),
                            ),
                          ),
                          _buildAbilityPopularityTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '解説: $_predictionSummary',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerPredictionDisplay(String cornerName, String prediction) {
    List<Widget> buildWidgetsFromString(String text) {
      final widgets = <Widget>[];
      String currentNumber = "";

      for (int i = 0; i < text.length; i++) {
        String char = text[i];
        if (int.tryParse(char) != null) {
          currentNumber += char;
        } else {
          if (currentNumber.isNotEmpty) {
            widgets.add(_buildHorseNumberChip(currentNumber));
            currentNumber = "";
          }
          if (['(', ')', ',', '-', '=', '*'].contains(char)) {
            widgets.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: Text(char, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
            ));
          }
        }
      }
      if (currentNumber.isNotEmpty) {
        widgets.add(_buildHorseNumberChip(currentNumber));
      }
      return widgets;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cornerName, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 2.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: buildWidgetsFromString(prediction),
          )
        ],
      ),
    );
  }

  Widget _buildHorseNumberChip(String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 0.5)
      ),
      child: Text(number, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildLegStyleCompositionTab() {
    final Map<String, List<PredictionHorseDetail>> groupedByLegStyle = {
      '逃げ': [], '先行': [], '差し': [], '追込': [], '不明': [],
    };
    for (final horse in widget.raceData.horses) {
      final style = _legStyles[horse.horseId] ?? '不明';
      groupedByLegStyle[style]?.add(horse);
    }

    final barGroups = groupedByLegStyle.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) {
      return BarChartGroupData(
        x: ['逃げ', '先行', '差し', '追込', '不明'].indexOf(entry.key),
        barRods: [
          BarChartRodData(
            toY: entry.value.length.toDouble(),
            color: Colors.teal,
            width: 20,
          )
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const styles = ['逃げ', '先行', '差し', '追込', '不明'];
                  return Text(styles[value.toInt()]);
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response?.spot != null) {
                final index = response!.spot!.touchedBarGroup.x;
                final style = ['逃げ', '先行', '差し', '追込', '不明'][index];
                final horses = groupedByLegStyle[style]!;
                showDialog(
                  context: context,
                  builder: (context) =>
                      AlertDialog(
                        title: Text('脚質: $style'),
                        content: SizedBox(
                          width: double.minPositive,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: horses.length,
                            itemBuilder: (context, i) =>
                                Text('${horses[i].horseNumber} ${horses[i]
                                    .horseName}'),
                          ),
                        ),
                        actions: [TextButton(onPressed: () =>
                            Navigator.pop(context), child: const Text('閉じる'))
                        ],
                      ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAbilityPopularityTab() {
    final spots = widget.raceData.horses.map((horse) {
      final score = widget.overallScores[horse.horseId] ?? 0.0;
      final popularity = horse.popularity?.toDouble() ??
          (widget.raceData.horses.length + 1).toDouble();
      final style = _legStyles[horse.horseId] ?? '不明';
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

    final scores = widget.overallScores.values;
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
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(axisNameWidget: Text('人気 →')),
                  leftTitles: AxisTitles(axisNameWidget: Text('スコア →')),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
                showingTooltipIndicators: _touchedSpotIndex != null ? [
                  _touchedSpotIndex!
                ] : [],
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
                      final horse = widget.raceData.horses[spots.indexOf(
                          touchedSpot)];
                      return ScatterTooltipItem(
                        '${horse.horseNumber} ${horse
                            .horseName}\nスコア: ${touchedSpot.y
                            .toStringAsFixed(1)}\n人気: ${touchedSpot.x
                            .toInt()}番',
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
      case '逃げ':
        return Colors.red;
      case '先行':
        return Colors.blue;
      case '差し':
        return Colors.orange;
      case '追込':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: Theme
            .of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // エリア2: デュアル予測推奨
  Widget _buildDualPredictionCard(List<PredictionHorseDetail> hitHorses,
      List<PredictionHorseDetail> recoveryHorses) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPredictionColumn('的中重視 (◎〇▲)', hitHorses, true),
            const Divider(height: 24),
            _buildPredictionColumn('回収率重視 (穴妙)', recoveryHorses, false),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionColumn(String title,
      List<PredictionHorseDetail> horses, bool isHitFocus) {
    const marks = ['◎', '〇', '▲'];
    const recoveryMarks = ['穴', '妙', '激'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme
            .of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)),
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
            return _buildRecommendedHorseTile(horse, mark, isHitFocus);
          }),
      ],
    );
  }

  Widget _buildRecommendedHorseTile(PredictionHorseDetail horse, String mark,
      bool isHitFocus) {
    final score = widget.overallScores[horse.horseId] ?? 0.0;
    final expectedValue = widget.expectedValues[horse.horseId] ?? -1.0;

    // アプリ勝率を計算
    final totalScore = widget.overallScores.values.fold(
        0.0, (sum, s) => sum + s);
    final appWinRate = totalScore > 0 ? (score / totalScore) * 100 : 0.0;
    // 市場勝率を計算 (単勝オッズから)
    final marketWinRate = horse.odds != null && horse.odds! > 0 ? (1.0 /
        horse.odds!) * 100 * 0.8 : 0.0; // 控除率20%と仮定

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
          // 1段目: 予想印とスコア/期待値
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(mark, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
              if (isHitFocus)
                Text('総合スコア: ${score.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold))
              else
                Text('期待値: ${expectedValue.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          // 2段目: 馬番と馬名
          Text('${horse.horseNumber} ${horse.horseName}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          // 3段目: 詳細
          if (isHitFocus)
            const Row(
              children: [
                Chip(label: Text('#コース巧者', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact),
                SizedBox(width: 4),
                Chip(label: Text('#騎手得意', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact),
              ],
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                  'アプリ勝率${appWinRate.toStringAsFixed(
                      1)}% > 市場勝率${marketWinRate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)
              ),
            ),
        ],
      ),
    );
  }

  // エリア3: 全出走馬詳細リスト
  Widget _buildAllHorsesListCard() {
    // ★★★ ここからが差し替え箇所 ★★★
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DataTable2(
        columnSpacing: 12.0,
        horizontalMargin: 12,
        minWidth: 800, // 必要に応じて幅を調整
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        columns: [
          DataColumn2(
            label: Text('馬番'),
            fixedWidth: 50,
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndex = columnIndex;
                _sortAscending = ascending;
                _sortHorses();
              });
            },
          ),
          const DataColumn2(
            label: Text('馬名'),
            fixedWidth: 150,
          ),
          DataColumn2(
            label: const Text('総合評価'),
            fixedWidth: 100,
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndex = columnIndex;
                _sortAscending = ascending;
                _sortHorses();
              });
            },
          ),
          DataColumn2(
            label: const Text('期待値'),
            fixedWidth: 80,
            numeric: true,
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndex = columnIndex;
                _sortAscending = ascending;
                _sortHorses();
              });
            },
          ),
          const DataColumn2(label: Text('先行力'),
              fixedWidth: 80, numeric: true),
          const DataColumn2(label: Text('瞬発力'),
              fixedWidth: 80, numeric: true),
          const DataColumn2(label: Text('スタミナ'),
              fixedWidth: 80, numeric: true),
        ],
        rows: _sortedHorses.map((horse) {
          final score = widget.overallScores[horse.horseId] ?? 0.0;
          final rank = _getRankFromScore(score);
          final expectedValue = widget.expectedValues[horse.horseId] ?? -1.0;
          final earlySpeed = _earlySpeedScores[horse.horseId] ?? 0.0;
          final finishingKick = _finishingKickScores[horse.horseId] ?? 0.0;
          final stamina = _staminaScores[horse.horseId] ?? 0.0;
          return DataRow(
            cells: [
              DataCell(Text(horse.horseNumber.toString())),
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
    );
    // ★★★ ここまでが差し替え箇所 ★★★
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
            DataCell(Text(horse.horseNumber.toString())),
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

  // _buildConditionFitTab で使用するための新しいヘルパーメソッドを追加
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

  Widget _buildFitRow(String title, FitnessRating? rating) {
    rating ??= FitnessRating.unknown;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(title)),
          Expanded(
            child: Text(
              _getRatingText(rating),
              style: TextStyle(
                  color: _getRatingColor(rating), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingText(FitnessRating rating) {
    switch (rating) {
      case FitnessRating.excellent:
        return '◎ 絶好';
      case FitnessRating.good:
        return '〇 好条件';
      case FitnessRating.average:
        return '△ 普通';
      case FitnessRating.poor:
        return '✕ 割引';
      case FitnessRating.unknown:
        return '－ データなし';
    }
  }

  Color _getRatingColor(FitnessRating rating) {
    switch (rating) {
      case FitnessRating.excellent:
        return Colors.red;
      case FitnessRating.good:
        return Colors.orange;
      case FitnessRating.average:
        return Colors.black87;
      case FitnessRating.poor:
        return Colors.blue;
      case FitnessRating.unknown:
        return Colors.grey;
    }
  }

  Widget _buildJockeyStatsTab() {
    if (_jockeyStats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final sortedHorses = List<PredictionHorseDetail>.from(widget.raceData.horses)
      ..sort((a, b) => a.horseNumber.compareTo(b.horseNumber));

    return DataTable2(
      columnSpacing: 0.0,
      dataRowHeight: 60,
      columns: const [
        DataColumn2(
          label: Text('騎手\n(当コース)'),
        ),
        DataColumn2(
          label: Text('人気馬信頼度\n(1-3人気/複勝率)'),
        ),
        DataColumn2(
          label: Text('穴馬一発度\n(6人気~/単複回収率)'),
        ),
      ],
      rows: sortedHorses.map((horse) {
        final stats = _jockeyStats[horse.jockeyId];
        if (stats == null) {
          return DataRow(cells: [
            DataCell(Text('${horse.jockey} (データなし)')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
          ]);
        }

        final courseStatsString = stats.courseStats?.recordString ?? '0-0-0-0';

        return DataRow(
          cells: [
            DataCell(
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: <TextSpan>[
                    TextSpan(
                      text: stats.jockeyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: '($courseStatsString)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DataCell(
                Text(
                  '${stats.popularHorseStats.showRate.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
            ),
            DataCell(
                Text(
                  '単(${stats.unpopularHorseStats.winRecoveryRate.toStringAsFixed(0)}%)複(${stats.unpopularHorseStats.showRecoveryRate.toStringAsFixed(0)}%)',
                )
            ),
          ],
        );
      }).toList(),
    );
  }
}