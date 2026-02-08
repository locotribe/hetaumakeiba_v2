// lib/widgets/stats_match_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/services/historical_match_service.dart';
import 'package:hetaumakeiba_v2/logic/ai/historical_match_engine.dart';

class StatsMatchTab extends StatefulWidget {
  final String raceId;
  final String raceName;
  final List<PredictionHorseDetail> horses;
  // ★追加: 集計対象とするレースIDのリスト
  final List<String>? targetRaceIds;

  const StatsMatchTab({
    super.key,
    required this.raceId,
    required this.raceName,
    required this.horses,
    this.targetRaceIds, // ★追加
  });

  @override
  State<StatsMatchTab> createState() => _StatsMatchTabState();
}

class _StatsMatchTabState extends State<StatsMatchTab> {
  final HistoricalMatchService _service = HistoricalMatchService();
  final HistoricalMatchEngine _engine = HistoricalMatchEngine();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = true;
  String _statusMessage = 'データ準備中...';
  List<HistoricalMatchModel> _results = [];
  TrendSummary? _summary;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      // ※ここはスクレイピング用メソッドですが、今回はDBにあるデータを使うため表示のみ更新
      if (mounted) setState(() => _statusMessage = '詳細データを収集中...');

      final Map<String, List<HorseRaceRecord>> currentHorseHistory = {};
      for (final horse in widget.horses) {
        final records = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
        currentHorseHistory[horse.horseId] = records;
      }

      // ★修正: 対象レースIDが指定されている場合は、そのレースだけを取得する
      List<RaceResult> pastRaces;
      if (widget.targetRaceIds != null && widget.targetRaceIds!.isNotEmpty) {
        final resultsMap = await _dbHelper.getMultipleRaceResults(widget.targetRaceIds!);
        pastRaces = resultsMap.values.toList();
      } else {
        // 指定がない場合は従来通り名前検索で全件取得（互換性維持）
        pastRaces = await _dbHelper.searchRaceResultsByName(widget.raceName);
      }

