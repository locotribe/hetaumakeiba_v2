// lib/widgets/featured_race_list_item.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';

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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: gradeColor,
                shape: BoxShape.circle,
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
                  Text(
                    '${race.raceDate} / ${race.venue} ${race.raceNumber}R',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            // 右側: アクションアイコン
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
