// lib/widgets/detailed_analysis_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/formation_analysis_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/formation_analysis_engine.dart';

class DetailedAnalysisTab extends StatefulWidget {
  final String raceId;
  final String raceName;
  final List<PredictionHorseDetail> horses;
  final List<String> targetRaceIds;

  const DetailedAnalysisTab({
    super.key,
    required this.raceId,
    required this.raceName,
    required this.horses,
    required this.targetRaceIds,
  });

  @override
  State<DetailedAnalysisTab> createState() => _DetailedAnalysisTabState();
}

class _DetailedAnalysisTabState extends State<DetailedAnalysisTab> {
  final RaceRepository _raceRepo = RaceRepository();
  final FormationAnalysisEngine _engine = FormationAnalysisEngine();
  final MatrixTrapFormationEngine _trapEngine = MatrixTrapFormationEngine();

  bool _isLoading = true;
  FormationAnalysisResult? _result;
  MatrixTrapResult? _trapResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      List<RaceResult> pastRaces = [];

      if (widget.targetRaceIds.isNotEmpty) {
        final resultsMap = await _raceRepo.getMultipleRaceResults(widget.targetRaceIds);
        pastRaces = resultsMap.values.toList();
      } else {
        pastRaces = await _raceRepo.searchRaceResultsByName(widget.raceName);
      }

      if (pastRaces.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '過去データがありません。統計分析を行うには、先に「過去傾向」タブでデータを取得してください。';
        });
        return;
      }

      // [修正] 引数から totalBudget を削除 (v.2.0)
      final result = _engine.analyze(
        pastRaces: pastRaces,
        currentHorses: widget.horses,
      );

      final Map<int, String> validMap = {};
      for (final h in widget.horses) {
        int p = int.tryParse(h.popularity?.toString() ?? '') ?? 0;
        double o = double.tryParse(h.odds?.toString() ?? '') ?? 0.0;
        if (p > 0 && o > 0) {
          if (o <= result.standardOddsLine) {
            validMap[p] = h.horseName;
          }
        } else if (p > 0) {
          validMap[p] = h.horseName;
        }
      }

      final trapResult = _trapEngine.analyze(
        frequencyMatrix: result.frequencyMatrix,
        validHorseMap: validMap,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _trapResult = trapResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '分析エラー: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, textAlign: TextAlign.center)));
    if (_result == null) return const Center(child: Text('データなし'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDisclaimerBanner(),
          const SizedBox(height: 16),

          _buildBasicFormationCard(_result!),
          const SizedBox(height: 16),

          _buildStrategyCard(_result!),
          const SizedBox(height: 16),

          _buildOddsLineCard(_result!),
          const SizedBox(height: 24),

          ExpansionTile(
            title: const Text('📊 人気出現マトリクス', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              _buildFrequencyMatrix(_result!),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 16),

          if (_trapResult != null) ...[
            MatrixTrapCard(result: _trapResult),
            const SizedBox(height: 24),
          ],

          // [削除] 買い目リスト関連のウィジェット呼び出しを完全に削除 (v.2.0)
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 8),
              Text('数字の読み方と本機能について', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '❶ 数字はすべて「人気順」です\n'
                '   (例: ① → 1番人気) ※馬番ではありません\n'
                '❷ これは予想ではありません\n'
                '   過去の波形を楽しむ「統計パズル」です。\n'
                '   馬の能力や調子は考慮されていません。',
            style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFormationCard(FormationAnalysisResult result) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey, width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.looks_one, color: Colors.green), SizedBox(width: 8), Text('基本フォーメーション (1-2-5)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            const SizedBox(height: 4),
            const Text('迷ったらコレ。点数を絞った王道の形です。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            _buildFormationRow('1列目', result.basicRank1, Colors.green[50]!),
            const SizedBox(height: 4),
            _buildFormationRow('2列目', result.basicRank2, Colors.green[50]!),
            const SizedBox(height: 4),
            _buildFormationRow('3列目', result.basicRank3, Colors.green[50]!),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCard(FormationAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo.shade900, Colors.indigo.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.psychology, color: Colors.white, size: 20), SizedBox(width: 8), Text('AI戦術眼 (Tactical Eye)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          Text(result.strategyName, style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('推奨: ${result.betType} / 推定${result.estimatedPoints}点', style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 8),
          Text(result.strategyReason, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          if (result.strategyName.contains("BOX"))
            _buildFormationRow("BOX対象", result.strategyRank1, Colors.white.withOpacity(0.2))
          else ...[
            _buildFormationRow("1列目", result.strategyRank1, Colors.white.withOpacity(0.2)),
            const SizedBox(height: 4),
            _buildFormationRow("2列目", result.strategyRank2, Colors.white.withOpacity(0.2)),
            const SizedBox(height: 4),
            _buildFormationRow("3列目", result.strategyRank3, Colors.white.withOpacity(0.2)),
          ]
        ],
      ),
    );
  }

  Widget _buildFormationRow(String label, List<int> candidates, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(child: Text(candidates.map((c) => '$c人').join(', '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildOddsLineCard(FormationAnalysisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [const Text('足切りライン (90%)', style: TextStyle(fontSize: 12, color: Colors.grey)), Text('${result.standardOddsLine.toStringAsFixed(1)}倍', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))]),
            const Icon(Icons.filter_alt, color: Colors.grey),
            Column(children: [const Text('有効対象馬', style: TextStyle(fontSize: 12, color: Colors.grey)), Text('${result.validHorseCount}頭', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyMatrix(FormationAnalysisResult result) {
    final List<int> activePops = [];
    for (int i = 0; i < 18; i++) {
      if (result.frequencyMatrix[i].any((count) => count > 0)) {
        activePops.add(i + 1);
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Row(children: [
              Expanded(flex: 1, child: Text('人気', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text('1着', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text('2着', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text('3着', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
            ]),
            const Divider(),
            ...activePops.map((pop) {
              final counts = result.frequencyMatrix[pop - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(flex: 1, child: Text('$pop人', textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: _buildHeatCell(counts[0])),
                  Expanded(flex: 1, child: _buildHeatCell(counts[1])),
                  Expanded(flex: 1, child: _buildHeatCell(counts[2])),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatCell(int count) {
    if (count == 0) return const Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey));
    Color color = Colors.blue.withOpacity(0.1 + (count * 0.15).clamp(0.0, 0.9));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text('$count回', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

// [削除] _buildChaosOptionCard, _buildTicketList メソッドを完全に削除 (v.2.0)
}

class MatrixTrapCard extends StatelessWidget {
  final MatrixTrapResult? result;

  const MatrixTrapCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null || result!.tickets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'マトリクストラップ (置き型予想)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '過去の出現分布に特化し、列間の重複を完全に排除した3連単専用のトラップです。レース側がこの波形に合致するのを待ちます。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            _buildRow('1列目', result!.rank1),
            Divider(color: Colors.grey.shade200, height: 24),
            _buildRow('2列目', result!.rank2),
            Divider(color: Colors.grey.shade200, height: 24),
            _buildRow('3列目', result!.rank3),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '推奨: 3連単 フォーメーション',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  Text(
                    '推定 ${result!.estimatedPoints}点',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, List<int> popularities) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: popularities.isEmpty
                ? [
              Text(
                '該当なし',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              )
            ]
                : popularities.map((pop) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$pop人',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}