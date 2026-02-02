// lib/widgets/condition_horse_row.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
import 'package:hetaumakeiba_v2/widgets/condition_match_chips.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';

/// 1頭の好走条件サマリーを表示し、詳細をアコーディオン展開する行ウィジェット
class ConditionHorseRow extends StatefulWidget {
  final HorseConditionDisplayData data;

  const ConditionHorseRow({
    super.key,
    required this.data,
  });

  @override
  State<ConditionHorseRow> createState() => _ConditionHorseRowState();
}

class _ConditionHorseRowState extends State<ConditionHorseRow> {
  bool _isExpanded = false;
  String? _selectedRankLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // メイン行：馬名と着順別のサマリー（水平スクロール対応）
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            color: _isExpanded ? Colors.blue.withAlpha(10) : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 馬名エリア（ここをタップで開閉）
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                    // 開くときにラベルが未選択なら最初のものを選択
                    if (_isExpanded && _selectedRankLabel == null && widget.data.summaries.isNotEmpty) {
                      _selectedRankLabel = widget.data.summaries.keys.first;
                    }
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
                  child: Text(
                    widget.data.horseName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              // サマリー行（ここをタップしても親の開閉はトリガーせず、タブ切り替えを行う）
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                child: Row(
                  children: widget.data.summaries.entries.map((entry) {
                    final isSelected = _selectedRankLabel == entry.key && _isExpanded;
                    return _buildSummaryCell(entry.key, entry.value, isSelected);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // 展開パネル：選択された着順の過去レース詳細（垂直リスト）
        if (_isExpanded && _selectedRankLabel != null && widget.data.summaries.containsKey(_selectedRankLabel))
          Container(
            color: Colors.grey.shade50,
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              children: widget.data.summaries[_selectedRankLabel]!.detailedRaces.map((pastRace) {
                return _buildDetailedRaceTile(pastRace);
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// 着順別のサマリーセル
  Widget _buildSummaryCell(String label, RankSummaryDisplay summary, bool isSelected) {
    const leftTextStyle = TextStyle(fontSize: 11);
    final rightTextStyle = TextStyle(fontSize: 10, color: Colors.grey.shade700);
    final rightLabelStyle = TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold);

    // 1. 脚質の集計
    final Map<String, int> legStyleCounts = {};
    for (var race in summary.detailedRaces) {
      final style = RaceDataParser.getSimpleLegStyle(race.record.cornerPassage, race.record.numberOfHorses);
      legStyleCounts[style] = (legStyleCounts[style] ?? 0) + 1;
    }
    final legStyleOrder = ['逃げ', '先行', '差し', '追込', 'マクリ', '不明'];
    final legStyleSortedMap = Map.fromEntries(
        legStyleOrder
            .where((style) => legStyleCounts.containsKey(style) && legStyleCounts[style]! > 0)
            .map((style) => MapEntry(style, legStyleCounts[style]!))
    );

    // 2. 馬場の集計
    final Map<String, int> trackCounts = {};
    for (var race in summary.detailedRaces) {
      if (race.record.trackCondition.isNotEmpty) {
        trackCounts[race.record.trackCondition] = (trackCounts[race.record.trackCondition] ?? 0) + 1;
      }
    }

    // 3. 人気の集計
    final Map<String, int> popularityCounts = {};
    for (var race in summary.detailedRaces) {
      if (race.record.popularity.isNotEmpty) {
        final key = '${race.record.popularity}人';
        popularityCounts[key] = (popularityCounts[key] ?? 0) + 1;
      }
    }
    final sortedPopKeys = popularityCounts.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
        final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
        return aNum.compareTo(bNum);
      });
    final popularitySortedMap = Map.fromEntries(
        sortedPopKeys.map((key) => MapEntry(key, popularityCounts[key]!))
    );

    // 4. 開催場所の集計
    final Map<String, int> venueCounts = {};
    for (var race in summary.detailedRaces) {
      final venue = race.record.venue.replaceAll(RegExp(r'\d'), '');
      if (venue.isNotEmpty) {
        venueCounts[venue] = (venueCounts[venue] ?? 0) + 1;
      }
    }

    // 5. 天候の集計
    final Map<String, int> weatherCounts = {};
    for (var race in summary.detailedRaces) {
      if (race.record.weather.isNotEmpty) {
        weatherCounts[race.record.weather] = (weatherCounts[race.record.weather] ?? 0) + 1;
      }
    }

    // 6. グレード別集計
    int g1Count = 0;
    int g2Count = 0;
    int g3Count = 0;
    int opCount = 0;
    int conditionCount = 0;

    for (var race in summary.detailedRaces) {
      final raceName = race.record.raceName;
      if (raceName.contains('(GI)')) {
        g1Count++;
      } else if (raceName.contains('(GII)')) {
        g2Count++;
      } else if (raceName.contains('(GIII)')) {
        g3Count++;
      } else if (raceName.contains('OP') || raceName.contains('L)')) {
        opCount++;
      } else {
        conditionCount++;
      }
    }

    List<String> parts = [];
    if (g1Count > 0) parts.add('G1【$g1Count】');
    if (g2Count > 0) parts.add('G2【$g2Count】');
    if (g3Count > 0) parts.add('G3【$g3Count】');
    if (opCount > 0) parts.add('OP【$opCount】');
    if (conditionCount > 0) parts.add('条件【$conditionCount】');

    final gradeDistribution = parts.join('　');

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = true;
          _selectedRankLabel = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4.0),
        ),
        width: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: 着順と回数
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  gradeDistribution,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                    children: [
                      const TextSpan(text: '計 '),
                      TextSpan(
                        text: '${summary.count}',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const TextSpan(text: ' 回'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 8),

            // 各集計行
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(children: [
                    Text("開催", style: rightLabelStyle),
                    const SizedBox(width: 4),
                    Expanded(child: _buildRichSummaryText(venueCounts, rightTextStyle)),
                  ]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: Row(children: [
                    Text("距離", style: rightLabelStyle),
                    const SizedBox(width: 4),
                    Expanded(child: Text(summary.distanceRange, style: leftTextStyle)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(children: [
                    Text("馬場", style: rightLabelStyle),
                    const SizedBox(width: 4),
                    Expanded(child: _buildRichSummaryText(trackCounts, rightTextStyle)),
                  ]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: Row(children: [
                    Text("脚質", style: rightLabelStyle),
                    const SizedBox(width: 4),
                    Expanded(child: _buildRichSummaryText(legStyleSortedMap, rightTextStyle)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(children: [
                    Text("天候", style: rightLabelStyle),
                    const SizedBox(width: 4),
                    Expanded(child: _buildRichSummaryText(weatherCounts, rightTextStyle)),
                  ]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: Row(children: [
                    Text("人気", style: rightLabelStyle),
                    const SizedBox(width: 4),
                    Expanded(child: _buildRichSummaryText(popularitySortedMap, rightTextStyle)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(children: [
                    Text("回り", style: rightLabelStyle),
                    const SizedBox(width: 2),
                    Expanded(child: Text(summary.directionSummary, style: rightTextStyle, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: Row(children: [
                    Text("斤量", style: rightLabelStyle),
                    const SizedBox(width: 2),
                    Expanded(child: Text(summary.carriedWeightRange, style: leftTextStyle)),
                  ]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: Row(children: [
                    Text("体重", style: rightLabelStyle),
                    const SizedBox(width: 2),
                    Expanded(child: Text(summary.weightRange, style: leftTextStyle)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 集計マップから、数字を強調したRichTextを作成するヘルパー
  Widget _buildRichSummaryText(Map<String, int> counts, TextStyle baseStyle) {
    if (counts.isEmpty) {
      return Text('-', style: baseStyle);
    }

    final highlightStyle = baseStyle.copyWith(
      color: Colors.blue.shade700,
      fontWeight: FontWeight.bold,
    );

    List<InlineSpan> spans = [];
    int index = 0;
    for (var entry in counts.entries) {
      if (index > 0) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
      spans.add(TextSpan(text: entry.key, style: baseStyle));
      spans.add(TextSpan(text: '(', style: baseStyle));
      spans.add(TextSpan(text: '${entry.value}', style: highlightStyle));
      spans.add(TextSpan(text: ')', style: baseStyle));
      index++;
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 詳細レース情報タイル
  Widget _buildDetailedRaceTile(PastRaceWithMatchup pastRace) {
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

    final legStyle = RaceDataParser.getSimpleLegStyle(record.cornerPassage, record.numberOfHorses);

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
                  // リストをコピーして着順(数値)でソート
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