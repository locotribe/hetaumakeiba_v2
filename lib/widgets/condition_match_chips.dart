// lib/widgets/condition_match_chips.dart

import 'package:flutter/material.dart';

/// 対戦結果（先着・敗北）を視覚的に表示するカラーチップ
class MatchupResultChip extends StatelessWidget {
  final String opponentName;
  final String opponentRank;
  final bool isWin;

  const MatchupResultChip({
    super.key,
    required this.opponentName,
    required this.opponentRank,
    required this.isWin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isWin ? Colors.red.withAlpha(40) : Colors.blue.withAlpha(40),
        border: Border.all(
          color: isWin ? Colors.red : Colors.blue,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWin ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: isWin ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 2),
          Text(
            '$opponentName(${opponentRank}着)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isWin ? Colors.red.shade900 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 範囲表示（最短〜最長など）をスマホで見やすく表示するためのテキスト部品
class ConditionRangeText extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const ConditionRangeText({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}