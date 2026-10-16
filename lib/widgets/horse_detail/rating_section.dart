// lib/widgets/horse_detail/rating_section.dart

// [追加] 能力分析を馬詳細へ Step2: 馬詳細の「能力・条件」の上の段。1頭の Rt の要約（実力Trend・順位・期待値Gap・前走Rt・安定度・状態サイクル）、
// 条件適合（クラス壁・斤量・季節）、Rt の推移を出す。計算は race_rating_summary.dart（能力分析タブから移した）。
// 色と言葉は能力分析タブと同じ。「全」ページの能力の表（rating_all_horses_view.dart）も、ここの色の関数を使う (v.2026.10.17+26101702)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_rating_summary.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/widgets/rating/components/rating_level_badge.dart';
import 'package:hetaumakeiba_v2/widgets/rating/components/rating_sparkline.dart';

/// 期待値Gap の色（能力分析タブと同じ）。
Color ratingGapColorOf(int gap) {
  if (gap >= 6) return Colors.red.shade700;
  if (gap >= 3) return Colors.orange.shade800;
  if (gap <= -6) return Colors.blue.shade800;
  if (gap <= -3) return Colors.blue.shade400;
  return Colors.grey;
}

/// 状態サイクルの色（能力分析タブと同じ）。
Color ratingMomentumColorOf(String momentumStatus) {
  switch (momentumStatus) {
    case '反動警戒':
      return Colors.red;
    case '上昇期':
      return Colors.orange;
    case '叩き一変注意':
      return Colors.blue;
    default:
      return Colors.black87;
  }
}

/// 実力Trend の色（105以上は赤。能力分析タブと同じ）。
Color ratingTrendColorOf(double trend) =>
    trend >= 105 ? Colors.red : Colors.blue.shade900;

class RatingSection extends StatelessWidget {
  final PredictionHorseDetail horse;
  final RaceRatingSummary summary;

  /// 今回のレース日（季節の判定に月を使う）。
  final String raceDate;

  const RatingSection({
    super.key,
    required this.horse,
    required this.summary,
    required this.raceDate,
  });

  static const TextStyle _labelStyle =
      TextStyle(fontSize: 10, color: Colors.black54);
  static const TextStyle _valueStyle = TextStyle(
      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87);
  static const TextStyle _headingStyle = TextStyle(
      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87);

