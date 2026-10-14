// lib/widgets/condition_race_tile.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
import 'package:hetaumakeiba_v2/widgets/condition_match_chips.dart';
// [修正] 基本情報整理と本賞金照合 Step2追補: 脚質は旧方式（RaceDataParser.getSimpleLegStyle）をやめ、好走条件と同じ判定にする (v.2026.10.15+26101505)
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
// [追加] 馬詳細タブ 表示項目変更 Step2: 4行目の馬場データ（クッション値・含水率）と芝/ダの判定 (v.2026.10.15+26101501)
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';

// [追加] 好走条件 馬詳細移植 StepA-2: 出典レース1件の明細タイル（今回メンバーとの対戦成績つき）。
// 現行 ConditionHorseRow._buildDetailedRaceTile 相当を公開ウィジェット化（現行タブは不変。統合はStep B） (v.2026.9.25+26092506)
class ConditionRaceTile extends StatelessWidget {
  final PastRaceWithMatchup pastRace;

  // [追加] 馬詳細タブ 表示項目変更 Step2: その過去走の馬場データ。渡されたときだけ4行目の右にクッション値・含水率を出す（ヒートマップは渡さない） (v.2026.10.15+26101501)
  final TrackConditionRecord? trackCondition;

  const ConditionRaceTile({
    super.key,
    required this.pastRace,
    this.trackCondition,
  });

  // [追加] 馬詳細タブ 表示項目変更 Step2: 小数1桁。無ければ「-」（馬柱の表記に合わせる） (v.2026.10.15+26101501)
  static String _num1(double? v) => v == null ? '-' : v.toStringAsFixed(1);

  // [追加] 馬詳細タブ 表示項目変更 Step2: 4行目の右の文字。馬柱と同じ表記で、芝=「C:クッション値 G:芝含水率ゴール前 4c:芝含水率4コーナー」、
  // ダ=「G:ダート含水率ゴール前 4c:ダート含水率4コーナー」。データ無し・障害は null (v.2026.10.15+26101501)
  String? _trackConditionText(String distance) {
    final tc = trackCondition;
    if (tc == null) return null;
    final surface = ConditionAptitudeAnalyzer.surfaceOf(distance);
    if (surface == '芝') {
      return 'C:${_num1(tc.cushionValue)} G:${_num1(tc.moistureTurfGoal)} 4c:${_num1(tc.moistureTurf4c)}';
    }
    if (surface == 'ダ') {
      return 'G:${_num1(tc.moistureDirtGoal)} 4c:${_num1(tc.moistureDirt4c)}';
    }
    return null;
  }

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

    // [修正] 基本情報整理と本賞金照合 Step2追補: 好走条件・脚質詳細・馬柱と同じ判定（道中で先頭なら逃げ、ほかは最終コーナーの3グループ。4コーナーはマクリ判定あり） (v.2026.10.15+26101505)
    final legStyle = LegStyleAnalyzer.analyzeSingleRaceStyle(record);

    String extractedGrade = '';
    final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
    final match = gradePattern.firstMatch(record.raceName);
    if (match != null) extractedGrade = match.group(1)!;
    final gradeColor = getGradeColor(extractedGrade);

    // [修正] 馬詳細タブ 表示項目変更 Step2: 1行増やした分、行の高さを詰める（文字サイズは変えない） (v.2026.10.15+26101501)
    const detailTextStyle = TextStyle(fontSize: 11, color: Colors.black87, height: 1.15);
    const detailBoldStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.15);

    final corner = record.cornerPassage.trim();
    final trackText = _trackConditionText(record.distance);

    return Container(
      // [修正] 馬詳細タブ 表示項目変更 Step2: 上下の余白 4→2 (v.2026.10.15+26101501)
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
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
                  // [修正] 馬詳細タブ 表示項目変更 Step2: 上下の余白 8→4 (v.2026.10.15+26101501)
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                    // [修正] 馬詳細タブ 表示項目変更 Step2: 上下の余白 4→2 (v.2026.10.15+26101501)
                    padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
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
                        // [追加] 馬詳細タブ 表示項目変更 Step2: 4行目: コーナー通過順 | クッション値・含水率（馬場データを渡されたときだけ） (v.2026.10.15+26101501)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '通過 ${corner.isEmpty ? '--' : corner}',
                                style: detailTextStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trackText != null) Text(trackText, style: detailTextStyle),
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