      // データがない場合の早期リターン
      if (pastRaces.isEmpty) {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
          });
        }
        return;
      }

      setState(() => _statusMessage = '過去の好走パターンを分析中...');
      final Map<String, List<HorseRaceRecord>> pastTopHorseRecords = {};

      for (final race in pastRaces) {
        for (final horse in race.horseResults) {
          final rank = int.tryParse(horse.rank ?? '');
          if (rank != null && rank <= 3 && horse.horseId.isNotEmpty) {
            if (!pastTopHorseRecords.containsKey(horse.horseId)) {
              final records = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
              pastTopHorseRecords[horse.horseId] = records;
            }
          }
        }
      }

      final analysisResult = _engine.analyze(
        currentHorses: widget.horses,
        pastRaces: pastRaces,
        currentHorseHistory: currentHorseHistory,
        pastTopHorseRecords: pastTopHorseRecords,
      );

      if (mounted) {
        setState(() {
          _results = analysisResult['results'] as List<HistoricalMatchModel>;
          _summary = analysisResult['summary'] as TrendSummary?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '分析中にエラーが発生しました:\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
      ]));
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('該当する過去レースデータがありませんでした。'));
    }

    return Column(
      children: [
        if (_summary != null) _buildTrendHeader(_summary!),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildResultTable(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendHeader(TrendSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('【過去の傾向分析】', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _headerItem(Icons.monitor_weight_outlined, '基準:${summary.medianWeight.toStringAsFixed(0)}kg'),
              _headerItem(Icons.view_column_outlined, '有利:${summary.bestZone}'),
              _headerItem(Icons.loop, 'ローテ:${summary.bestRotation}'),
              _headerItem(Icons.trending_up, '前走人気:${summary.bestPrevPop}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultTable() {
    double maxScore = 0.0;
    if (_results.isNotEmpty) {
      maxScore = _results.map((e) => e.totalScore).reduce((a, b) => a > b ? a : b);
    }

    return DataTable(
      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('馬名')),
        DataColumn(label: Text('総合シンクロ')),
        DataColumn(label: Text('人気妙味')),
        DataColumn(label: Text('信頼度(格)')),
        DataColumn(label: Text('馬体重')),
        DataColumn(label: Text('枠順')),
      ],
      rows: _results.map((item) {
        return DataRow(cells: [
          DataCell(Text(item.horseName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(_buildTotalScoreCell(item.totalScore, maxScore)),
          DataCell(InkWell(
            onTap: () => _showPopularityDetailDialog(context, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: _buildPopularityCell(item),
            ),
          )),
          DataCell(_buildRotationCell(item)),
          DataCell(_buildWeightDetailCell(item)),
          DataCell(_buildFrameDetailCell(item)),
        ]);
      }).toList(),
    );
  }

  Widget _buildPopularityCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.popularityScore >= 90) color = Colors.red;
    else if (item.popularityScore <= 40) color = Colors.blue;

    // 短い診断名だけを表示 (S:お宝馬 など)
    return Row(
      children: [
        Text(item.popDiagnosis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 4),
        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
      ],
    );
  }

  void _showPopularityDetailDialog(BuildContext context, HistoricalMatchModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // Column に変更し、縦並びにする
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.horseName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '累積指数: ${item.valueIndex >= 0 ? "+" : ""}${item.valueIndex.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. AIによる解説 (自然言語)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.psychology, size: 16, color: Colors.blue), SizedBox(width: 4), Text('AI診断', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                      const SizedBox(height: 4),
                      Text(item.valueReasoning, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('▼ 過去レース分析 (人気 vs 着順)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const Divider(),

                // 2. 履歴リスト (矢印付き)
                Expanded(
                  child: item.recentHistory.isEmpty
                      ? const Center(child: Text('過去データがありません'))
                      : ListView.builder(
                    itemCount: item.recentHistory.length,
                    itemBuilder: (context, index) {
                      final rec = item.recentHistory[index];
                      final pop = int.tryParse(rec.popularity) ?? 0;
                      final rank = int.tryParse(rec.rank) ?? 0;
                      if (pop == 0 || rank == 0) return const SizedBox.shrink();

                      final diff = pop - rank;
                      IconData icon;
                      Color color;

                      if (diff >= 5) { icon = Icons.arrow_upward; color = Colors.red; }
                      else if (diff >= 1) { icon = Icons.north_east; color = Colors.orange; }
                      else if (diff == 0) { icon = Icons.arrow_forward; color = Colors.grey; }
                      else if (diff >= -3) { icon = Icons.south_east; color = Colors.blue; }
                      else { icon = Icons.arrow_downward; color = Colors.blue[900]!; }

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text(rec.date.split('/').sublist(1).join('/'), style: const TextStyle(fontSize: 10))],
                        ),
                        title: Text(rec.raceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${rec.popularity}人 → ${rec.rank}着', style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(diff > 0 ? '+${diff}Gap' : '${diff}Gap', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Icon(icon, color: color),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          ],
        );
      },
    );
  }

  // --- 既存のセル構築メソッド ---
  Widget _buildRotationCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.rotationScore >= 90) color = Colors.red;
    else if (item.rotationScore >= 80) color = Colors.orange[800]!;
    String raceName = item.prevRaceName;
    if (raceName.length > 8) raceName = '${raceName.substring(0, 7)}...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(item.rotDiagnosis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(raceName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTotalScoreCell(double score, double maxScore) {
    Color color;
    String rank;
    if (score >= maxScore && score > 0) { rank = 'S'; color = Colors.red; }
    else if (score >= 90) { rank = 'A'; color = Colors.deepOrange; }
    else if (score >= 80) { rank = 'B'; color = Colors.orange; }
    else if (score >= 70) { rank = 'C'; color = Colors.amber.shade700; }
    else if (score >= 60) { rank = 'D'; color = Colors.blue; }
    else if (score >= 50) { rank = 'E'; color = Colors.indigo; }
    else { rank = 'F'; color = Colors.grey; }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 45, child: Text('${score.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16))),
        const SizedBox(width: 8),
        Container(width: 24, height: 20, alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildWeightDetailCell(HistoricalMatchModel item) {
    final diff = item.weightDiff;
    Color color = Colors.black;
    if (item.weightScore >= 90) color = Colors.red;
    else if (item.weightScore >= 80) color = Colors.orange[800]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 40, child: Text('${item.weightScore.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.weightStr.split(' ')[0], style: TextStyle(color: item.isWeightCurrent ? Colors.black87 : Colors.grey, fontSize: 12)),
            if (!item.isWeightCurrent) const Text('(前)', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(' 差:${diff.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildFrameDetailCell(HistoricalMatchModel item) {
    if (item.gateNumber == 0) return const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 40, child: Text('--', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))), Text('未発表', style: TextStyle(fontSize: 11, color: Colors.grey))]);
    Color color = Colors.black;
    if (item.frameScore >= 90) color = Colors.red;
    else if (item.frameScore >= 70) color = Colors.orange[800]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 40, child: Text('${item.frameScore.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
        Row(mainAxisSize: MainAxisSize.min, children: [Text('${item.positionZone}目', style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), Text('(${item.gateNumber}番)', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
      ],
    );
  }
}