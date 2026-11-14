// lib/widgets/condition_match_chips.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_match_engine.dart'; // MatchupBrief型のため

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

    // [追加] 対戦成績の2行化: 着順が数字のときだけ「着」を付ける（「中」「取」「除」などはそのまま） (v.2026.11.14+26111401)
    final rankText = int.tryParse(matchup.opponentRank) != null
        ? '${matchup.opponentRank}着'
        : matchup.opponentRank;

    // [修正] 対戦成績の2行化: 相手の勝ち馬との着差（左の数字）をやめ、1頭を2行にする。
    // 1行目: 上下・着順・馬番・枠の内外・馬名・馬体重 / 2行目: 騎手・斤量・着差タイム・通過順位・上がり (v.2026.11.14+26111401)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1行目 ---
          Row(
            children: [
              // 1. 勝敗アイコン
              Icon(iconData, size: 12, color: iconColor),
              const SizedBox(width: 4),

              // 2. 相手の着順
              SizedBox(
                width: 30,
                child: Text(rankText, style: detailStyle, maxLines: 1),
              ),

              // 3. 相手馬番
              SizedBox(
                width: 30,
                child: Text(
                  '${matchup.opponentHorseNumber}番',
                  style: detailStyle,
                  maxLines: 1,
                ),
              ),

              // 4. 枠順比較（相手がその馬より内か外か）
              SizedBox(
                width: 28,
                child: Text(
                  matchup.relativeGate,
                  style: detailStyle.copyWith(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                ),
              ),

              // 5. 相手馬名
              Expanded(
                child: Text(
                  matchup.opponentName,
                  style: detailStyle.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // 6. 相手の馬体重
              Text(matchup.opponentHorseWeight, style: detailStyle, maxLines: 1),
            ],
          ),

          // --- 2行目 ---
          Row(
            children: [
              // アイコンの幅だけ字下げ
              const SizedBox(width: 16),

              // 7. 相手の騎手
              SizedBox(
                width: 66,
                child: Text(
                  matchup.opponentJockey,
                  style: detailStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 8. 相手の斤量
              SizedBox(
                width: 30,
                child: Text(matchup.opponentCarriedWeight, style: detailStyle, maxLines: 1),
              ),

              // 9. タイム差 (秒付き)
              SizedBox(
                width: 44,
                child: Text(
                  matchup.timeDiff == '-' ? '-' : '${matchup.timeDiff}s',
                  style: detailStyle.copyWith(
                      color: matchup.isWin ? Colors.red.shade700 : Colors.blue.shade700
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 10),

              // 10. 相手の通過順位
              Expanded(
                child: Text(
                  matchup.opponentCornerPassage,
                  style: detailStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // 11. 相手の上がり
              Text(matchup.opponentAgari, style: detailStyle, maxLines: 1),
            ],
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