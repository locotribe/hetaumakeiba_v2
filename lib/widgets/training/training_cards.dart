// lib/widgets/training/training_cards.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/logic/training_evaluation.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

// [追加] 馬詳細タブStep1: 調教タブ（training_tab.dart）の表示部品をここへ移した。
// 見た目は移す前と同じ。馬詳細タブ（Step3）からも使う (v.2026.9.23+26092306)
// [追加] 調教タイム個別データ移植Step2: 6列表に基準差・意図/鬼脚バッジ・全ラップの傾き（矢印）を追加。
// 調教ブロックの背景は全コース暗色に統一。基準差・意図・鬼脚は栗東・美浦の坂路/ウッドのみ（他は計算されず出ない）。
// 中間追切のレース見出しはタップでそのレースを開く (v.2026.9.25+26092502)

/// 左端の枠色の帯の幅
const double kTrainingGateBarWidth = 26;

const Color _tokeiColor1 = Color(0xFFFC855C);
const Color _tokeiColor2 = Color(0xFFFDF2C1);

// [追加] 調教タイム個別データ移植Step2: 調教ブロックの背景（全コース暗色に統一） (v.2026.9.25+26092502)
const Color _kDarkRowBg = Color(0xFF2B2B2B);

Color? _cellColor(int color) {
  if (color == 1) return _tokeiColor1;
  if (color == 2) return _tokeiColor2;
  return null;
}

