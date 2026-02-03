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

  // ソート状態の管理
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

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
    // Logic側ですべてのパターンの計算が行われる
    final results = calculator.runSimulation(widget.horses, iterations: 100);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  /// ソート処理
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

  /// ★追加: リスト内での順位を取得する（同値は同順位とする）
  /// [value] 判定したい値
  /// [getField] リスト内の各要素から値を抽出する関数
  /// [descending] trueなら「大きいほうが上位」、falseなら「小さいほうが上位（人気など）」
  int _getRankInList<T extends Comparable>(T value, T Function(RelativeEvaluationResult) getField, {bool descending = true}) {
    if (_results == null || _results!.isEmpty) return 999;

    // 値のリストを作成してソート
    final values = _results!.map((e) => getField(e)).toList();

    // null排除（念のため）
    values.removeWhere((v) => v == null);

    if (descending) {
      values.sort((a, b) => b.compareTo(a)); // 降順
    } else {
      values.sort((a, b) => a.compareTo(b)); // 昇順
    }

    // 自分の値が何番目にあるか探す（0-indexed なので +1 する）
    // indexOfは最初に見つかったインデックスを返すため、同値なら同じ順位になる
    return values.indexOf(value) + 1;
  }

  /// ★追加: 順位に応じた背景色を取得する
  Color? _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.red.withOpacity(0.3); // 1位: 赤
      case 2:
        return Colors.deepOrange.withOpacity(0.3); // 2位: 濃いオレンジ
      case 3:
        return Colors.orange.withOpacity(0.3); // 3位: 薄いオレンジ
      case 4:
        return Colors.lime.withOpacity(0.4); // 4位: 濃い黄色（ライム）
      case 5:
        return Colors.yellow.withOpacity(0.3); // 5位: 薄い黄色
      default:
        return null; // 6位以下: 無色
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results == null || _results!.isEmpty) {
      return const Center(child: Text("データがありません"));
    }

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
                onSelected: (selected) {
                  setState(() {
                    selected ? _visiblePaces.add(RacePace.slow) : _visiblePaces.remove(RacePace.slow);
                  });
                },
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              FilterChip(
                label: const Text("M (ミドル)"),
                selected: _visiblePaces.contains(RacePace.middle),
                onSelected: (selected) {
                  setState(() {
                    selected ? _visiblePaces.add(RacePace.middle) : _visiblePaces.remove(RacePace.middle);
                  });
                },
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              FilterChip(
                label: const Text("H (ハイ)"),
                selected: _visiblePaces.contains(RacePace.high),
                onSelected: (selected) {
                  setState(() {
                    selected ? _visiblePaces.add(RacePace.high) : _visiblePaces.remove(RacePace.high);
                  });
                },
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),

        // テーブル本体
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
      DataColumn(
        label: const Text('順位', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.rank, idx, asc),
      ),
      DataColumn(
        label: const Text('人気', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.popularity ?? 999, idx, asc),
      ),
      DataColumn(
        label: const Text('馬名', style: TextStyle(fontWeight: FontWeight.bold)),
        onSort: (idx, asc) => _sort((r) => r.horseName, idx, asc),
      ),
      DataColumn(
        label: const Text('総合勝率', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.winRate, idx, asc),
      ),
    ];

    // ペース別カラムの追加
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
    // 各項目の順位を計算（同値考慮）

    // 総合勝率ランク（高い順）
    final winRateRank = _getRankInList(result.winRate, (r) => r.winRate, descending: true);

    // 人気ランク（低い順）
    final popRank = _getRankInList(result.popularity ?? 999, (r) => r.popularity ?? 999, descending: false);

    // 逆転期待度ランク（高い順）
    final revRank = _getRankInList(result.reversalScore, (r) => r.reversalScore, descending: true);

    // 基礎能力ランク（高い順）
    final baseRank = _getRankInList(result.factorScores['base'] ?? 0, (r) => r.factorScores['base'] ?? 0, descending: true);

    // 妙味ランク（高い順）
    final valueRank = _getRankInList(result.factorScores['value'] ?? 0, (r) => r.factorScores['value'] ?? 0, descending: true);


    List<DataCell> cells = [
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
      DataCell(
        Container(
          color: _getRankColor(popRank), // 人気順の色分け
          alignment: Alignment.center,
          child: Text(
            result.popularity != null ? '${result.popularity}人' : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      DataCell(Text(result.horseName)),
      DataCell(
        Container(
          color: _getRankColor(winRateRank), // 総合勝率の色分け
          alignment: Alignment.centerRight,
          child: Text(
            '${(result.winRate * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: winRateRank <= 3 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    ];

    // ペース別セルの追加
    if (_visiblePaces.contains(RacePace.slow)) {
      double rate = result.scenarioWinRates[RacePace.slow] ?? 0.0;
      // スロー勝率ランク
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
      // ミドル勝率ランク
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
      // ハイ勝率ランク
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
          color: _getRankColor(revRank), // 逆転期待度の色分け
          alignment: Alignment.center,
          child: Text(result.reversalScore.toStringAsFixed(1)),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(baseRank), // 基礎能力の色分け
          alignment: Alignment.center,
          child: Text((result.factorScores['base'] ?? 0).toStringAsFixed(0)),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(valueRank), // 妙味の色分け
          alignment: Alignment.center,
          child: Text((result.factorScores['value'] ?? 0).toStringAsFixed(1)),
        ),
      ),
      DataCell(
        Text(
          result.evaluationComment,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ]);

    return DataRow(cells: cells);
  }
}