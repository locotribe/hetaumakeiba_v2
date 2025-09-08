// lib/screens/ai_prediction_analysis_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/services/ai_prediction_analysis_service.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/main.dart';

class AiPredictionAnalysisPage extends StatefulWidget {
  const AiPredictionAnalysisPage({super.key});

  @override
  State<AiPredictionAnalysisPage> createState() => _AiPredictionAnalysisPageState();
}

class _AiPredictionAnalysisPageState extends State<AiPredictionAnalysisPage> {
  final AiPredictionAnalysisService _analysisService = AiPredictionAnalysisService();
  Future<Map<String, dynamic>>? _analysisFuture;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  void _loadAnalysisData() {
    final userId = localUserId;
    if (userId != null) {
      setState(() {
        _analysisFuture = _analysisService.analyzeAllPredictions(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI予測 傾向分析'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _analysisFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('分析データの読み込み中にエラーが発生しました: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!['overall'] == null) {
                return const Center(child: Text('分析対象のデータがありません。'));
              }

              final overallAnalysis = snapshot.data!['overall'] as AiOverallAnalysis;
              final venueAnalysis = (snapshot.data!['byVenue'] as List<dynamic>?)?.cast<AiFactorAnalysis>() ?? [];
              final distanceAnalysis = (snapshot.data!['byDistance'] as List<dynamic>?)?.cast<AiFactorAnalysis>() ?? [];
              final trackConditionAnalysis = (snapshot.data!['byTrackCondition'] as List<dynamic>?)?.cast<AiFactorAnalysis>() ?? [];
              final popularityAnalysis = (snapshot.data!['byPopularity'] as List<dynamic>?)?.cast<AiFactorAnalysis>() ?? [];
              final legStyleAnalysis = (snapshot.data!['byLegStyle'] as List<dynamic>?)?.cast<AiFactorAnalysis>() ?? []; // ← この行を追加

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildOverallAnalysisCard(overallAnalysis),
                  const SizedBox(height: 16),
                  _buildFactorAnalysisCard('競馬場別 分析', venueAnalysis),
                  const SizedBox(height: 16),
                  _buildFactorAnalysisCard('距離別 分析', distanceAnalysis),
                  const SizedBox(height: 16),
                  _buildFactorAnalysisCard('馬場状態別 分析', trackConditionAnalysis),
                  const SizedBox(height: 16),
                  _buildFactorAnalysisCard('人気度別 分析', popularityAnalysis),
                  const SizedBox(height: 16),
                  _buildFactorAnalysisCard('脚質別 分析', legStyleAnalysis),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAnalysisCard(AiOverallAnalysis analysis) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本命馬 総合分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '総合評価スコアが最も高かった馬の通算成績です。(全${analysis.totalHonmeiCount}レース)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            _buildStatRow('勝率 (1着)', '${analysis.winRate.toStringAsFixed(1)}%'),
            _buildStatRow('連対率 (2着以内)', '${analysis.placeRate.toStringAsFixed(1)}%'),
            _buildStatRow('複勝率 (3着以内)', '${analysis.showRate.toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            _buildStatRow('単勝回収率', '${analysis.winRecoveryRate.toStringAsFixed(1)}%', isRecoveryRate: true),
            _buildStatRow('複勝回収率', '${analysis.showRecoveryRate.toStringAsFixed(1)}%', isRecoveryRate: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String title, String value, {bool isRecoveryRate = false}) {
    Color valueColor = Colors.black87;
    if (isRecoveryRate) {
      final rate = double.tryParse(value.replaceAll('%', '')) ?? 0.0;
      if (rate > 100.0) {
        valueColor = Colors.blue.shade700;
      } else if (rate < 100.0) {
        valueColor = Colors.red.shade700;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorAnalysisCard(String title, List<AiFactorAnalysis> analysisList) {
    if (analysisList.isEmpty) {
      return const SizedBox.shrink();
    }

    // 回収率でソート
    analysisList.sort((a, b) => b.analysis.winRecoveryRate.compareTo(a.analysis.winRecoveryRate));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('条件')),
                  DataColumn(label: Text('単回率'), numeric: true),
                  DataColumn(label: Text('複回率'), numeric: true),
                  DataColumn(label: Text('複勝率'), numeric: true),
                  DataColumn(label: Text('N数'), numeric: true),
                ],
                rows: analysisList.map((analysis) {
                  return DataRow(
                    cells: [
                      DataCell(Text(analysis.factorName)),
                      DataCell(_buildRecoveryRateCell(analysis.analysis.winRecoveryRate)),
                      DataCell(_buildRecoveryRateCell(analysis.analysis.showRecoveryRate)),
                      DataCell(Text('${analysis.analysis.showRate.toStringAsFixed(1)}%')),
                      DataCell(Text(analysis.analysis.totalHonmeiCount.toString())),
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

  Widget _buildRecoveryRateCell(double rate) {
    Color color = Colors.black87;
    if (rate > 100) {
      color = Colors.blue.shade700;
    } else if (rate < 80) {
      color = Colors.red.shade700;
    }
    return Text(
      '${rate.toStringAsFixed(1)}%',
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}