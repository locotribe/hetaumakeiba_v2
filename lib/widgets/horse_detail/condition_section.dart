// lib/widgets/horse_detail/condition_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/condition_presentation_model.dart';
// [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（クッション値/含水率） (v.2026.9.25+26092507)
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_match_engine.dart';
// [追加] 基本情報整理と本賞金照合 Step2: 脚質の割合（脚質詳細と同じ計算） (v.2026.10.15+26101505)
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/widgets/condition_race_tile.dart';
// [追加] 好走条件・個別成績・相対評価の移動 Step3: 総成績の下の回収率 (v.2026.10.17+26101708)
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_stats.dart';
// [追加] 得意条件まとめ Step1: まとめカード（個体差・得意条件）の計算と、誕生日・血統の馬プロフィール (v.2026.10.31+26103101)
import 'package:hetaumakeiba_v2/logic/analysis/horse_strength_summary.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';

// [追加] 好走条件 馬詳細移植 StepA-2: 馬詳細タブ「好走条件」ビュー。条件カテゴリ主軸（得意条件）で1頭ぶんを縦に表示 (v.2026.9.25+26092506)
class ConditionSection extends StatelessWidget {
  final PredictionHorseDetail horse;
  final Map<String, List<HorseRaceRecord>> allPastRecords;
  final List<PredictionHorseDetail> currentRaceHorses;
  final Map<String, TrackConditionRecord?> trackConditions;

  // [追加] 馬詳細タブ 表示項目変更 Step2: 今回レースの芝/ダ（'芝'/'ダ'/'障'）と当日の馬場データ。「今回」印に使う。無ければ印なし (v.2026.10.15+26101501)
  final String? currentSurface;
  final TrackConditionRecord? currentTrackCondition;

  // [追加] 好走条件・個別成績・相対評価の移動 Step3: 回収率（出走馬分析の個別成績から移した）。読み込み前・計算できないときは null (v.2026.10.17+26101708)
  final HorseRecordStats? recordStats;

  // [追加] 好走条件の改良 Step4: 好走条件の並べ替え（選んでいるもの）と、チップを押したときの知らせ。知らせが無ければチップは押せない (v.2026.10.18+26101802)
  final AptitudeSort sort;
  final ValueChanged<AptitudeSort>? onSortChanged;

  // [追加] 得意条件まとめ Step1: まとめカードに使う。この馬の馬プロフィール（誕生日・血統。読み込み前・無ければ null）、
  // 今回の出走馬（取消を除く。この馬を含む）の誕生日、今回のレースの日付と条件 (v.2026.10.31+26103101)
  final HorseProfile? profile;
  final List<DateTime> entrantBirthdays;
  final DateTime? raceDate;
  final StrengthCurrent strengthCurrent;

