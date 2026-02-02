// lib/widgets/condition_match_chips.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/ai/condition_match_engine.dart'; // MatchupBrief型のため

/// 対戦結果（先着・敗北）を詳細な行形式で表示するウィジェット
class MatchupResultRow extends StatelessWidget {
  final MatchupBrief matchup;

  const MatchupResultRow({
    super.key,
    required this.matchup,
  });

  @override
  Widget build(BuildContext context) {
    final detailStyle = TextStyle(
      fontSize: 11,
      color: Colors.grey.shade800,
      fontFamily: 'Roboto', // 数字が見やすいフォントを指定（環境による）
    );

    // 勝敗による色設定
    final iconColor = matchup.isWin ? Colors.red : Colors.blue;
    final iconData = matchup.isWin ? Icons.arrow_downward : Icons.arrow_upward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          // 1. 勝敗アイコン
          Icon(iconData, size: 12, color: iconColor),
          const SizedBox(width: 4),

          // 2. 相手馬名
          SizedBox(
            width: 110,
            child: Text(
              matchup.opponentName,
              style: detailStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // 3. 相手の着順
          SizedBox(
            width: 35,
            child: Text(
              '${matchup.opponentRank}着',
              style: detailStyle,
              textAlign: TextAlign.center,
            ),
          ),

          // 4. 着差
          SizedBox(
            width: 40,
            child: Text(
              matchup.margin,
              style: detailStyle,
              textAlign: TextAlign.right,
            ),
          ),

          // 5. タイム差 (秒付き)
          SizedBox(
            width: 45,
            child: Text(
              matchup.timeDiff == '-' ? '-' : '${matchup.timeDiff}s',
              style: detailStyle.copyWith(
                  color: matchup.isWin ? Colors.red.shade700 : Colors.blue.shade700
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // 6. 相手馬番
          SizedBox(
            width: 35,
            child: Text(
              '${matchup.opponentHorseNumber}番',
              style: detailStyle,
              textAlign: TextAlign.right,
            ),
          ),

          const SizedBox(width: 8),

          // 7. 枠順比較
          Text(
            matchup.relativeGate,
            style: detailStyle.copyWith(fontSize: 10, color: Colors.grey.shade600),
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