// [修正] 調教タイム個別データ移植Step2: 全行を暗色に統一したため、rank の色は暗色背景用に統一 (v.2026.9.25+26092502)
Color _rankColor(String rank) {
  switch (rank) {
    case 'A':
      return Colors.redAccent;
    case 'B':
      return Colors.lightBlueAccent;
    case 'C':
      return Colors.white70;
    default:
      return Colors.white38;
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

/// 調教1本（見出し行＋時計6マス＋脚色(位置)＋併せ馬＋独自評価）
// [修正] 調教タイム個別データ移植Step2: 入力を row から entry に変え、基準差・意図/鬼脚・傾きを表示。
// 調教ブロックは全コース暗色（ゼブラ廃止） (v.2026.9.25+26092502)
class TrainingSessionBlock extends StatelessWidget {
  final MergedTrainingEntry entry;

  const TrainingSessionBlock({Key? key, required this.entry})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final row = buildTrainingRowView(entry);
    final eval = buildTrainingEvaluation(entry);

    return Container(
      color: _kDarkRowBg,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(row.headerLabel,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ),
                // 全体・基準差（栗東・美浦の坂路/ウッドのみ）
                if (eval.comparable && eval.total != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildTotalDiff(eval),
                  ),
                if (row.isBestTime)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange.shade700),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('一番時計',
                        style: TextStyle(
                            fontSize: 10, color: Colors.orangeAccent)),
                  ),
                if (row.critic != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(row.critic!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
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
          if (eval.comparable && (eval.intent != null || eval.oniashi))
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: _buildBadgeRow(eval),
            ),
          _TrainingTimeGrid(row: row),
          for (final partner in row.partners)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
              child: Text(partner.fullText,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.lightBlueAccent.shade100)),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalDiff(TrainingEvaluation eval) {
    final total = eval.total!.toStringAsFixed(1);
    final diff = eval.baseDiff;
    final children = <InlineSpan>[
      const TextSpan(
          text: '全体 ',
          style: TextStyle(color: Colors.white70, fontSize: 11)),
      TextSpan(
          text: total,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    ];
    if (diff != null) {
      final sign = diff > 0 ? '+' : '';
      final Color diffColor = diff < 0
          ? Colors.redAccent.shade100
          : (diff > 0 ? Colors.lightBlueAccent.shade100 : Colors.white70);
      children.add(TextSpan(
          text: ' (基準差 $sign${diff.toStringAsFixed(1)})',
          style: TextStyle(
              color: diffColor, fontSize: 11, fontWeight: FontWeight.bold)));
    }
    return Text.rich(TextSpan(children: children));
  }

  Widget _buildBadgeRow(TrainingEvaluation eval) {
    final badges = <Widget>[];
    final intent = eval.intent;
    if (intent != null) badges.add(_intentBadge(intent));
    if (eval.oniashi) badges.add(_badge('🔥 鬼脚', Colors.redAccent));
    return Wrap(spacing: 6, runSpacing: 4, children: badges);
  }

  Widget _intentBadge(TrainingIntent intent) {
    Color color;
    switch (intent.kind) {
      case TrainingIntentKind.light:
        color = Colors.grey.shade400;
        break;
      case TrainingIntentKind.practical:
        color = Colors.greenAccent;
        break;
      case TrainingIntentKind.sharp:
        color = Colors.orangeAccent;
        break;
      case TrainingIntentKind.standard:
        color = Colors.lightBlueAccent;
        break;
    }
    return _badge(intent.label, color);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

/// 時計6マス（累計＋ラップ、netkeiba の色）と脚色(位置)。暗色背景用。
/// 各1Fラップは1つ前のラップと比べて 速い=赤↗ / 遅い=青↘ / 横ばい=→ で色分けする。
// [修正] 調教タイム個別データ移植Step2: 暗色背景に統一し、全ラップの傾き（矢印）を表示 (v.2026.9.25+26092502)
class _TrainingTimeGrid extends StatelessWidget {
  final TrainingRowView row;

  const _TrainingTimeGrid({required this.row});

  @override
  Widget build(BuildContext context) {
    const borderColor = Colors.white24;

    // 値の入ったマス（ラップあり）の位置を集め、各マスの「1つ前のラップとの傾き」を求める。
    final lapIndexes = <int>[];
    for (int i = 0; i < row.cells.length; i++) {
      if (row.cells[i].lap != null) lapIndexes.add(i);
    }
    final Map<int, int> trendByCell = {}; // -1=加速(赤) / 1=減速(青) / 0=横ばい
    for (int k = 1; k < lapIndexes.length; k++) {
      final cur = row.cells[lapIndexes[k]].lap!;
      final prev = row.cells[lapIndexes[k - 1]].lap!;
      final diff = cur - prev;
      trendByCell[lapIndexes[k]] = diff < -0.05 ? -1 : (diff > 0.05 ? 1 : 0);
    }

    Color lapColor(int? trend) {
      if (trend == -1) return Colors.redAccent.shade100;
      if (trend == 1) return Colors.lightBlueAccent.shade100;
      return Colors.white70;
    }

    String arrow(int? trend) {
      if (trend == -1) return '↗';
      if (trend == 1) return '↘';
      if (trend == 0) return '→';
      return '';
    }

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
                    border: const Border(
                        right: BorderSide(color: borderColor)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        row.cells[i].time?.toStringAsFixed(1) ?? '-',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _cellColor(row.cells[i].color) != null
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                      Text(
                        row.cells[i].lap != null
                            ? '(${row.cells[i].lap!.toStringAsFixed(1)}${arrow(trendByCell[i])})'
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: _cellColor(row.cells[i].color) != null
                              ? Colors.black87
                              : lapColor(trendByCell[i]),
                          fontWeight:
                              (trendByCell[i] == -1 || trendByCell[i] == 1)
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
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white)),
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
                  // [修正] 調教タイム個別データ移植Step2: entry を渡す (v.2026.9.25+26092502)
                  TrainingSessionBlock(entry: finalEntry),
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
// [修正] 調教タイム個別データ移植Step2: レース見出しをタップでそのレースを開く。調教ブロックに entry を渡す (v.2026.9.25+26092502)
class TrainingRaceGroupView extends StatelessWidget {
  final TrainingRaceGroup group;
  final NetkeibaTrainingReview? review;

  const TrainingRaceGroupView({Key? key, required this.group, this.review})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final review = this.review;
    final raceId = group.raceId;
    final canOpen = !group.isCurrent && raceId != null && raceId.isNotEmpty;

    final header = Container(
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
          if (canOpen)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right, size: 18, color: Colors.blueGrey),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canOpen)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RacePage(raceId: raceId, raceDate: group.raceDate),
                  ),
                );
              },
              child: header,
            )
          else
            header,
          if (review?.shortReview != null)
            TrainingShortReview(text: review!.shortReview!),
          for (final entry in group.entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TrainingSessionBlock(entry: entry),
            ),
        ],
      ),
    );
  }
}
