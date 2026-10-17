// lib/widgets/horse_detail/rating_all_horses_view.dart

// [追加] 能力分析を馬詳細へ Step3: 馬詳細の「全」ページの「能力」チップの表。全頭の 実力Trend・期待値Gap・前走Rt・勢い（状態サイクル）を
// 実力Trendの高い順に並べる（能力分析タブの「基本・期待値」と同じ順）。取消の馬はいちばん下に薄く出す。行のタップでその馬の「能力・条件」へ (v.2026.10.17+26101703)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_rating_summary.dart';
// [追加] 好走条件・個別成績・相対評価の移動 Step3: 2段目の通算成績と回収率 (v.2026.10.17+26101708)
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_stats.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/rating_section.dart';
import 'package:hetaumakeiba_v2/widgets/rating/components/rating_level_badge.dart';

class RatingAllHorsesView extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final RaceRatingSummary summary;
  final ValueChanged<PredictionHorseDetail> onSelectHorse;

  // [追加] 好走条件・個別成績・相対評価の移動 Step3: 馬ごとの通算成績と回収率（馬ID→成績）。無い馬は2段目を出さない (v.2026.10.17+26101708)
  final Map<String, HorseRecordStats> recordStats;

  const RatingAllHorsesView({
    super.key,
    required this.horses,
    required this.summary,
    required this.onSelectHorse,
    this.recordStats = const {},
  });

  static const double _numberWidth = 26;
  static const double _trendWidth = 44;
  static const double _gapWidth = 54;
  static const double _lastWidth = 58;
  static const double _momentumWidth = 62;

  static const TextStyle _headerStyle = TextStyle(
      fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54);

  @override
  Widget build(BuildContext context) {
    final byId = {for (final h in horses) h.horseId: h};
    final ordered = <PredictionHorseDetail>[
      for (final id in summary.trendOrder)
        if (byId[id] != null) byId[id]!,
      for (final h in horses)
        if (!summary.trendOrder.contains(h.horseId)) h,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            // [修正] 好走条件・個別成績・相対評価の移動 Step3: 2段目（通算成績と回収率）の説明を足した (v.2026.10.17+26101708)
            '実力Trendの高い順。期待値Gap＝今回の人気−Trend順位（＋は人気より能力が上）。2段目は今回より前の通算成績（取消・除外を除く）と単勝・複勝の回収率。行をタップでその馬の「能力・条件」へ',
            style: TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ),
        _buildHeader(),
        for (final horse in ordered) _buildRow(horse),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: _numberWidth,
              child: Center(child: Text('馬番', style: _headerStyle))),
          SizedBox(width: 6),
          Expanded(child: Text('馬名', style: _headerStyle)),
          SizedBox(
              width: _trendWidth,
              child: Center(child: Text('Trend', style: _headerStyle))),
          SizedBox(
              width: _gapWidth,
              child: Center(child: Text('Gap', style: _headerStyle))),
          SizedBox(
              width: _lastWidth,
              child: Center(child: Text('前走Rt', style: _headerStyle))),
          SizedBox(
              width: _momentumWidth,
              child: Center(child: Text('勢い', style: _headerStyle))),
        ],
      ),
    );
  }

  // [追加] 好走条件・個別成績・相対評価の移動 Step3: 2段目の文字（例「12戦 勝率8% 複勝率33% 単回45% 複回80%」） (v.2026.10.17+26101708)
  static String _recordLineOf(HorseRecordStats stats) {
    if (stats.starts == 0) return '出走歴なし';
    return '${stats.starts}戦 勝率${recordPercentLabel(stats.winRate)} 複勝率${recordPercentLabel(stats.showRate)} '
        '単回${recordPercentLabel(stats.winReturnRate)} 複回${recordPercentLabel(stats.showReturnRate)}';
  }

  Widget _buildRow(PredictionHorseDetail horse) {
    final profile = summary.profileOf(horse.horseId);
    // [追加] 好走条件・個別成績・相対評価の移動 Step3 (v.2026.10.17+26101708)
    final stats = recordStats[horse.horseId];
    final history = profile?.history ?? const <RatingAnalyzedResult>[];
    final hasGate = horse.gateNumber > 0;
    final gap = summary.gapOf(horse);
    final last = history.isNotEmpty ? history.last : null;

    final Widget trendCell = (profile == null || history.isEmpty)
        ? const Text('-', style: TextStyle(fontSize: 12))
        : Text(
            profile.latestTrend.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: ratingTrendColorOf(profile.latestTrend),
            ),
          );

    final Widget gapCell;
    if (horse.isScratched) {
      gapCell = const Text('取消',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red));
    } else if (gap == null) {
      gapCell = const Text('-', style: TextStyle(fontSize: 12));
    } else {
      final color = ratingGapColorOf(gap);
      gapCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(gap > 0 ? '+$gap' : '$gap',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(ratingGapLabelOf(gap),
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      );
    }

    final Widget lastCell = last == null
        ? const Text('-', style: TextStyle(fontSize: 12))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(last.raceRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RatingLevelBadge(
                  level: last.levelGrade,
                  rankStr: last.record.rank,
                ),
              ),
            ],
          );

    final status = profile?.momentumStatus ?? 'データなし';
    final Widget momentumCell = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: ratingMomentumColorOf(status),
        ),
      ),
    );

    return InkWell(
      onTap: () => onSelectHorse(horse),
      child: Opacity(
        opacity: horse.isScratched ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          // [修正] 好走条件・個別成績・相対評価の移動 Step3: 2段目に通算成績と回収率（出走馬分析の個別成績から移した）を出す。今までの1段目は字下げしただけで中身は同じ (v.2026.10.17+26101708)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: _numberWidth,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasGate
                              ? horse.gateNumber.gateBackgroundColor
                              : Colors.grey.shade400,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          horse.horseNumber > 0 ? '${horse.horseNumber}' : '-',
                          style: TextStyle(
                            color: hasGate
                                ? horse.gateNumber.gateTextColor
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      horse.horseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration:
                            horse.isScratched ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  SizedBox(width: _trendWidth, child: Center(child: trendCell)),
                  SizedBox(width: _gapWidth, child: Center(child: gapCell)),
                  SizedBox(width: _lastWidth, child: Center(child: lastCell)),
                  SizedBox(
                      width: _momentumWidth, child: Center(child: momentumCell)),
                ],
              ),
              if (stats != null)
                Padding(
                  padding: const EdgeInsets.only(left: _numberWidth + 6, top: 2),
                  child: Text(
                    _recordLineOf(stats),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
