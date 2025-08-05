// lib/widgets/featured_race_list_item.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';

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

class FeaturedRaceListItem extends StatelessWidget {
  final FeaturedRace race;
  final String? dayOfWeek; // ★ requiredを外し、String? に変更
  final VoidCallback onTap;

  const FeaturedRaceListItem({
    super.key,
    required this.race,
    this.dayOfWeek, // ★ requiredを外す
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
            SizedBox(
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 25,
                    decoration: BoxDecoration(
                      color: gradeColor,
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
                  // ★ dayOfWeekが渡された時だけ表示するように修正
                  if (dayOfWeek != null && dayOfWeek!.isNotEmpty) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      dayOfWeek!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
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
                    Builder(
                        builder: (context) {
                          String formattedDetails2 = race.raceDetails2 ?? '';
                          // 「(」の位置を探す
                          final parenIndex = formattedDetails2.indexOf('頭');

                          // 「(」が見つかり、かつその位置が2文字目以降の場合
                          if (parenIndex >= 2) {
                            // 「(」の2文字前の位置を計算
                            final breakIndex = parenIndex - 2;
                            // 計算した位置で文字列を分割し、間に改行コードを入れる
                            final part1 = formattedDetails2.substring(0, breakIndex);
                            final part2 = formattedDetails2.substring(breakIndex);
                            formattedDetails2 = '$part1\n$part2';
                          }

                          return Text(
                            formattedDetails2,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          );
                        }
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
            buildStatusWidget(),
          ],
        ),
      ),
    );
  }
}