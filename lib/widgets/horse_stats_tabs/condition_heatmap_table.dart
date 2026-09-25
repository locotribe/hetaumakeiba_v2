// lib/widgets/horse_stats_tabs/condition_heatmap_table.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_ranking_builder.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_match_engine.dart';
import 'package:hetaumakeiba_v2/widgets/condition_race_tile.dart';

// [追加] 好走条件 相対順位付け StepB-2: 今回条件ヒートマップ（行=各出走馬/列=今回該当ファクター＋総合/列ごと相対順位で緑グラデ） (v.2026.9.25+26092509)
class ConditionHeatmapTable extends StatefulWidget {
  final ConditionRankingTable table;
  final Map<String, List<HorseRaceRecord>> allPastRecords;
  final List<PredictionHorseDetail> currentRaceHorses;

  const ConditionHeatmapTable({
    super.key,
    required this.table,
    required this.allPastRecords,
    required this.currentRaceHorses,
  });

  @override
  State<ConditionHeatmapTable> createState() => _ConditionHeatmapTableState();
}

class _ConditionHeatmapTableState extends State<ConditionHeatmapTable> {
  String? _expandedHorseId;
  String? _expandedColumnKey;

  // グラデ両端（複勝率＝買えるの意で緑系。1位=濃→下位=淡）
  static const Color _gradeDark = Color(0xFF2E7D32);
  static const Color _gradeLight = Color(0xFFE8F5E9);
  static const double _nameColWidth = 54.0;

  void _toggle(String horseId, String columnKey) {
    setState(() {
      if (_expandedHorseId == horseId && _expandedColumnKey == columnKey) {
        _expandedHorseId = null;
        _expandedColumnKey = null;
      } else {
        _expandedHorseId = horseId;
        _expandedColumnKey = columnKey;
      }
    });
  }

  DateTime _parseDate(String s) {
    final p = s.split('/');
    if (p.length == 3) {
      final y = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime(1900);
  }

  /// rank/rankOutOf から 0.0(1位・最濃)〜1.0(最下位・最淡) を返す。順位なしは -1。
  double _t(HorseConditionCell cell) {
    final r = cell.rank;
    final n = cell.rankOutOf;
    if (r == null || n == null) return -1.0;
    if (n <= 1) return 0.0;
    return (r - 1) / (n - 1);
  }

  Color _bgColor(HorseConditionCell cell) {
    final t = _t(cell);
    if (t < 0) return Colors.transparent;
    return Color.lerp(_gradeDark, _gradeLight, t)!;
  }

  Color _textColor(HorseConditionCell cell) {
    final t = _t(cell);
    if (t < 0) {
      return cell.isReference ? Colors.black38 : Colors.black54;
    }
    return t < 0.5 ? Colors.white : Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.table.columns;
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderRow(columns),
          for (final row in widget.table.rows) ..._buildHorseRow(columns, row),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<RaceConditionColumn> columns) {
    return Container(
      color: Colors.green.shade50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: _nameColWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
              child: Center(
                child: Text('馬',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          for (final c in columns) Expanded(child: _headerCell(c)),
        ],
      ),
    );
  }

  Widget _headerCell(RaceConditionColumn c) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(c.todayValue,
                maxLines: 1,
                style: TextStyle(fontSize: 8, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHorseRow(List<RaceConditionColumn> columns, HorseConditionRow row) {
    final rowWidget = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: _nameColWidth, child: _nameCell(row)),
            for (final c in columns) Expanded(child: _dataCell(row, c)),
          ],
        ),
      ),
    );

    final widgets = <Widget>[rowWidget];
    if (_expandedHorseId == row.horseId && _expandedColumnKey != null) {
      widgets.add(_buildExpansion(row, _expandedColumnKey!));
    }
    return widgets;
  }

  Widget _nameCell(HorseConditionRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${row.horseNumber}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text(row.horseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  Widget _dataCell(HorseConditionRow row, RaceConditionColumn c) {
    final cell = row.cells[c.key]!;
    final bool isOverall = c.key == ConditionRankingBuilder.kOverall;
    final bool tappable = !isOverall && cell.matchedCount > 0;

    final w = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _bgColor(cell),
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 1.0),
      child: _cellContent(cell, isOverall),
    );

    if (!tappable) return w;
    return GestureDetector(
      onTap: () => _toggle(row.horseId, c.key),
      behavior: HitTestBehavior.opaque,
      child: w,
    );
  }

  Widget _cellContent(HorseConditionCell cell, bool isOverall) {
    if (cell.showRate == null) {
      return Text('−', style: TextStyle(fontSize: 11, color: Colors.grey.shade400));
    }
    final pct = (cell.showRate! * 100).round();
    final txt = _textColor(cell);
    if (isOverall) {
      return Text('$pct%',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txt));
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$pct%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txt)),
          Text('(${cell.matchedCount})',
              style: TextStyle(fontSize: 8, color: txt)),
        ],
      ),
    );
  }

  Widget _buildExpansion(HorseConditionRow row, String columnKey) {
    final col = widget.table.columns.firstWhere((c) => c.key == columnKey);
    final records = ConditionRankingBuilder.recordsForColumn(
      columnKey,
      col.todayValue,
      widget.allPastRecords[row.horseId] ?? const [],
    );
    final sorted = List<HorseRaceRecord>.of(records)
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));

    return Container(
      color: Colors.grey.shade50,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6.0, 4.0, 6.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
            child: Text(
              '${row.horseName}／${col.name}: ${col.todayValue}（${sorted.length}走）',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          for (final r in sorted)
            ConditionRaceTile(
              pastRace: PastRaceWithMatchup(
                record: r,
                matchupContext: ConditionMatchEngine.scanMatchups(
                  targetRaceId: r.raceId,
                  myHorseId: row.horseId,
                  myRank: r.rank,
                  currentRaceMembers: widget.currentRaceHorses,
                  allHorsesPastRecords: widget.allPastRecords,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
