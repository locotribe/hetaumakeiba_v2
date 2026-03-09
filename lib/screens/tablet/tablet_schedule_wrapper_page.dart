import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/jyusyoichiran_page.dart';
import 'package:hetaumakeiba_v2/screens/race_schedule_page.dart';

class TabletScheduleWrapperPage extends StatelessWidget {
  const TabletScheduleWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 画面全体を横並び（Row）にする単純な箱です
    return Row(
      children: [
        // 左側：開催一覧カレンダー（横幅の 60% を占有）
        Expanded(
          flex: 6,
          child: const RaceSchedulePage(),
        ),

        // 中央の境界線
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: Colors.grey,
        ),

        // 右側：重賞一覧リスト（横幅の 40% を占有）
        Expanded(
          flex: 4,
          child: const JyusyoIchiranPage(),
        ),
      ],
    );
  }
}