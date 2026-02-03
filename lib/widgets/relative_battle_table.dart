// lib/widgets/relative_battle_table.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';
import 'package:hetaumakeiba_v2/logic/relative_battle_calculator.dart';

class RelativeBattleTable extends StatefulWidget {
  final List<PredictionHorseDetail> horses;

  const RelativeBattleTable({
    super.key,
    required this.horses,
  });

  @override
  State<RelativeBattleTable> createState() => _RelativeBattleTableState();
}

class _RelativeBattleTableState extends State<RelativeBattleTable> {
  List<RelativeEvaluationResult>? _results;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  /// シミュレーションの実行
  Future<void> _runSimulation() async {
    // UIスレッドをブロックしないよう少し遅延させる
    await Future.delayed(Duration.zero);

    final calculator = RelativeBattleCalculator();
    final results = calculator.runSimulation(widget.horses, iterations: 100);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  /// ヒートマップ用の色を計算
  Color _getHeatmapColor(double value, {double max = 100.0, double min = 0.0}) {
    // 簡易的な正規化 (0.0 - 1.0)
    double normalized = (value - min) / (max - min);
    normalized = normalized.clamp(0.0, 1.0);

    if (normalized > 0.6) {
      return Colors.red.withOpacity(0.1 + (normalized * 0.4)); // 高い値は赤
    } else if (normalized < 0.3) {
      return Colors.blue.withOpacity(0.1 + ((1 - normalized) * 0.2)); // 低い値は青
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results == null || _results!.isEmpty) {
      return const Center(child: Text("データがありません"));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12.0,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: Text('順位', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('人気', style: TextStyle(fontWeight: FontWeight.bold))), // ★追加
            DataColumn(label: Text('馬名', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('勝率', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('逆転', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('基礎', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('妙味', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('評価短評', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _results!.map((result) {
            return DataRow(
              cells: [
                // 順位
                DataCell(
                  Center(
                    child: Text(
                      '${result.rank}位',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: result.rank <= 3 ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
                ),
                // 人気 (★新規追加)
                DataCell(
                  Center(
                    child: Text(
                      result.popularity != null ? '${result.popularity}人' : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 馬名
                DataCell(Text(result.horseName)),
                // 勝率
                DataCell(
                  Container(
                    width: 60,
                    alignment: Alignment.centerRight,
                    child: Text('${(result.winRate * 100).toStringAsFixed(1)}%'),
                  ),
                ),
                // 逆転期待度 (Value + Pace)
                DataCell(
                  Container(
                    color: _getHeatmapColor(result.reversalScore, max: 15.0),
                    alignment: Alignment.center,
                    child: Text(result.reversalScore.toStringAsFixed(1)),
                  ),
                ),
                // 基礎能力 (Base)
                DataCell(
                  Container(
                    color: _getHeatmapColor(result.factorScores['base'] ?? 0, max: 100.0, min: 40.0),
                    alignment: Alignment.center,
                    child: Text((result.factorScores['base'] ?? 0).toStringAsFixed(0)),
                  ),
                ),
                // 妙味 (Value)
                DataCell(
                  Container(
                    color: _getHeatmapColor(result.factorScores['value'] ?? 0, max: 2.0), // しきい値調整
                    alignment: Alignment.center,
                    child: Text((result.factorScores['value'] ?? 0).toStringAsFixed(1)),
                  ),
                ),
                // 短評
                DataCell(
                  Text(
                    result.evaluationComment,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}