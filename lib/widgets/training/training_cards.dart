// lib/widgets/training/training_cards.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

// [追加] 馬詳細タブStep1: 調教タブ（training_tab.dart）の表示部品をここへ移した。
// 見た目は移す前と同じ。馬詳細タブ（Step3）からも使う (v.2026.9.23+26092306)

/// 左端の枠色の帯の幅
const double kTrainingGateBarWidth = 26;

const Color _tokeiColor1 = Color(0xFFFC855C);
const Color _tokeiColor2 = Color(0xFFFDF2C1);
const Color _rankBColor = Color(0xFF007EFF);

Color? _cellColor(int color) {
  if (color == 1) return _tokeiColor1;
  if (color == 2) return _tokeiColor2;
  return null;
}

Color _rankColor(String rank) {
  switch (rank) {
    case 'A':
      return Colors.red;
    case 'B':
      return _rankBColor;
    case 'C':
      return Colors.black87;
    default:
      return Colors.grey;
  }
}

/// 厩舎コメントの評価アイコン番号 → 印（判明分のみ）
String? _stableMarkLabel(String? code) {
  if (code == '02') return '○';
  return null;
}

/// 左端の枠色の帯と馬番（枠順確定前・馬番0は灰色）
class TrainingGateBar extends StatelessWidget {
  final PredictionHorseDetail horse;

  const TrainingGateBar({Key? key, required this.horse}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasGate = horse.gateNumber > 0 && horse.horseNumber > 0;
    final background =
        hasGate ? horse.gateNumber.gateBackgroundColor : Colors.grey.shade400;
    final foreground =
        hasGate ? horse.gateNumber.gateTextColor : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      alignment: Alignment.center,
      child: Text(
        horse.horseNumber > 0 ? '${horse.horseNumber}' : '-',
        style: TextStyle(
            color: foreground, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

/// 馬名（取消は取り消し線・灰色）
class TrainingHorseName extends StatelessWidget {
  final PredictionHorseDetail horse;

  const TrainingHorseName({Key? key, required this.horse}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      horse.horseName,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        decoration: horse.isScratched ? TextDecoration.lineThrough : null,
        color: horse.isScratched ? Colors.grey : null,
      ),
    );
  }
}

/// 短評（灰色の小さめ文字）
class TrainingShortReview extends StatelessWidget {
  final String text;

  const TrainingShortReview({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
    );
  }
}

/// 厩舎コメント（印・本文・話者）
class TrainingStableComment extends StatelessWidget {
  final NetkeibaTrainingReview review;

  const TrainingStableComment({Key? key, required this.review})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mark = _stableMarkLabel(review.stableMark);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
              text: '厩舎 ',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
            if (mark != null)
              TextSpan(
                  text: '$mark ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: review.stableComment ?? ''),
            if (review.stableSpeaker != null)
              TextSpan(
                text: '〈${review.stableSpeaker}〉',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}

/// 調教1本（見出し行＋時計5マス＋脚色(位置)＋併せ馬）
class TrainingSessionBlock extends StatelessWidget {
  final TrainingRowView row;

  const TrainingSessionBlock({Key? key, required this.row}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(row.headerLabel,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
              ),
              if (row.isBestTime)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.shade700),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('一番時計',
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade800)),
                ),
              if (row.critic != null)
                Text(row.critic!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              if (row.rank != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    row.rank!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _rankColor(row.rank!),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _TrainingTimeGrid(row: row),
        for (final partner in row.partners)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(partner.fullText,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
          ),
      ],
    );
  }
}

/// 時計5マス（累計＋ラップ、netkeiba の色）と脚色(位置)。最後の1Fのラップは加速=赤・減速=青
class _TrainingTimeGrid extends StatelessWidget {
  final TrainingRowView row;

  const _TrainingTimeGrid({required this.row});

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey.shade300;
    final lastLapIndex = row.cells.lastIndexWhere((c) => c.lap != null);
    final trend = row.lastLapTrend;
    final trendColor = trend < 0
        ? Colors.red
        : (trend > 0 ? Colors.blue : Colors.grey.shade700);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < row.cells.length; i++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _cellColor(row.cells[i].color),
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        row.cells[i].time?.toStringAsFixed(1) ?? '-',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        row.cells[i].lap != null
                            ? '(${row.cells[i].lap!.toStringAsFixed(1)})'
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: i == lastLapIndex
                              ? trendColor
                              : Colors.grey.shade700,
                          fontWeight: i == lastLapIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: 56,
              child: Center(
                child: Text(row.loadLabel ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 最終追い切り（1頭1枚）
class TrainingFinalCard extends StatelessWidget {
  final PredictionHorseDetail horse;
  final List<MergedTrainingEntry> entries;
  final String raceId;

  /// このレースの評価（短評・厩舎コメント）
  final NetkeibaTrainingReview? review;

  const TrainingFinalCard({
    Key? key,
    required this.horse,
    required this.entries,
    required this.raceId,
    this.review,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final finalEntry = pickFinalEntry(entries, raceId);
    final review = this.review;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kTrainingGateBarWidth + 8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrainingHorseName(horse: horse),
                if (review?.shortReview != null)
                  TrainingShortReview(text: review!.shortReview!),
                const SizedBox(height: 6),
                if (finalEntry == null)
                  Text('調教データなし',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600))
                else
                  TrainingSessionBlock(row: buildTrainingRowView(finalEntry)),
                if (review?.stableComment != null)
                  TrainingStableComment(review: review!),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: kTrainingGateBarWidth,
            child: TrainingGateBar(horse: horse),
          ),
        ],
      ),
    );
  }
}

/// レースごとのまとまり（見出し・着順・短評・調教）
class TrainingRaceGroupView extends StatelessWidget {
  final TrainingRaceGroup group;
  final NetkeibaTrainingReview? review;

  const TrainingRaceGroupView({Key? key, required this.group, this.review})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final review = this.review;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: group.isCurrent
                ? Colors.green.shade100
                : Colors.blueGrey.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Text(group.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                if (group.result != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(group.result!,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          if (review?.shortReview != null)
            TrainingShortReview(text: review!.shortReview!),
          for (final entry in group.entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TrainingSessionBlock(row: buildTrainingRowView(entry)),
            ),
        ],
      ),
    );
  }
}
