// lib/widgets/condition_horse_row.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
import 'package:hetaumakeiba_v2/widgets/condition_match_chips.dart';

/// 1頭の好走条件サマリーを表示し、詳細をアコーディオン展開する行ウィジェット
class ConditionHorseRow extends StatefulWidget {
  final HorseConditionDisplayData data;

  const ConditionHorseRow({
    super.key,
    required this.data,
  });

  @override
  State<ConditionHorseRow> createState() => _ConditionHorseRowState();
}

class _ConditionHorseRowState extends State<ConditionHorseRow> {
  bool _isExpanded = false;
  String? _selectedRankLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // メイン行：馬名と着順別のサマリー（水平スクロール対応）
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
              if (_selectedRankLabel == null && widget.data.summaries.isNotEmpty) {
                _selectedRankLabel = widget.data.summaries.keys.first;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              color: _isExpanded ? Colors.blue.withAlpha(10) : Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.horseName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.data.summaries.entries.map((entry) {
                      final isSelected = _selectedRankLabel == entry.key && _isExpanded;
                      return _buildSummaryCell(entry.key, entry.value, isSelected);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展開パネル：選択された着順の過去レース詳細（垂直リスト）
        if (_isExpanded && _selectedRankLabel != null)
          Container(
            color: Colors.grey.shade50,
            child: Column(
              children: widget.data.summaries[_selectedRankLabel]!.detailedRaces.map((pastRace) {
                return _buildDetailedRaceTile(pastRace);
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// 着順別のサマリーセル（範囲表示と内訳）
  Widget _buildSummaryCell(String label, RankSummaryDisplay summary, bool isSelected) {
    // 共通のテキストスタイル定義
    const leftTextStyle = TextStyle(fontSize: 11);
    final rightTextStyle = TextStyle(fontSize: 10, color: Colors.grey.shade700);
    // ラベル用のスタイル（右側の項目名）
    final rightLabelStyle = TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold);

    const iconColor = Colors.grey;
    const iconSize = 12.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = true;
          _selectedRankLabel = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4.0),
        ),
        // 文字数が多い場合でも切れないよう、幅を280に拡張
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: 着順と回数
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${summary.count}回', style: const TextStyle(fontSize: 11, color: Colors.blue)),
              ],
            ),
            const Divider(height: 8),

            // 1行目: [距離Icon] データ | [脚質] データ
            Row(
              children: [
                // 左側：距離
                Expanded(
                  flex: 5, // 左側を少し広めに確保
                  child: Row(
                    children: [
                      Text("距離", style: rightLabelStyle),
                      const SizedBox(width: 4),
                      Expanded(child: Text(summary.distanceRange, style: leftTextStyle, overflow: TextOverflow.visible)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 右側：脚質
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Text("脚質", style: rightLabelStyle), // テキストに変更
                      const SizedBox(width: 4),
                      Expanded(child: Text(summary.legStyleSummary, style: rightTextStyle, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 2行目: [体重Icon] データ | [回り] データ
            Row(
              children: [
                // 左側：体重
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Text("体重", style: rightLabelStyle),
                      const SizedBox(width: 4),
                      Expanded(child: Text(summary.weightRange, style: leftTextStyle, overflow: TextOverflow.visible)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 右側：回り
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Text("回り", style: rightLabelStyle), // テキストに変更
                      const SizedBox(width: 4),
                      Expanded(child: Text(summary.directionSummary, style: rightTextStyle, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 3行目: [斤量Icon] データ | [馬場] データ
            Row(
              children: [
                // 左側：斤量
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Text("斤量", style: rightLabelStyle),
                      const SizedBox(width: 4),
                      Expanded(child: Text(summary.carriedWeightRange, style: leftTextStyle, overflow: TextOverflow.visible)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 右側：馬場
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Text("馬場", style: rightLabelStyle), // テキストに変更
                      const SizedBox(width: 4),
                      Expanded(child: Text(summary.trackConditionSummary, style: rightTextStyle, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 対戦相手情報を含む過去レースの1タイル
  Widget _buildDetailedRaceTile(PastRaceWithMatchup pastRace) {
    final record = pastRace.record;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${record.date} ${record.raceName}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${record.venue} / ${record.distance}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 対戦相手バッジの表示（今回のメンバーがいた場合のみ）
          if (pastRace.matchupContext != null)
            Wrap(
              spacing: 4.0,
              runSpacing: 2.0,
              children: pastRace.matchupContext!.matchups.map((m) {
                return MatchupResultChip(
                  opponentName: m.opponentName,
                  opponentRank: m.opponentRank,
                  isWin: m.isWin,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}