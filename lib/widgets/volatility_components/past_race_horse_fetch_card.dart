// lib/widgets/volatility_components/past_race_horse_fetch_card.dart

// [追加] 全出走馬の取得と読み込み Step2: 過去分析のローテタブ・血統タブの上に置く、過去レースの全出走馬の戦績・血統の取得カード。
// 見た目はすべての作業が終わってから調整する（今は必要な情報を出すだけ） (v.2026.10.16+26101609)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';
import 'package:hetaumakeiba_v2/services/past_race_horse_fetch_service.dart';

class PastRaceHorseFetchCard extends StatelessWidget {
  /// 予想するレースのID。
  final String raceId;

  /// 取る必要がある戦績・血統。数え終わるまでは null。
  final PastRaceHorseFetchPlan? plan;

  /// 共通の取得の進み具合。
  final PastRaceHorseFetchProgress progress;

  /// 取得ボタンを押したとき。
  final VoidCallback onStart;

  const PastRaceHorseFetchCard({
    super.key,
    required this.raceId,
    required this.plan,
    required this.progress,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '過去の全出走馬のデータ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildBody(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (progress.isRunningFor(raceId)) {
      final total = progress.totalHorses;
      return [
        LinearProgressIndicator(
          value: total > 0 ? progress.doneHorses / total : null,
        ),
        const SizedBox(height: 8),
        Text(
          total > 0
              ? '取得中... ${progress.doneHorses} / $total 頭（画面を閉じても続きます）'
              : '取得する馬を数えています...',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ];
    }

    final currentPlan = plan;
    if (currentPlan == null) {
      return const [
        Text('取得済みの頭数を数えています...',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
      ];
    }

    final widgets = <Widget>[
      Text(
        '全出走馬 ${currentPlan.totalHorseCount}頭のうち、'
        '戦績が無い馬 ${currentPlan.performanceHorseIds.length}頭・'
        '血統が無い馬 ${currentPlan.pedigreeHorseIds.length}頭',
        style: const TextStyle(fontSize: 13),
      ),
    ];

    if (progress.raceId == raceId && progress.failedHorses > 0) {
      widgets.addAll([
        const SizedBox(height: 4),
        Text(
          '前回の取得で ${progress.failedHorses}頭が取れませんでした。もう一度押すと、取れなかった馬だけ取り直します。',
          style: const TextStyle(fontSize: 12, color: Colors.redAccent),
        ),
      ]);
    }

    widgets.add(const SizedBox(height: 8));
    if (progress.isRunning) {
      widgets.add(const Text(
        '別のレースの過去の出走馬を取得中です。終わってから取得できます。',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ));
    } else if (currentPlan.isComplete) {
      widgets.add(const Text(
        'すべての馬の戦績・血統を取得済みです。',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ));
    } else {
      final pages = currentPlan.performanceHorseIds.length +
          currentPlan.pedigreeHorseIds.length;
      // 1ページ取るごとに1秒待つので、1ページ約2秒で見積もる
      final minutes = (pages * 2 / 60).ceil();
      widgets.add(ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.download),
        label: Text('不足しているデータを取得（約$minutes分）'),
      ));
    }
    return widgets;
  }
}