  /// 今回の開催月（能力分析タブの季節適性と同じ読み方。読めなければ 1）。
  int _currentMonth() {
    final match =
        RegExp(r'\d{4}[^\d]*(\d{1,2})[^\d]*\d{1,2}').firstMatch(raceDate);
    if (match == null) return 1;
    return int.parse(match.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    final profile = summary.profileOf(horse.horseId);
    final history = profile?.history ?? const <RatingAnalyzedResult>[];
    if (profile == null || history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Rt を計算できる過去成績がありません',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      );
    }
    final rank = summary.trendRankOf(horse.horseId);
    final gap = summary.gapOf(horse);
    final last = history.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _tile(
              '実力Trend',
              Text(
                profile.latestTrend.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ratingTrendColorOf(profile.latestTrend),
                ),
              ),
            ),
            _tile(
              'Trend順位',
              Text(
                rank == null ? '取消' : '$rank位/${summary.trendOrder.length}頭',
                style: _valueStyle,
              ),
            ),
            _tile('期待値Gap', _buildGap(gap)),
            _tile(
              '前走Rt',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(last.raceRating.toStringAsFixed(1), style: _valueStyle),
                  const SizedBox(width: 4),
                  RatingLevelBadge(
                    level: last.levelGrade,
                    rankStr: last.record.rank,
                  ),
                ],
              ),
            ),
            _tile(
              '安定度',
              Text(
                profile.stabilityRank,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: profile.stabilityRank == 'A'
                      ? Colors.green
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('状態サイクル', style: _labelStyle),
            const SizedBox(width: 8),
            Text(
              profile.momentumStatus,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: ratingMomentumColorOf(profile.momentumStatus),
              ),
            ),
          ],
        ),
        Text(
          ratingMomentumNoteOf(profile.momentumStatus),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        const Text('条件適合', style: _headingStyle),
        const SizedBox(height: 2),
        _buildClassWallRow(profile, history),
        _buildWeightRow(profile),
        _buildSeasonRow(profile),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text('Rt の推移（新しい順）', style: _headingStyle),
            ),
            RatingSparkline(analysis: history),
          ],
        ),
        Container(height: 1, color: Colors.grey.shade300),
        for (final result in history.reversed) _buildHistoryRow(result),
      ],
    );
  }

  Widget _tile(String label, Widget value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }

  Widget _buildGap(int? gap) {
    if (gap == null) return const Text('-', style: _valueStyle);
    final color = ratingGapColorOf(gap);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gap > 0 ? '+$gap' : '$gap',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(ratingGapLabelOf(gap),
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  /// 条件適合の1行（左に項目名、右に判定と根拠）。
  Widget _conditionRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(label, style: _labelStyle)),
          Expanded(child: value),
        ],
      ),
    );
  }

  /// クラス壁: 今回のクラスの標準の Rt 以上を出したことがあれば「突破済」。
  Widget _buildClassWallRow(
      HorseRatingProfile profile, List<RatingAnalyzedResult> history) {
    final maxRt = history
        .map((r) => r.raceRating)
        .reduce((a, b) => a > b ? a : b);
    final basis = '最高Rt ${maxRt.toStringAsFixed(1)} ／ 今回のクラスの標準 '
        '${summary.classStandardRating.toStringAsFixed(1)}';
    return _conditionRow(
      'クラス壁',
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Icon(
            profile.isClassCleared ? Icons.check_circle : Icons.warning,
            color: profile.isClassCleared ? Colors.green : Colors.red,
            size: 14,
          ),
          Text(
            profile.isClassCleared ? '突破済' : '壁あり',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: profile.isClassCleared ? Colors.black87 : Colors.red,
            ),
          ),
          Text(basis,
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  /// 斤量: 今回の斤量が最高Rt を出したときより 1kg を超えて重い／軽いか（能力分析タブと同じ判定）。
  Widget _buildWeightRow(HorseRatingProfile profile) {
    if (profile.bestRatingWeight <= 0) {
      return _conditionRow('斤量', const Text('-', style: TextStyle(fontSize: 12)));
    }
    final diff = horse.carriedWeight - profile.bestRatingWeight;
    final String judge;
    if (diff > 1.0) {
      judge = '過去ベスト時より重い(酷量)';
    } else if (diff < -1.0) {
      judge = '過去ベスト時より軽い(恵量)';
    } else {
      judge = '適量';
    }
    return _conditionRow(
      '斤量',
      Text.rich(
        TextSpan(children: [
          TextSpan(
              text: judge,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(
            text: '  今回 ${horse.carriedWeight.toStringAsFixed(1)}kg ／ '
                'ベスト時 ${profile.bestRatingWeight.toStringAsFixed(1)}kg',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ]),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  /// 季節: 最高Rt を出した月と今回の月の差が2か月以内（年をまたぐ場合を含む）なら「好相性」（能力分析タブと同じ判定）。
  Widget _buildSeasonRow(HorseRatingProfile profile) {
    if (profile.bestRatingMonth <= 0) {
      return _conditionRow('季節', const Text('-', style: TextStyle(fontSize: 12)));
    }
    final monthDiff = (_currentMonth() - profile.bestRatingMonth).abs();
    final judge = (monthDiff <= 2 || monthDiff >= 10) ? '好相性(同季節に高Rt)' : '普通';
    return _conditionRow(
      '季節',
      Text.rich(
        TextSpan(children: [
          TextSpan(
              text: judge,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(
            text: '  ベスト時 ${profile.bestRatingMonth}月',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ]),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  /// Rt の推移の1行（能力分析タブの推移ダイアログと同じ項目）。
  Widget _buildHistoryRow(RatingAnalyzedResult result) {
    final r = result.record;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.date} ${r.raceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
                Text(
                  '着順: ${r.rank}/${r.numberOfHorses} (${r.popularity}人)',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('Rt ${result.raceRating.toStringAsFixed(1)}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: RatingLevelBadge(
                level: result.levelGrade,
                rankStr: r.rank,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
