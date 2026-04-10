// lib/widgets/rating/components/rating_level_badge.dart
import 'package:flutter/material.dart';

class RatingLevelBadge extends StatelessWidget {
  final String level; // High, Mid, Low
  final String rankStr; // 前走の着順 (例: "1", "12" など)

  const RatingLevelBadge({
    super.key,
    required this.level,
    required this.rankStr,
  });

  @override
  Widget build(BuildContext context) {
    if (level == 'None' || level == 'Mid') return const SizedBox.shrink();

    int rank = int.tryParse(rankStr) ?? 99; // 着順を数値化

    Color color = Colors.grey;
    String label = level;

    // ★修正：判定結果と着順を組み合わせた動的なラベル生成
    if (level == "High") {
      // 自身の平均（Trend）から +2.1 以上の上振れ
      color = Colors.red.shade700;
      label = "▲能力以上";
    }
    else if (level == "Low") {
      // 自身の平均（Trend）から -2.1 以下の下振れ
      if (rank <= 3) {
        // 1〜3着（好走しているのに数値が低い＝相手が弱かった、斤量が軽かった等）
        color = Colors.blue.shade600;
        label = "▼余力残し";
      } else {
        // 4着以下（敗退しており、かつ数値も低い＝実力を出せていない）
        color = Colors.blueGrey.shade600;
        label = "▼下振れ";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}