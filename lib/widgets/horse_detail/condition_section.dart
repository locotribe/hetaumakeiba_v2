// lib/widgets/horse_detail/condition_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
// [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（クッション値/含水率） (v.2026.9.25+26092507)
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_match_engine.dart';
import 'package:hetaumakeiba_v2/widgets/condition_race_tile.dart';

// [追加] 好走条件 馬詳細移植 StepA-2: 馬詳細タブ「好走条件」ビュー。条件カテゴリ主軸（得意条件）で1頭ぶんを縦に表示 (v.2026.9.25+26092506)
class ConditionSection extends StatelessWidget {
  final PredictionHorseDetail horse;
  final Map<String, List<HorseRaceRecord>> allPastRecords;
  final List<PredictionHorseDetail> currentRaceHorses;
  final Map<String, TrackConditionRecord?> trackConditions;

  const ConditionSection({
    super.key,
    required this.horse,
    required this.allPastRecords,
    required this.currentRaceHorses,
    this.trackConditions = const {},
  });

  // 1着=赤 / 2着=青 / 3着=橙 / 着外=灰
  static const Color _c1 = Color(0xFFEF5350);
  static const Color _c2 = Color(0xFF42A5F5);
  static const Color _c3 = Color(0xFFFFA726);
  static const Color _cOut = Color(0xFFE0E0E0);

  DateTime _parseDate(String s) {
    final p = s.split('/');
    if (p.length == 3) {
      final y = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime(1900);
  }

  @override
  Widget build(BuildContext context) {
    final records = allPastRecords[horse.horseId] ?? const <HorseRaceRecord>[];
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('過去成績がありません', style: TextStyle(fontSize: 12, color: Colors.black54)),
      );
    }

    final aptitude = ConditionAptitudeAnalyzer.analyze(records, trackConditions: trackConditions);
    final o = aptitude.overall;

    // 出典レース（新しい順）
    final sortedRecords = List<HorseRaceRecord>.of(records)
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー（総成績）
        Text('${horse.horseNumber}番 ${horse.horseName}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Row(
          children: [
            Text('総${o.total}戦 [${o.first}-${o.second}-${o.third}-${o.out}]',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(width: 10),
            Text('勝率${(o.winRate * 100).round()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.pink)),
            const SizedBox(width: 8),
            Text('複勝${(o.showRate * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('得意条件（勝率順）',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
        const Divider(height: 8),

        // カテゴリ一覧
        for (final cat in aptitude.categories) _buildCategoryBlock(cat),

        const SizedBox(height: 8),
        const Text('出典レース（新しい順）',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        Container(height: 1, color: Colors.grey.shade300),

        // 出典レースの明細（対戦成績つき）
        for (final r in sortedRecords) _buildRaceTile(r),
      ],
    );
  }

  Widget _buildCategoryBlock(AptitudeCategory cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
          child: Text(cat.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        for (final v in cat.values) _buildValueRow(v),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildValueRow(AptitudeValue v) {
    final t = v.tally;
    final winPct = (t.winRate * 100).round();

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Row(
              children: [
                Flexible(
                  child: Text(v.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: v.isBest ? FontWeight.bold : FontWeight.normal,
                      )),
                ),
                if (v.isBest)
                  Container(
                    margin: const EdgeInsets.only(left: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade400),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('得意',
                        style: TextStyle(fontSize: 8, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          _buildBar(t),
          const SizedBox(width: 6),
          Text('[${t.first}-${t.second}-${t.third}-${t.out}]',
              style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
          const SizedBox(width: 6),
          Text('$winPct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: v.isBest ? Colors.red.shade700 : Colors.black87,
              )),
          if (v.isReference)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('参考', style: TextStyle(fontSize: 9, color: Colors.black38)),
            ),
        ],
      ),
    );

    // 参考（1走のみ）は淡色
    return v.isReference ? Opacity(opacity: 0.55, child: row) : row;
  }

  Widget _buildBar(RankTally t) {
    final segs = <Widget>[];
    void add(int c, Color col) {
      if (c > 0) segs.add(Expanded(flex: c, child: Container(color: col)));
    }
    add(t.first, _c1);
    add(t.second, _c2);
    add(t.third, _c3);
    add(t.out, _cOut);
    return SizedBox(
      width: 72,
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Row(children: segs),
      ),
    );
  }

  Widget _buildRaceTile(HorseRaceRecord r) {
    final matchup = ConditionMatchEngine.scanMatchups(
      targetRaceId: r.raceId,
      myHorseId: horse.horseId,
      myRank: r.rank,
      currentRaceMembers: currentRaceHorses,
      allHorsesPastRecords: allPastRecords,
    );
    return ConditionRaceTile(
      pastRace: PastRaceWithMatchup(record: r, matchupContext: matchup),
    );
  }
}