  const ConditionSection({
    super.key,
    required this.horse,
    required this.allPastRecords,
    required this.currentRaceHorses,
    this.trackConditions = const {},
    this.currentSurface,
    this.currentTrackCondition,
    // [追加] 好走条件・個別成績・相対評価の移動 Step3 (v.2026.10.17+26101708)
    this.recordStats,
    // [追加] 好走条件の改良 Step4 (v.2026.10.18+26101802)
    this.sort = AptitudeSort.standard,
    this.onSortChanged,
    // [追加] 得意条件まとめ Step1 (v.2026.10.31+26103101)
    this.profile,
    this.entrantBirthdays = const [],
    this.raceDate,
    this.strengthCurrent = const StrengthCurrent(),
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
    // [修正] 得意条件まとめ Step1: 過去成績が無い馬（新馬）でも、まとめカード（個体差）を上に出す (v.2026.10.31+26103101)
    if (records.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          _buildSummaryCard(records),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('過去成績がありません', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ],
      );
    }

    // [修正] 馬詳細タブ 表示項目変更 Step2: 今回レースの芝/ダ・クッション値・含水率・騎手を渡して「今回」印を付ける (v.2026.10.15+26101501)
    // [修正] 好走条件の改良 Step4: 選んだ並び（sort）で並べ替える。標準なら今までどおり (v.2026.10.18+26101802)
    final aptitude = ConditionAptitudeAnalyzer.sortedBy(
      ConditionAptitudeAnalyzer.analyze(
        records,
        trackConditions: trackConditions,
        currentSurface: currentSurface,
        currentCushionValue: currentTrackCondition?.cushionValue,
        currentMoistureDirtGoal: currentTrackCondition?.moistureDirtGoal,
        currentJockeyId: horse.jockeyId,
        currentJockeyName: horse.jockey,
      ),
      sort,
    );
    final o = aptitude.overall;
    final debut = ConditionAptitudeAnalyzer.debutRecordOf(records);

    // 出典レース（新しい順）
    final sortedRecords = List<HorseRaceRecord>.of(records)
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー（総成績）
        // [削除] 馬詳細の表示修正: 「N番 馬名」の行を出さない（ページの上の馬名で分かるため） (v.2026.10.26+26102601)
        // [追加] 馬詳細タブ 表示項目変更 Step2: デビュー戦の1行（表題は「メイクデビュー」で固定） (v.2026.10.15+26101501)
        if (debut != null) ...[
          const SizedBox(height: 2),
          _buildDebutRow(debut),
        ],
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
        // [追加] 好走条件・個別成績・相対評価の移動 Step3: 単勝・複勝の回収率（1走100円。取消・除外を除く。複勝はレース結果を保存してある走だけ） (v.2026.10.17+26101708)
        if (recordStats != null && recordStats!.starts > 0) ...[
          const SizedBox(height: 2),
          Text(
            '回収率 単勝${recordPercentLabel(recordStats!.winReturnRate)} 複勝${recordPercentLabel(recordStats!.showReturnRate)}'
            '（${recordStats!.starts}戦。取消・除外を除く）',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
        // [追加] 得意条件まとめ Step1: 総成績・回収率の下に、まとめカード（個体差・得意条件） (v.2026.10.31+26103101)
        const SizedBox(height: 6),
        _buildSummaryCard(records),
        const SizedBox(height: 6),
        // [修正] 馬詳細の表示修正: 見出し「得意条件」を外し、並べ替えのチップ（標準／勝率／複勝率／出走数）だけを左から出す (v.2026.10.26+26102601)
        _buildSortChips(),
        const Divider(height: 8),

        // カテゴリ一覧
        // [修正] 基本情報整理と本賞金照合 Step2: 脚質だけは主脚質・割合・マクリの内訳つきの部品で出す (v.2026.10.15+26101505)
        for (final cat in aptitude.categories)
          cat.name == '脚質' ? _buildLegStyleBlock(cat, records) : _buildCategoryBlock(cat),

        const SizedBox(height: 8),
        const Text('出典レース（新しい順）',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        Container(height: 1, color: Colors.grey.shade300),

        // 出典レースの明細（対戦成績つき）
        for (final r in sortedRecords) _buildRaceTile(r),
      ],
    );
  }

  // [追加] 得意条件まとめ Step1: まとめカード。上の段「個体差」（全馬）、下の段「得意条件」（4戦以上で、当てはまる条件があるとき）。
  // 苦手な条件は出さない。今回のレースに当たる得意条件には「今回」 (v.2026.10.31+26103101)
  Widget _buildSummaryCard(List<HorseRaceRecord> records) {
    String? pick(String? a, String? b) {
      final s = a?.trim() ?? '';
      if (s.isNotEmpty) return s;
      final t = b?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final traits = HorseStrengthSummary.traitsOf(
      records: records,
      raceDate: raceDate,
      birthdayText: profile?.birthday,
      entrantBirthdays: entrantBirthdays,
      currentHorseWeight: horse.horseWeight,
      currentDistanceLabel: strengthCurrent.distanceLabel,
      sireName: pick(profile?.fatherName, horse.fatherName),
      damSireName: pick(profile?.mfName, horse.mfName),
      damDamName: pick(profile?.mmName, null),
    );
    final strength = HorseStrengthSummary.strengthsOf(
      records,
      trackConditions: trackConditions,
      current: strengthCurrent,
    );

    const titleStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87);
    const noteStyle = TextStyle(fontSize: 11, color: Colors.black54);

    Widget labeled(String label, Widget child) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    Widget chip(StrengthItem item) {
      final t = item.tally;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(
            color: item.isCurrent ? Colors.blue.shade400 : Colors.green.shade400,
            width: item.isCurrent ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              if (item.isCurrent)
                TextSpan(
                  text: '今回 ',
                  style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                ),
              TextSpan(text: item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: ' ${t.first}-${t.second}-${t.third}-${t.out}'),
            ],
          ),
          style: TextStyle(fontSize: 11, color: Colors.green.shade900),
        ),
      );
    }

    final axes = <String>[];
    for (final i in strength.items) {
      if (!axes.contains(i.axis)) axes.add(i.axis);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('個体差', style: titleStyle),
          if (traits.isEmpty)
            const Text('誕生日・馬体重・血統のデータがありません', style: noteStyle)
          else
            for (final line in traits)
              labeled(line.label, Text(line.text, style: const TextStyle(fontSize: 11, color: Colors.black87))),
          const SizedBox(height: 6),
          const Text('得意条件', style: titleStyle),
          if (strength.starts == 0)
            const Text('初出走のため出しません', style: noteStyle)
          else if (!strength.hasEnoughStarts)
            Text('${strength.starts}戦のため出しません（${HorseStrengthSummary.minStarts}戦以上で出します）', style: noteStyle)
          else if (strength.items.isEmpty)
            const Text('目立って好走している条件はありません', style: noteStyle)
          else ...[
            for (final axis in axes)
              labeled(
                axis,
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final i in strength.items)
                      if (i.axis == axis) chip(i),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            const Text(
              '同じ条件で2走以上・複勝率50%以上・通算の複勝率より15pt以上高い条件。クッション値・含水率は3着以内だった走の幅と、その幅に入る全部の走の成績',
              style: TextStyle(fontSize: 9.5, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  // [追加] 馬詳細タブ 表示項目変更 Step2: 「メイクデビュー 開催場 芝1600m 脚質 1着(2人気)」。読めない項目は「--」 (v.2026.10.15+26101501)
  Widget _buildDebutRow(HorseRaceRecord debut) {
    final venue = debut.venue.replaceAll(RegExp(r'\d'), '');
    final surface = ConditionAptitudeAnalyzer.surfaceOf(debut.distance);
    final meters = ConditionAptitudeAnalyzer.distanceMetersOf(debut.distance);
    final course = (surface != null && meters != null) ? '$surface${meters}m' : '--';
    final legStyle = ConditionAptitudeAnalyzer.legStyleOf(debut) ?? '--';
    final rankText = debut.rank.trim();
    final rankLabel = rankText.isEmpty
        ? '--'
        : (RegExp(r'^\d').hasMatch(rankText) ? '$rankText着' : rankText);
    final popularity = debut.popularity.trim();
    final result = popularity.isEmpty ? rankLabel : '$rankLabel($popularity人気)';
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'メイクデビュー',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          TextSpan(text: '  ${venue.isEmpty ? '--' : venue} $course $legStyle  $result'),
        ],
      ),
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // [追加] 好走条件の改良 Step4: 並べ替えのチップ（標準＝今の並び。標準以外は全カテゴリを選んだ順に並べ、2走未満は下） (v.2026.10.18+26101802)
  Widget _buildSortChips() {
    const labels = {
      AptitudeSort.standard: '標準',
      AptitudeSort.winRate: '勝率',
      AptitudeSort.showRate: '複勝率',
      AptitudeSort.starts: '出走数',
    };
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final s in AptitudeSort.values)
          ChoiceChip(
            label: Text(labels[s]!, style: const TextStyle(fontSize: 11)),
            selected: sort == s,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: onSortChanged == null ? null : (_) => onSortChanged!(s),
          ),
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

  // [追加] 基本情報整理と本賞金照合 Step2: 脚質のカテゴリ。各行の右端に割合（マクリは回数）、
  // マクリと判定した走があれば、その競馬場と距離を新しい順に1行で出す。割合は脚質詳細と同じ（マクリを除いた4脚質の中の割合） (v.2026.10.15+26101505)
  Widget _buildLegStyleBlock(AptitudeCategory cat, List<HorseRaceRecord> records) {
    final profile = LegStyleAnalyzer.getRunningStyle(records);
    final makuriRecords = records
        .where((r) => ConditionAptitudeAnalyzer.legStyleOf(r) == 'マクリ')
        .toList()
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
          child: Text(cat.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        for (final v in cat.values)
          _buildValueRow(
            v,
            extraText: v.label == 'マクリ'
                ? '${v.tally.total}回'
                : '割合${((profile.styleDistribution[v.label] ?? 0.0) * 100).round()}%',
          ),
        if (makuriRecords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              'マクリ: ${makuriRecords.map(_courseLabelOf).join(' / ')}',
              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
            ),
          ),
        const SizedBox(height: 2),
      ],
    );
  }

  // [追加] 基本情報整理と本賞金照合 Step2: 「中山 芝2000m」（開催場は数字を除く。読めない部分は「--」。デビュー戦の行と同じ書き方） (v.2026.10.15+26101505)
  String _courseLabelOf(HorseRaceRecord r) {
    final venue = r.venue.replaceAll(RegExp(r'\d'), '');
    final surface = ConditionAptitudeAnalyzer.surfaceOf(r.distance);
    final meters = ConditionAptitudeAnalyzer.distanceMetersOf(r.distance);
    final course = (surface != null && meters != null) ? '$surface${meters}m' : '--';
    return '${venue.isEmpty ? '--' : venue} $course';
  }

  // [修正] 基本情報整理と本賞金照合 Step2: 右端に出す文字（extraText。脚質の割合・マクリの回数）を任意で受け取る。無ければ今までどおり (v.2026.10.15+26101505)
  Widget _buildValueRow(AptitudeValue v, {String? extraText}) {
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
          // [追加] 基本情報整理と本賞金照合 Step2: 脚質の割合（マクリは回数）。他のカテゴリは extraText が無いので出ない (v.2026.10.15+26101505)
          if (extraText != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(extraText,
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ),
          if (v.isReference)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('参考', style: TextStyle(fontSize: 9, color: Colors.black38)),
            ),
          // [追加] 馬詳細タブ 表示項目変更 Step2: 今回レースの条件に当たる値（クッション値・含水率の段、今回の騎手）に「今回」 (v.2026.10.15+26101501)
          if (v.isCurrent)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade400),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('今回',
                  style: TextStyle(fontSize: 8, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
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
    // [修正] 馬詳細タブ 表示項目変更 Step2: その過去走の馬場データ（クッション値・含水率）をタイルに渡す (v.2026.10.15+26101501)
    return ConditionRaceTile(
      pastRace: PastRaceWithMatchup(record: r, matchupContext: matchup),
      trackCondition: trackConditions[r.raceId],
    );
  }
}
