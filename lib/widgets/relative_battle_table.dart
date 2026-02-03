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

  // 表示するペース列の管理
  final Set<RacePace> _visiblePaces = {};

  // ソート状態の管理（デフォルトは総合勝率）
  int _sortColumnIndex = 1; // 馬名(0)の次、総合勝率(1)をデフォルトソートとする
  bool _sortAscending = false; // 降順（高い順）

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    await Future.delayed(Duration.zero);
    final calculator = RelativeBattleCalculator();
    final results = calculator.runSimulation(widget.horses, iterations: 100);

    if (mounted) {
      setState(() {
        _results = results;
        // 初期ソート: 総合勝率（降順）
        _results!.sort((a, b) => b.winRate.compareTo(a.winRate));
        _isLoading = false;
      });
    }
  }

  void _sort<T>(Comparable<T> Function(RelativeEvaluationResult d) getField, int columnIndex, bool ascending) {
    if (_results == null) return;

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _results!.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
      });
    });
  }

  // 順位取得ヘルパー
  int _getRankInList<T extends Comparable>(T value, T Function(RelativeEvaluationResult) getField, {bool descending = true}) {
    if (_results == null || _results!.isEmpty) return 999;
    final values = _results!.map((e) => getField(e)).toList();
    values.removeWhere((v) => v == null);
    if (descending) {
      values.sort((a, b) => b.compareTo(a));
    } else {
      values.sort((a, b) => a.compareTo(b));
    }
    return values.indexOf(value) + 1;
  }

  // 背景色取得ヘルパー
  Color? _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.red.withOpacity(0.3);
      case 2: return Colors.deepOrange.withOpacity(0.3);
      case 3: return Colors.orange.withOpacity(0.3);
      case 4: return Colors.lime.withOpacity(0.4);
      case 5: return Colors.yellow.withOpacity(0.3);
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_results == null || _results!.isEmpty) return const Center(child: Text("データがありません"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ペース別表示切り替えトグル
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Wrap(
            spacing: 8.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("展開シミュ: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              FilterChip(
                label: const Text("S (スロー)"),
                selected: _visiblePaces.contains(RacePace.slow),
                onSelected: (selected) => setState(() => selected ? _visiblePaces.add(RacePace.slow) : _visiblePaces.remove(RacePace.slow)),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              FilterChip(
                label: const Text("M (ミドル)"),
                selected: _visiblePaces.contains(RacePace.middle),
                onSelected: (selected) => setState(() => selected ? _visiblePaces.add(RacePace.middle) : _visiblePaces.remove(RacePace.middle)),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              FilterChip(
                label: const Text("H (ハイ)"),
                selected: _visiblePaces.contains(RacePace.high),
                onSelected: (selected) => setState(() => selected ? _visiblePaces.add(RacePace.high) : _visiblePaces.remove(RacePace.high)),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columnSpacing: 12.0,
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                columns: _buildColumns(),
                rows: _results!.map((result) => _buildRow(result)).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DataColumn> _buildColumns() {
    List<DataColumn> columns = [
      // 1. 馬名 (固定)
      DataColumn(
        label: const Text('馬名', style: TextStyle(fontWeight: FontWeight.bold)),
        onSort: (idx, asc) => _sort((r) => r.horseName, idx, asc),
      ),
      // 2. 総合勝率 (実質的な順位)
      DataColumn(
        label: const Text('総合勝率', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.winRate, idx, asc),
      ),
      // 3. 人気
      DataColumn(
        label: const Text('人気', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.popularity ?? 999, idx, asc),
      ),
      // 4. ★追加: オッズ
      DataColumn(
        label: const Text('オッズ', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.odds, idx, asc),
      ),
    ];

    // ペース別カラム
    if (_visiblePaces.contains(RacePace.slow)) {
      columns.add(DataColumn(
        label: const Text('S勝率', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.scenarioWinRates[RacePace.slow] ?? 0.0, idx, asc),
      ));
    }
    if (_visiblePaces.contains(RacePace.middle)) {
      columns.add(DataColumn(
        label: const Text('M勝率', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.scenarioWinRates[RacePace.middle] ?? 0.0, idx, asc),
      ));
    }
    if (_visiblePaces.contains(RacePace.high)) {
      columns.add(DataColumn(
        label: const Text('H勝率', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.scenarioWinRates[RacePace.high] ?? 0.0, idx, asc),
      ));
    }

    // 残りの固定カラム
    columns.addAll([
      DataColumn(
        label: const Text('逆転', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.reversalScore, idx, asc),
      ),
      DataColumn(
        label: const Text('基礎', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['base'] ?? 0, idx, asc),
      ),
      DataColumn(
        label: const Text('妙味', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['value'] ?? 0, idx, asc),
      ),
      const DataColumn(
        label: Text('評価短評', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);

    return columns;
  }

  DataRow _buildRow(RelativeEvaluationResult result) {
    // ランク計算
    final winRateRank = _getRankInList(result.winRate, (r) => r.winRate, descending: true);
    final popRank = _getRankInList(result.popularity ?? 999, (r) => r.popularity ?? 999, descending: false);
    final revRank = _getRankInList(result.reversalScore, (r) => r.reversalScore, descending: true);
    final baseRank = _getRankInList(result.factorScores['base'] ?? 0, (r) => r.factorScores['base'] ?? 0, descending: true);
    final valueRank = _getRankInList(result.factorScores['value'] ?? 0, (r) => r.factorScores['value'] ?? 0, descending: true);

    // ★ オッズのスタイル判定 (10.0倍未満なら赤太字)
    final bool isRedOdds = result.odds < 10.0 && result.odds > 0;
    final TextStyle oddsStyle = isRedOdds
        ? const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)
        : const TextStyle(fontWeight: FontWeight.normal, color: Colors.black);

    List<DataCell> cells = [
      // 1. 馬名
      DataCell(Text(result.horseName)),
      // 2. 総合勝率 (順位列の代わり)
      DataCell(
        Container(
          color: _getRankColor(winRateRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(result.winRate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: winRateRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
      // 3. 人気
      DataCell(
        Container(
          color: _getRankColor(popRank),
          alignment: Alignment.center,
          child: Text(
            result.popularity != null ? '${result.popularity}人' : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      // 4. ★追加: オッズ (背景色なし、赤文字判定のみ)
      DataCell(
        Container(
          alignment: Alignment.centerRight,
          child: Text(
            result.odds > 0 ? result.odds.toStringAsFixed(1) : '-',
            style: oddsStyle,
          ),
        ),
      ),
    ];

    // ペース別セル
    if (_visiblePaces.contains(RacePace.slow)) {
      double rate = result.scenarioWinRates[RacePace.slow] ?? 0.0;
      final sRank = _getRankInList(rate, (r) => r.scenarioWinRates[RacePace.slow] ?? 0.0, descending: true);
      cells.add(DataCell(
        Container(
          color: _getRankColor(sRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: sRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ));
    }
    if (_visiblePaces.contains(RacePace.middle)) {
      double rate = result.scenarioWinRates[RacePace.middle] ?? 0.0;
      final mRank = _getRankInList(rate, (r) => r.scenarioWinRates[RacePace.middle] ?? 0.0, descending: true);
      cells.add(DataCell(
        Container(
          color: _getRankColor(mRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: mRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ));
    }
    if (_visiblePaces.contains(RacePace.high)) {
      double rate = result.scenarioWinRates[RacePace.high] ?? 0.0;
      final hRank = _getRankInList(rate, (r) => r.scenarioWinRates[RacePace.high] ?? 0.0, descending: true);
      cells.add(DataCell(
        Container(
          color: _getRankColor(hRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: hRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ));
    }

    // 残りの固定セル
    cells.addAll([
      DataCell(
        Container(
          color: _getRankColor(revRank),
          alignment: Alignment.center,
          child: Text(result.reversalScore.toStringAsFixed(1)),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(baseRank),
          alignment: Alignment.center,
          child: Text((result.factorScores['base'] ?? 0).toStringAsFixed(0)),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(valueRank),
          alignment: Alignment.center,
          child: Text((result.factorScores['value'] ?? 0).toStringAsFixed(0)), // 整数で表示
        ),
      ),
      DataCell(
        // 短評は横幅制限なし（スクロール前提）
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200),
          child: Text(
            result.evaluationComment,
            style: const TextStyle(fontSize: 12),
            softWrap: true,
          ),
        ),
      ),
    ]);

    return DataRow(cells: cells);
  }
}