// lib/widgets/condition_race_tile.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
import 'package:hetaumakeiba_v2/widgets/condition_match_chips.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';

// [追加] 好走条件 馬詳細移植 StepA-2: 出典レース1件の明細タイル（今回メンバーとの対戦成績つき）。
// 現行 ConditionHorseRow._buildDetailedRaceTile 相当を公開ウィジェット化（現行タブは不変。統合はStep B） (v.2026.9.25+26092506)
class ConditionRaceTile extends StatelessWidget {
  final PastRaceWithMatchup pastRace;

  const ConditionRaceTile({
    super.key,
    required this.pastRace,
  });

  @override
  Widget build(BuildContext context) {
    final record = pastRace.record;

    // 着順による色分け
    final rankInt = int.tryParse(record.rank);
    Color rankBgColor = Colors.transparent;
    Color rankTextColor = Colors.black87;
    if (rankInt != null) {
      if (rankInt == 1) {
        rankBgColor = Colors.pink.shade50;
        rankTextColor = Colors.pink;
      } else if (rankInt == 2) {
        rankBgColor = Colors.blue.shade50;
        rankTextColor = Colors.blue;
      } else if (rankInt == 3) {
        rankBgColor = Colors.orange.shade50;
        rankTextColor = Colors.orange.shade800;
      }
    }

    final legStyle =
        RaceDataParser.getSimpleLegStyle(record.cornerPassage, record.numberOfHorses);

    String extractedGrade = '';
    final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
    final match = gradePattern.firstMatch(record.raceName);
    if (match != null) extractedGrade = match.group(1)!;
    final gradeColor = getGradeColor(extractedGrade);

    const detailTextStyle = TextStyle(fontSize: 11, color: Colors.black87);
    const detailBoldStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 左列 (着順/人気/脚質) ---
                Container(
                  width: 45,
                  decoration: BoxDecoration(
                    color: rankBgColor,
                    border: Border(
                      left: BorderSide(color: gradeColor, width: 4.0),
                      right: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        record.rank,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: rankTextColor),
                      ),
                      Text('${record.popularity}人', style: const TextStyle(fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(legStyle, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),

                // --- 右列 (レース詳細情報) ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1行目: 日付・場所・天気・馬場・頭数 | タイム
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${record.date} ${record.venue.replaceAll(RegExp(r'\d'), '')} ${record.weather}/${record.trackCondition}/${record.numberOfHorses}頭',
                                style: detailTextStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(record.time, style: detailBoldStyle),
                          ],
                        ),
                        // 2行目: レース名(グレード除く)・距離 | 上がり
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${record.raceName.replaceAll(RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3}|L)\)', caseSensitive: false), '').trim()} ${record.distance}',
                                style: detailTextStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(record.agari, style: detailBoldStyle),
                          ],
                        ),
                        // 3行目: 馬番・体重・騎手(斤量) | 着差
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${record.horseNumber}番 ${record.horseWeight} ${record.jockey}(${record.carriedWeight})',
                                style: detailTextStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(record.margin, style: detailBoldStyle),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 対戦成績リスト (着順昇順で並び替えて表示) ---
          if (pastRace.matchupContext != null && pastRace.matchupContext!.matchups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 4.0),
              child: Column(
                children: () {
                  final sortedMatchups = List.of(pastRace.matchupContext!.matchups)
                    ..sort((a, b) {
                      final rankA = int.tryParse(a.opponentRank) ?? 999;
                      final rankB = int.tryParse(b.opponentRank) ?? 999;
                      return rankA.compareTo(rankB);
                    });

                  return sortedMatchups.map((m) {
                    return MatchupResultRow(matchup: m);
                  }).toList();
                }(),
              ),
            ),
        ],
      ),
    );
  }
}
