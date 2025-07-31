// lib/widgets/featured_race_list_item.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';

// ▼▼▼ 日付をパースするためのヘルパー関数を追加 ▼▼▼
DateTime _parseDateStringAsDateTime(String dateText) {
  try {
    final yearMonthDayMatch = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(dateText);
    if (yearMonthDayMatch != null) {
      final year = int.parse(yearMonthDayMatch.group(1)!);
      final month = int.parse(yearMonthDayMatch.group(2)!);
      final day = int.parse(yearMonthDayMatch.group(3)!);
      return DateTime(year, month, day);
    }
    final monthDayMatch = RegExp(r'(\d+)月(\d+)日').firstMatch(dateText);
    if (monthDayMatch != null) {
      final month = int.parse(monthDayMatch.group(1)!);
      final day = int.parse(monthDayMatch.group(2)!);
      return DateTime(DateTime.now().year, month, day);
    }
    final slashDateMatch = RegExp(r'(\d+)/(\d+)').firstMatch(dateText);
    if (slashDateMatch != null) {
      final month = int.parse(slashDateMatch.group(1)!);
      final day = int.parse(slashDateMatch.group(2)!);
      return DateTime(DateTime.now().year, month, day);
    }
    return DateTime.now();
  } catch (e) {
    print('Date parsing error in FeaturedRaceListItem: $dateText, Error: $e');
    return DateTime.now();
  }
}
// ▲▲▲ ヘルパー関数の追加ここまで ▲▲▲

class FeaturedRaceListItem extends StatelessWidget {
  final FeaturedRace race;
  final VoidCallback onTap;

  const FeaturedRaceListItem({
    super.key,
    required this.race,
    required this.onTap,
  });

  // グレードに応じた色を返すヘルパーメソッド
  Color _getGradeColor(String grade) {
    if (grade.contains('G1')) return Colors.blue.shade700;
    if (grade.contains('G2')) return Colors.red.shade700;
    if (grade.contains('G3')) return Colors.green.shade700;
    return Colors.blueGrey; // デフォルト色
  }

  // グレードアイコンの文字色は白で統一
  Color _getGradeTextColor(String grade) {
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor(race.raceGrade);
    final bool hasDetails = race.raceDetails1 != null && race.raceDetails1!.isNotEmpty;

    // ▼▼▼ 表示を「>」アイコンから「確/未」表示に切り替えるロジック ▼▼▼
    Widget buildStatusWidget() {
      // 月別一覧のレース（詳細情報がないレース）かどうかを判定
      final bool isMonthlyRace = !hasDetails;

      if (isMonthlyRace) {
        final raceDate = _parseDateStringAsDateTime(race.raceDate);
        // レース開催日の16時を「終了時刻」と定義
        final raceFinishTime = raceDate.add(const Duration(hours: 16));
        final bool isConfirmed = DateTime.now().isAfter(raceFinishTime);

        return Container(
          width: 28.0,
          height: 28.0,
          color: isConfirmed ? Colors.red : Colors.grey,
          child: Center(
            child: Text(
              isConfirmed ? '確' : '未',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else {
        // 今週の重賞レースの場合は、元の「>」アイコンを表示
        return const Icon(Icons.chevron_right, color: Colors.grey);
      }
    }
    // ▲▲▲ ロジックの追加ここまで ▲▲▲


    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(left: BorderSide(color: gradeColor, width: 5)),
        ),
        child: Row(
          children: [
            // 左側: グレードアイコン
            Container(
              width: 30,
              height: 25,
              decoration: BoxDecoration(
                color: gradeColor,
               // shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  race.raceGrade,
                  style: TextStyle(
                    color: _getGradeTextColor(race.raceGrade),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16.0),
            // 中央: レース情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    race.raceName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  if (hasDetails) ...[
                    Text(
                      race.raceDetails1 ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      race.raceDetails2 ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      '${race.raceDate}'
                          '${race.raceNumber.isNotEmpty ? ' / ${race.venue} ${race.raceNumber}R' : ' / ${race.venue}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '${race.distance} / ${race.conditions} / ${race.weight}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
            // ▼▼▼ 右側の表示を新しいウィジェットに置き換え ▼▼▼
            buildStatusWidget(),
            // ▲▲▲ ここまで ▲▲▲
          ],
        ),
      ),
    );
  }
}