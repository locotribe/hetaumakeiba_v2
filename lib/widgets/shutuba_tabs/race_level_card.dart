// lib/widgets/shutuba_tabs/race_level_card.dart

// [追加] 能力分析を馬詳細へ Step4: レース情報タブの「レースレベル診断」のカード。能力分析タブの「予想レースレベル診断」のカードを移したもの。
// 言葉と色は今までと同じ。比べる相手が「今回のクラスの標準の Rt」になったので、その値を下に書く (v.2026.10.17+26101704)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_rating_summary.dart';

class RaceLevelCard extends StatelessWidget {
  final RaceLevelDiagnosis diagnosis;

  const RaceLevelCard({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String description;
    final Color color;
    if (diagnosis.kind == RaceLevelKind.high) {
      title = 'ハイレベルな一戦';
      description = 'クラス基準を大きく上回る強豪が揃いました。上位馬は昇級後も即通用する可能性があります。';
      color = Colors.red.shade700;
    } else if (diagnosis.kind == RaceLevelKind.low) {
      title = '低調なメンバー構成';
      description = '手薄な組み合わせです。能力不足の馬でも展開一つで勝機があり、波乱に注意が必要です。';
      color = Colors.blue.shade700;
    } else {
      title = '標準的なレースレベル';
      description = 'このクラスの平均的な水準のメンバーです。純粋な能力比較と適性が鍵となります。';
      color = Colors.green.shade700;
    }
    final diff = diagnosis.diff;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('予想レースレベル診断',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
              Text('分析信頼度: ${diagnosis.reliabilityGrade}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
              const SizedBox(width: 8),
              Text('数値: ${diagnosis.predictedLevel.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('(${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)})',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const Divider(height: 16),
          Text(description,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87, height: 1.4)),
          const SizedBox(height: 6),
          Text(
            '数値＝出走馬の実力Trendの平均×0.7＋今回のクラスの標準のRt（${diagnosis.classStandardRating.toStringAsFixed(1)}）×0.3。'
            'かっこ内は標準のRtとの差（±1.5で区切る）。取消の馬は除く',
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
