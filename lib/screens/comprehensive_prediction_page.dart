// lib/screens/comprehensive_prediction_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'dart:math';

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

class _ComprehensivePredictionPageState extends State<ComprehensivePredictionPage> {
  // ソート用の状態変数
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  // ソート対象の馬リスト
  late List<PredictionHorseDetail> _sortedHorses;

  @override
  void initState() {
    super.initState();
    // 初期状態では馬番順にソート
    _sortedHorses = List.from(widget.raceData.horses);
    _sortHorses();
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
          _buildRaceSummaryCard(), // エリア1
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
            // TODO: 脚質構成グラフ
            Center(
              child: Container(
                height: 50,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text('(脚質構成グラフ表示エリア)'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '解説: 逃げ馬不在で前残りに注意。内枠の先行馬がレースの鍵を握る可能性が高い。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
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
                ],
                rows: _sortedHorses.map((horse) {
                  final score = widget.overallScores[horse.horseId] ?? 0.0;
                  final rank = _getRankFromScore(score);
                  final expectedValue = widget.expectedValues[horse.horseId] ?? -1.0;
                  return DataRow(
                    cells: [
                      DataCell(Text(horse.horseNumber.toString())),
                      DataCell(Text('$rank (${score.toStringAsFixed(1)})')),
                      DataCell(Text(expectedValue.toStringAsFixed(2))),
                      DataCell(Text(horse.horseName)),
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
}