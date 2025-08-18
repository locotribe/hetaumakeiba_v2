// lib/screens/comprehensive_prediction_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/prediction_analyzer.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

// lib/screens/comprehensive_prediction_page.dart のファイル末尾などにあるクラス

// ▼▼▼【このクラスを完全に置き換え】▼▼▼
class _HorseNumberDotPainter extends FlDotPainter {
  final Color color;
  final String horseNumber;
  final double radius;

  _HorseNumberDotPainter(this.color, this.horseNumber, {this.radius = 9});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset center) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);

    final textStyle = TextStyle(
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

  @override
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
// ▲▲▲【ここまでを完全に置き換え】▲▲▲

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
  // ▼▼▼【テスト用コード】▼▼▼
  String _predictionSummary = '';
  Map<String, double> _earlySpeedScores = {};
  Map<String, double> _finishingKickScores = {};
  Map<String, double> _staminaScores = {};
  Map<String, List<HorseRaceRecord>> _allPastRecords = {};
  // ▲▲▲【テスト用コード】▲▲▲

  @override
  void initState() {
    super.initState();
    // 初期状態では馬番順にソート
    _sortedHorses = List.from(widget.raceData.horses);
    _sortHorses();
    _tabController = TabController(length: 3, vsync: this);
    _calculateLegStylesAndDevelopment();
    // ▼▼▼【テスト用コード】▼▼▼
    _calculateDetailedScores();
    // ▲▲▲【テスト用コード】▲▲▲
  }

  // ▼▼▼【テスト用コード】▼▼▼
  void _generateSummary() {
    setState(() {
      _predictionSummary = PredictionAnalyzer.generatePredictionSummary(widget.raceData, widget.overallScores, _allPastRecords);
    });
  }

  Future<void> _calculateDetailedScores() async {
    final Map<String, double> earlySpeedScores = {};
    final Map<String, double> finishingKickScores = {};
    final Map<String, double> staminaScores = {};

    for (var horse in widget.raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      earlySpeedScores[horse.horseId] = PredictionAnalyzer.evaluateEarlySpeedFit(horse, widget.raceData, pastRecords);
      finishingKickScores[horse.horseId] = PredictionAnalyzer.evaluateFinishingKickFit(horse, widget.raceData, pastRecords);
      staminaScores[horse.horseId] = PredictionAnalyzer.evaluateStaminaFit(horse, widget.raceData, pastRecords);
    }

    if (mounted) {
      setState(() {
        _earlySpeedScores = earlySpeedScores;
        _finishingKickScores = finishingKickScores;
        _staminaScores = staminaScores;
      });
    }
  }
  // ▲▲▲【テスト用コード】▲▲▲

  void _calculateLegStylesAndDevelopment() async {
    final Map<String, String> legStyles = {};
    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    for (var horse in widget.raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;
      legStyles[horse.horseId] = PredictionAnalyzer.getRunningStyle(pastRecords);
    }

    // ▼▼▼【修正箇所】▼▼▼
    final statisticsService = StatisticsService();
    final pastRaceResults = await statisticsService.fetchPastRacesForAnalysis(widget.raceData.raceName, widget.raceData.raceId);
    final cornersToPredict = <String>{};
    for (final result in pastRaceResults) {
      for (final cornerPassage in result.cornerPassages) {
        final cornerName = cornerPassage.split(':').first.trim();
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
    final sortedCorners = cornersToPredict.toList()..sort();

    final development = PredictionAnalyzer.simulateRaceDevelopment(widget.raceData.horses, legStyles, sortedCorners.isNotEmpty ? sortedCorners : ['1-2コーナー', '3コーナー', '4コーナー']);
    // ▲▲▲【修正箇所】▲▲▲

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
        case 1: // 総合スコア
          final scoreA = widget.overallScores[a.horseId] ?? 0.0;
          final scoreB = widget.overallScores[b.horseId] ?? 0.0;
          result = scoreB.compareTo(scoreA); // 降順がデフォルト
          break;
        case 2: // 期待値
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
    // 的中重視の推奨馬 (スコア上位3頭)
    final hitFocusHorses = [...widget.raceData.horses]..sort((a, b) {
      final scoreA = widget.overallScores[a.horseId] ?? 0.0;
      final scoreB = widget.overallScores[b.horseId] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    // 回収率重視の推奨馬 (期待値0以上の中から上位3頭)
    final recoveryFocusHorses = [...widget.raceData.horses]
      ..where((h) => (widget.expectedValues[h.horseId] ?? -1.0) > 0)
      ..sort((a, b) {
        final valueA = widget.expectedValues[a.horseId] ?? -1.0;
        final valueB = widget.expectedValues[b.horseId] ?? -1.0;
        return valueB.compareTo(valueA);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI総合予測'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _buildRaceSummaryCard(),
          const SizedBox(height: 16),
          _buildDualPredictionCard(hitFocusHorses.take(3).toList(), recoveryFocusHorses.take(3).toList()), // エリア2
          const SizedBox(height: 16),
          _buildAllHorsesListCard(), // エリア3
        ],
      ),
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
            Text(widget.raceData.raceName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('予測ペース', widget.raceData.racePacePrediction?.predictedPace ?? '不明'),
                _buildSummaryItem('有利な脚質', widget.raceData.racePacePrediction?.advantageousStyle ?? '不明'),
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
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColorDark,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Theme.of(context).primaryColor,
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
                        controller: _tabController,
                        children: [
                          _buildLegStyleCompositionTab(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListView(
                              children: _raceDevelopment.entries.map((entry) {
                                return _buildCornerPredictionDisplay(entry.key, entry.value);
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
            // ▼▼▼【テスト用コード】▼▼▼
            Text(
              '解説: $_predictionSummary',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            // ▲▲▲【テスト用コード】▲▲▲
          ],
        ),
      ),
    );
  }

  // ▼▼▼【修正箇所】▼▼▼
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
              child: Text(char, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          Text(cornerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  // ▲▲▲【修正箇所】▲▲▲

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
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              if (response?.spot != null) {
                final index = response!.spot!.touchedBarGroup.x;
                final style = ['逃げ', '先行', '差し', '追込', '不明'][index];
                final horses = groupedByLegStyle[style]!;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('脚質: $style'),
                    content: SizedBox(
                      width: double.minPositive,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: horses.length,
                        itemBuilder: (context, i) => Text('${horses[i].horseNumber} ${horses[i].horseName}'),
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))],
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
      final popularity = horse.popularity?.toDouble() ?? (widget.raceData.horses.length + 1).toDouble();
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
    const padding = 5.0;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: 0,
                maxX: (widget.raceData.horses.length + 1).toDouble(),
                minY: (minScore - padding).floorToDouble(),
                maxY: (maxScore - padding).ceilToDouble(),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(axisNameWidget: Text('人気 →')),
                  leftTitles: AxisTitles(axisNameWidget: Text('スコア →')),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
                    tooltipBorderRadius: BorderRadius.circular(4),
                    tooltipPadding: const EdgeInsets.all(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpot) {
                      final index = spots.indexWhere(
                            (s) => s.x == touchedSpot.x && s.y == touchedSpot.y,
                      );
                      if (index != -1 && index < widget.raceData.horses.length) {
                        final horse = widget.raceData.horses[index];
                        return ScatterTooltipItem(
                          '${horse.horseName}\nスコア: ${touchedSpot.y.toStringAsFixed(1)}',
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        );
                      }
                      return ScatterTooltipItem(
                        '',
                        textStyle: const TextStyle(),
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
    switch(style) {
      case '逃げ': return Colors.red;
      case '先行': return Colors.blue;
      case '差し': return Colors.orange;
      case '追込': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // エリア2: デュアル予測推奨
  Widget _buildDualPredictionCard(List<PredictionHorseDetail> hitHorses, List<PredictionHorseDetail> recoveryHorses) {
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

  Widget _buildPredictionColumn(String title, List<PredictionHorseDetail> horses, bool isHitFocus) {
    const marks = ['◎', '〇', '▲'];
    const recoveryMarks = ['穴', '妙', '激'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildRecommendedHorseTile(PredictionHorseDetail horse, String mark, bool isHitFocus) {
    final score = widget.overallScores[horse.horseId] ?? 0.0;
    final expectedValue = widget.expectedValues[horse.horseId] ?? -1.0;

    // アプリ勝率を計算
    final totalScore = widget.overallScores.values.fold(0.0, (sum, s) => sum + s);
    final appWinRate = totalScore > 0 ? (score / totalScore) * 100 : 0.0;
    // 市場勝率を計算 (単勝オッズから)
    final marketWinRate = horse.odds != null && horse.odds! > 0 ? (1.0 / horse.odds!) * 100 * 0.8 : 0.0; // 控除率20%と仮定

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
              Text(mark, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (isHitFocus)
                Text('総合スコア: ${score.toStringAsFixed(1)}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold))
              else
                Text('期待値: ${expectedValue.toStringAsFixed(2)}', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          // 2段目: 馬番と馬名
          Text('${horse.horseNumber} ${horse.horseName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          // 3段目: 詳細
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

  // エリア3: 全出走馬詳細リスト
  Widget _buildAllHorsesListCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全出走馬 詳細データ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('馬番'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                        _sortHorses();
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('総合評価'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                        _sortHorses();
                      });
                    },
                  ),
                  DataColumn(
                    label: const Text('期待値'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortColumnIndex = columnIndex;
                        _sortAscending = ascending;
                        _sortHorses();
                      });
                    },
                  ),
                  const DataColumn(label: Text('馬名')),
                  // ▼▼▼【テスト用コード】▼▼▼
                  const DataColumn(label: Text('先行力'), numeric: true),
                  const DataColumn(label: Text('瞬発力'), numeric: true),
                  const DataColumn(label: Text('スタミナ'), numeric: true),
                  // ▲▲▲【テスト用コード】▲▲▲
                ],
                rows: _sortedHorses.map((horse) {
                  final score = widget.overallScores[horse.horseId] ?? 0.0;
                  final rank = _getRankFromScore(score);
                  final expectedValue = widget.expectedValues[horse.horseId] ?? -1.0;
                  // ▼▼▼【テスト用コード】▼▼▼
                  final earlySpeed = _earlySpeedScores[horse.horseId] ?? 0.0;
                  final finishingKick = _finishingKickScores[horse.horseId] ?? 0.0;
                  final stamina = _staminaScores[horse.horseId] ?? 0.0;
                  // ▲▲▲【テスト用コード】▲▲▲
                  return DataRow(
                    cells: [
                      DataCell(Text(horse.horseNumber.toString())),
                      DataCell(Text('$rank (${score.toStringAsFixed(1)})')),
                      DataCell(Text(expectedValue.toStringAsFixed(2))),
                      DataCell(Text(horse.horseName)),
                      // ▼▼▼【テスト用コード】▼▼▼
                      DataCell(_buildScoreIndicator(earlySpeed)),
                      DataCell(_buildScoreIndicator(finishingKick)),
                      DataCell(_buildScoreIndicator(stamina)),
                      // ▲▲▲【テスト用コード】▲▲▲
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ▼▼▼【テスト用コード】▼▼▼
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
// ▲▲▲【テスト用コード】▲▲▲
}