// lib/widgets/shutuba_tabs/game_sim_panels.dart
// [追加] 展開シミュゲーム式移植Step4b: 新しい展開シミュの画面部品(100回走らせた結果・条件を動かす・出走馬のステータス)。
// 画面の案は Design「展開シミュ 新画面案」の①〜③。設計は memory/展開シミュ_ゲーム式移植_設計書.md の7章 (v.2026.10.27+26102705)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_ability_builder.dart';
// [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
import 'package:hetaumakeiba_v2/logic/analysis/game_form.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_form_inputs.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_display.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_inputs.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_reasons.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_reference.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_simulator.dart';
import 'package:hetaumakeiba_v2/widgets/horse_number_badge.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/race_simulation_view.dart';

/// 画面の色(画面の案と同じ)
class GameSimColors {
  GameSimColors._();
  static const Color primary = Color(0xFF1B5E20);
  static const Color accent = Color(0xFFE65100);
  static const Color subText = Color(0xFF4B5A4B);
  static const Color border = Color(0xFFB9CDB5);
  static const Color rowLine = Color(0xFFEDF2EA);
  static const Color chipBg = Color(0xFFE8F0E5);

  /// ランクごとの(背景, 文字)の色
  static const Map<String, (Color, Color)> rank = {
    'S': (Color(0xFFFFF4CC), Color(0xFF8A6100)),
    'A': (Color(0xFFFFE2D1), Color(0xFFB23C00)),
    'B': (Color(0xFFFDE0EC), Color(0xFFA3124F)),
    'C': (Color(0xFFDDF0DC), Color(0xFF1E6B22)),
    'D': (Color(0xFFDBE8F8), Color(0xFF0F4F9E)),
    'E': (Color(0xFFECE2F5), Color(0xFF5B1D87)),
    'F': (Color(0xFFECECEC), Color(0xFF4F4F4F)),
    'G': (Color(0xFFF3F3F3), Color(0xFF6B6B6B)),
  };

  /// [追加] 展開シミュ改良Step7b: 調子の5段階ごとの(背景, 文字)の色(ゲームの「やる気」の色に寄せた) (v.2026.10.30+26103006)
  static const Map<GameFormLevel, (Color, Color)> form = {
    GameFormLevel.best: (Color(0xFFFFE0EA), Color(0xFFB0124F)),
    GameFormLevel.good: (Color(0xFFFFEBD2), Color(0xFFB45300)),
    GameFormLevel.normal: (Color(0xFFEEF0E6), Color(0xFF5C6150)),
    GameFormLevel.poor: (Color(0xFFDCEAFA), Color(0xFF0F4F9E)),
    GameFormLevel.worst: (Color(0xFFEBDFF5), Color(0xFF5B1D87)),
  };
}

/// 画面に出す1頭ぶんの値。
class GameSimHorseView {
  final int horseNumber;
  final int gateNumber;
  final String horseName;
  final GameHorseAbility ability;

  /// スタミナ指数(画面のスタミナの値を作る)。無ければ null
  final double? staminaIndex;

  /// 100回の集計。まだ走らせていなければ null
  final GameHorseSummary? summary;

  /// [追加] 展開シミュ改良Step7b: 調子(調教から出した5段階)。無ければ null (v.2026.10.30+26103006)
  final GameFormResult? form;

  const GameSimHorseView({
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.ability,
    required this.staminaIndex,
    required this.summary,
    // [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
    this.form,
  });

  String get styleLabel => GameRaceDisplay.styleLabelOf(ability.style);
}

/// 白いカード(画面の案の角丸・薄い影)
class GameSimCard extends StatelessWidget {
  final Widget child;
  const GameSimCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

/// カードの見出し(左に題、右に補足)
class _CardTitle extends StatelessWidget {
  final String title;
  final String? note;
  const _CardTitle(this.title, [this.note]);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        if (note != null)
          Expanded(
            child: Text(
              note!,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: GameSimColors.subText),
            ),
          ),
      ],
    );
  }
}

/// [追加] 展開シミュゲーム式移植Step4c: 再生している1回の結果(着順・通過順・時計)。「別の回を見る」で再生と一緒に入れ替わる (v.2026.10.27+26102706)
class GameSimRunResultCard extends StatelessWidget {
  /// 入力の馬の順([GameRunRow.index] で引く)
  final List<GameSimHorseView> horses;

  /// 着順の順の行
  final List<GameRunRow> rows;

  /// 見出しの右の補足(「平均の走り」など)
  final String note;

  /// 表の下の説明。無ければ出さない
  final String? footnote;
  final String checkpointHeader;
  final int cornerCount;

  const GameSimRunResultCard({
    super.key,
    required this.horses,
    required this.rows,
    required this.note,
    this.footnote,
    required this.checkpointHeader,
    required this.cornerCount,
  });

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 11, color: GameSimColors.subText);
    final winner = rows.isEmpty ? null : rows.first.finishSeconds;
    return GameSimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('この再生の結果', note),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Row(
              children: [
                const SizedBox(width: 24, child: Text('着', style: head)),
                const SizedBox(width: 30, child: Text('#', style: head)),
                const Expanded(child: Text('馬名', style: head)),
                SizedBox(
                    width: 64,
                    child: Text(checkpointHeader,
                        style: head, textAlign: TextAlign.right)),
                const SizedBox(
                    width: 52,
                    child: Text('時計', style: head, textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (final r in rows) _row(r, winner),
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(footnote!,
                style: const TextStyle(fontSize: 11, color: GameSimColors.subText)),
          ],
        ],
      ),
    );
  }

  Widget _row(GameRunRow r, double? winner) {
    final h = horses[r.index];
    const num = TextStyle(
        fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);
    final f = r.finishSeconds;
    final String time;
    if (f == null) {
      time = '-';
    } else if (r.rank == 1 || winner == null) {
      time = GameRaceReference.formatTime(f);
    } else {
      time = '+${(f - winner).toStringAsFixed(1)}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GameSimColors.rowLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${r.rank}',
                style: num.copyWith(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: HorseNumberBadge(
                  horseNumber: h.horseNumber,
                  gateNumber: h.gateNumber,
                  size: 22),
            ),
          ),
          Expanded(
            child: Text(h.horseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 64,
            child: Text(
              GameRaceInputs.checkpointTextOf(r.checkpointRanks, cornerCount),
              textAlign: TextAlign.right,
              style: num.copyWith(fontSize: 12, color: GameSimColors.subText),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(time, textAlign: TextAlign.right, style: num),
          ),
        ],
      ),
    );
  }
}

/// ① シミュレーションの結果(全回の勝率・複勝率・平均の通過順)
class GameSimResultCard extends StatelessWidget {
  final List<GameSimHorseView> horses;
  final int runs;

  /// 「勝ち時計 1:57.0 ・ 1000m 58.3 ・ 上がり 34.8」
  final String timesText;
  final String checkpointHeader;
  final int cornerCount;

  /// [追加] 展開シミュ改良Step5b: 見出しの右の補足(既定「全回の平均」。計算中は「途中の結果 40/100回」) (v.2026.10.29+26102903)
  final String note;

  /// [追加] 展開シミュ改良Step5b: 時計の下に出す、回ごとに散らしたペースの幅の1行。無ければ出さない (v.2026.10.29+26102903)
  final String? paceText;

  const GameSimResultCard({
    super.key,
    required this.horses,
    required this.runs,
    required this.timesText,
    required this.checkpointHeader,
    required this.cornerCount,
    // [追加] 展開シミュ改良Step5b (v.2026.10.29+26102903)
    this.note = '全回の平均',
    this.paceText,
  });

  @override
  Widget build(BuildContext context) {
    final rows = horses.where((h) => h.summary != null).toList()
      ..sort((a, b) {
        final c = b.summary!.winProb.compareTo(a.summary!.winProb);
        if (c != 0) return c;
        return a.summary!.meanRank.compareTo(b.summary!.meanRank);
      });
    const head = TextStyle(fontSize: 11, color: GameSimColors.subText);
    return GameSimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // [修正] 展開シミュゲーム式移植Step4c: 見出しに回数と「走らせた」を使わない (v.2026.10.27+26102706)
          // [修正] 展開シミュ改良Step5b: 補足を [note] に(計算中は途中の結果と出す) (v.2026.10.29+26102903)
          _CardTitle('シミュレーションの結果', note),
          const SizedBox(height: 2),
          Text(timesText,
              style: const TextStyle(
                  fontSize: 12,
                  color: GameSimColors.subText,
                  fontFeatures: [FontFeature.tabularFigures()])),
          // [追加] 展開シミュ改良Step5b: 回ごとに散らしたペースの幅 (v.2026.10.29+26102903)
          if (paceText != null)
            Text(paceText!,
                style: const TextStyle(
                    fontSize: 12,
                    color: GameSimColors.subText,
                    fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Row(
              children: [
                const SizedBox(width: 30, child: Text('#', style: head)),
                const Expanded(child: Text('馬名', style: head)),
                const SizedBox(width: 34, child: Text('脚質', style: head)),
                const SizedBox(
                    width: 48,
                    child: Text('勝率', style: head, textAlign: TextAlign.right)),
                const SizedBox(
                    width: 50,
                    child: Text('複勝率', style: head, textAlign: TextAlign.right)),
                SizedBox(
                    width: 64,
                    child: Text(checkpointHeader,
                        style: head, textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (final h in rows) _row(h),
          const SizedBox(height: 6),
          Text(
            '勝率・複勝率は、$runs回のシミュレーションの割合を実際の結果に合わせて補正した値。通過順は全回の平均。',
            style: const TextStyle(fontSize: 11, color: GameSimColors.subText),
          ),
        ],
      ),
    );
  }

  Widget _row(GameSimHorseView h) {
    final s = h.summary!;
    const num = TextStyle(
        fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GameSimColors.rowLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: HorseNumberBadge(
                  horseNumber: h.horseNumber,
                  gateNumber: h.gateNumber,
                  size: 22),
            ),
          ),
          Expanded(
            child: Text(h.horseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 34,
            child: Text(h.styleLabel,
                style: const TextStyle(fontSize: 12, color: GameSimColors.subText)),
          ),
          SizedBox(
            width: 48,
            child: Text('${(s.winProb * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: num.copyWith(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 50,
            child: Text('${(s.top3Prob * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right, style: num),
          ),
          SizedBox(
            width: 64,
            child: Text(
              GameRaceInputs.checkpointTextOf(
                  s.meanCheckpointRanks, cornerCount),
              textAlign: TextAlign.right,
              style: num.copyWith(fontSize: 12, color: GameSimColors.subText),
            ),
          ),
        ],
      ),
    );
  }
}

/// [追加] 展開シミュ改良Step5b(案E): なぜこの勝率か。各馬の、全馬の平均より得した(+)・損した(−)距離の上位2つ。
/// 並びは結果の表と同じ(補正した勝率の高い順) (v.2026.10.29+26102903)
class GameSimReasonCard extends StatelessWidget {
  /// 入力の馬の順
  final List<GameSimHorseView> horses;

  /// 入力の馬の順(GameRaceReasons.of の結果)
  final List<List<GameReason>> reasons;

  /// [追加] 展開シミュ改良Step7b: 入力の馬の順の調子の得・損(GameRaceReasons.formOf の結果)。調子が普通の馬は null。無ければ空 (v.2026.10.30+26103006)
  final List<GameReason?> formReasons;

  const GameSimReasonCard({
    super.key,
    required this.horses,
    required this.reasons,
    // [追加] 展開シミュ改良Step7b (v.2026.10.30+26103006)
    this.formReasons = const [],
  });

  @override
  Widget build(BuildContext context) {
    final order = List<int>.generate(horses.length, (i) => i)
      ..sort((a, b) {
        final sa = horses[a].summary;
        final sb = horses[b].summary;
        if (sa == null || sb == null) return a.compareTo(b);
        final c = sb.winProb.compareTo(sa.winProb);
        if (c != 0) return c;
        return sa.meanRank.compareTo(sb.meanRank);
      });
    return GameSimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('なぜこの勝率か', '全馬の平均との差'),
          const SizedBox(height: 4),
          // [修正] 展開シミュ改良Step7b: 調子の得・損を3行目に足す (v.2026.10.30+26103006)
          for (final i in order)
            _row(
              horses[i],
              i < reasons.length ? reasons[i] : const [],
              i < formReasons.length ? formReasons[i] : null,
            ),
          const SizedBox(height: 6),
          const Text(
            '全回の平均で、ゴールまでに得した(+)・損した(−)距離の目安(1馬身=2.4m)。'
            'スピード指数・適性・斤量は能力の差、ほかは展開(スタミナ切れ・前が詰まる・外を回る・砂をかぶる・傷んだ内)で数えたもの。'
            '調子は、普通だった場合との差(終盤の速度の分だけ数えた目安)。',
            style: TextStyle(fontSize: 11, color: GameSimColors.subText, height: 1.5),
          ),
        ],
      ),
    );
  }

  // [修正] 展開シミュ改良Step7b: 調子の得・損([formReason])を足した (v.2026.10.30+26103006)
  Widget _row(GameSimHorseView h, List<GameReason> rs, GameReason? formReason) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GameSimColors.rowLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: HorseNumberBadge(
                  horseNumber: h.horseNumber,
                  gateNumber: h.gateNumber,
                  size: 22),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.horseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (rs.isEmpty)
                  const Text('大きな差なし',
                      style: TextStyle(fontSize: 12, color: GameSimColors.subText)),
                for (final r in rs)
                  Text(
                    r.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.lengths >= 0
                          ? GameSimColors.primary
                          : GameSimColors.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                // [追加] 展開シミュ改良Step7b: 調子の得・損。「調子」のラベルは5段階の色 (v.2026.10.30+26103006)
                if (formReason != null)
                  Row(
                    children: [
                      _formTag(h.form?.level ?? GameFormLevel.normal),
                      Flexible(
                        child: Text(
                          formReason.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: formReason.lengths >= 0
                                ? GameSimColors.primary
                                : GameSimColors.accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [追加] 展開シミュ改良Step7b: 「調子」のラベル (v.2026.10.30+26103006)
  Widget _formTag(GameFormLevel level) {
    final colors = GameSimColors.form[level]!;
    return Container(
      margin: const EdgeInsets.only(right: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('調子',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: colors.$2)),
    );
  }
}

/// 音量バーのようなスライダー1本(題・大きな値・両端の目盛り・説明)
class _TimeSlider extends StatelessWidget {
  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final String minText;
  final String middleText;
  final String maxText;
  final String note;
  final ValueChanged<double>? onChanged;

  /// 左右を逆にする(左が大きい値=遅い、右が小さい値=速い)。[minText] は右端、[maxText] は左端に出る
  final bool reversed;

  const _TimeSlider({
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.minText,
    required this.middleText,
    required this.maxText,
    required this.note,
    required this.onChanged,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(
        fontSize: 11,
        color: GameSimColors.subText,
        fontFeatures: [FontFeature.tabularFigures()]);
    final divisions = ((max - min) * 10).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            Text(valueText,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: GameSimColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: GameSimColors.primary,
            thumbColor: GameSimColors.primary,
            inactiveTrackColor: GameSimColors.chipBg,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: reversed
                ? (min + max - value).clamp(min, max).toDouble()
                : value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : null,
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(reversed ? min + max - v : v),
          ),
        ),
        Row(
          children: [
            Text(reversed ? maxText : minText, style: small),
            Expanded(
                child: Text(middleText, style: small, textAlign: TextAlign.center)),
            Text(reversed ? minText : maxText, style: small),
          ],
        ),
        const SizedBox(height: 4),
        Text(note,
            style: const TextStyle(
                fontSize: 11, color: GameSimColors.subText, height: 1.5)),
      ],
    );
  }
}

/// 丸いチップのボタン(選んでいるものは緑で塗る)
class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;

  const _PillButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.height = 32,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: selected ? GameSimColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black87,
          disabledForegroundColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(expand ? 8 : height / 2),
            side: selected
                ? BorderSide.none
                : const BorderSide(color: GameSimColors.border),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(label,
            style: TextStyle(
                fontSize: expand ? 13 : 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
    return expand ? Expanded(child: button) : button;
  }
}

/// ② 条件を動かす(走破タイム・1000m通過・クッション値のスライダー、馬場状態、馬場のデータ、シミュレーションのボタン)
class GameSimConditionCard extends StatelessWidget {
  /// 過去レースの説明(「過去(同じレース名・10レース): 最速 … 」)
  final String winnerNote;

  final double winnerSeconds;
  final double winnerMin;
  final double winnerMax;
  final ValueChanged<double> onWinnerChanged;

  /// 1000m通過。1000m未満のレースなどで出せないときは null
  final double? first1000Seconds;
  final double first1000Min;
  final double first1000Max;
  final String first1000Note;
  final ValueChanged<double> onFirst1000Changed;

  /// クッション値。ダートなど出さないときは null
  final double? cushion;
  final double cushionMin;
  final double cushionMax;
  final String cushionSourceLabel;
  final ValueChanged<double> onCushionChanged;

  final String going;
  final String goingNote;
  final ValueChanged<String> onGoingChanged;

  final TrackBiasSource source;
  final bool hasActual;
  final bool hasPredicted;
  final bool hasTrend;
  final ValueChanged<TrackBiasSource> onSourceChanged;

  final bool isRunning;

  /// シミュレーションし直しが必要な変更があるか(ボタンを押せるか)
  final bool isPending;
  final VoidCallback onRun;

  const GameSimConditionCard({
    super.key,
    required this.winnerNote,
    required this.winnerSeconds,
    required this.winnerMin,
    required this.winnerMax,
    required this.onWinnerChanged,
    required this.first1000Seconds,
    required this.first1000Min,
    required this.first1000Max,
    required this.first1000Note,
    required this.onFirst1000Changed,
    required this.cushion,
    required this.cushionMin,
    required this.cushionMax,
    required this.cushionSourceLabel,
    required this.onCushionChanged,
    required this.going,
    required this.goingNote,
    required this.onGoingChanged,
    required this.source,
    required this.hasActual,
    required this.hasPredicted,
    required this.hasTrend,
    required this.onSourceChanged,
    required this.isRunning,
    required this.isPending,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return GameSimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('条件を動かす', '同じレースの過去の時計から範囲を作る'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('馬場のデータ',
                  style: TextStyle(fontSize: 12, color: GameSimColors.subText)),
              _PillButton(
                label: '実測(当日)',
                selected: source == TrackBiasSource.actual,
                onPressed: hasActual
                    ? () => onSourceChanged(TrackBiasSource.actual)
                    : null,
              ),
              _PillButton(
                label: '予測',
                selected: source == TrackBiasSource.predicted,
                onPressed: hasPredicted
                    ? () => onSourceChanged(TrackBiasSource.predicted)
                    : null,
              ),
              _PillButton(
                label: '過去平均',
                selected: source == TrackBiasSource.trend,
                onPressed: hasTrend
                    ? () => onSourceChanged(TrackBiasSource.trend)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TimeSlider(
            title: '走破タイム(馬場の速さ)',
            valueText: GameRaceReference.formatTime(winnerSeconds),
            value: winnerSeconds,
            min: winnerMin,
            max: winnerMax,
            minText: GameRaceReference.formatTime(winnerMin),
            middleText: '遅い ← → 速い',
            maxText: GameRaceReference.formatTime(winnerMax),
            note: '$winnerNote 動かしても着順は変わらず、時計だけが変わる。',
            onChanged: onWinnerChanged,
            reversed: true,
          ),
          if (first1000Seconds != null) ...[
            const SizedBox(height: 16),
            _TimeSlider(
              title: '1000m通過(ペース)',
              valueText: first1000Seconds!.toStringAsFixed(1),
              value: first1000Seconds!,
              min: first1000Min,
              max: first1000Max,
              minText: first1000Min.toStringAsFixed(1),
              middleText: 'スロー ← ミドル → ハイ',
              maxText: first1000Max.toStringAsFixed(1),
              note:
                  '$first1000Note 速くすると前の馬がバテやすくなり、展開と着順が変わる(シミュレーションし直すと反映)。',
              onChanged: isRunning ? null : onFirst1000Changed,
              reversed: true,
            ),
          ],
          if (cushion != null) ...[
            const SizedBox(height: 16),
            _TimeSlider(
              title: 'クッション値',
              valueText: cushion!.toStringAsFixed(1),
              value: cushion!,
              min: cushionMin,
              max: cushionMax,
              minText: '${cushionMin.toStringAsFixed(1)} 軟らかい',
              middleText: cushionSourceLabel,
              maxText: '硬い ${cushionMax.toStringAsFixed(1)}',
              note:
                  '走破タイムの初期値が動く(+1で2000mあたり約0.2秒速い。実測)。馬場状態のボタンを押すと、その馬場のよくある値に動く。',
              onChanged: onCushionChanged,
            ),
          ],
          const SizedBox(height: 16),
          const Text('馬場状態',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final g in const ['良', '稍重', '重', '不良']) ...[
                _PillButton(
                  label: g,
                  selected: going == g,
                  height: 40,
                  expand: true,
                  onPressed: isRunning ? null : () => onGoingChanged(g),
                ),
                if (g != '不良') const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(goingNote,
              style: const TextStyle(
                  fontSize: 11, color: GameSimColors.subText, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: GameSimColors.accent,
                disabledBackgroundColor: const Color(0xFFF3C9AE),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: (isPending && !isRunning) ? onRun : null,
              child: isRunning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        // [修正] 展開シミュゲーム式移植Step4c: ボタンを押した後の表示を「計算しています…」にし、ボタンの文字に回数を使わない (v.2026.10.27+26102706)
                        Text('計算しています…',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('この条件でシミュレーションする',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPending
                ? '1000m通過・馬場状態の変更は、シミュレーションし直すと結果と再生に反映される。'
                : '今の結果はこの条件でシミュレーションしたもの。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: GameSimColors.subText),
          ),
        ],
      ),
    );
  }
}

/// ③ 出走馬のステータス(ゲーム画面風。5つの能力値をランクと数値で)
class GameSimStatusCard extends StatelessWidget {
  final List<GameSimHorseView> horses;

  const GameSimStatusCard({super.key, required this.horses});

  static const List<String> labels = ['スピード', 'スタミナ', 'パワー', '根性', '賢さ'];

  static List<double> valuesOf(GameSimHorseView h) => [
        h.ability.speedDisplay,
        GameRaceDisplay.staminaDisplay(h.staminaIndex),
        h.ability.power,
        h.ability.guts,
        h.ability.wit,
      ];

  @override
  Widget build(BuildContext context) {
    final sorted = List<GameSimHorseView>.from(horses)
      ..sort((a, b) => a.horseNumber.compareTo(b.horseNumber));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GameSimCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('出走馬のステータス',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'スピード=スピード指数 ・ スタミナ=スタミナ指数 ・ パワー=テン(前に行く力) ・ 根性=終い(末脚) ・ 賢さ=騎手の3着内率。'
                'ランクは固定の区切り(S 1000〜 / A 900〜 / B 800〜 / C 700〜 / D 600〜 / E 450〜 / F 300〜 / G)。'
                // [追加] 展開シミュ改良Step7b: 調子の説明。ステータスの値は調子を含まない地力 (v.2026.10.30+26103006)
                '調子=調教の時計を、その馬の好調時と比べた5段階(絶好調×1.04 / 好調×1.02 / 普通 / 不調×0.98 / 絶不調×0.96)。'
                'ステータスの値は調子を含まない地力で、調子は走らせるときに能力へかける。',
                style: TextStyle(
                    fontSize: 11, color: GameSimColors.subText, height: 1.6),
              ),
            ],
          ),
        ),
        for (final h in sorted) _horseCard(h),
      ],
    );
  }

  Widget _horseCard(GameSimHorseView h) {
    final values = valuesOf(h);
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HorseNumberBadge(
                  horseNumber: h.horseNumber,
                  gateNumber: h.gateNumber,
                  size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(h.horseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: GameSimColors.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(h.styleLabel,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF2F4A2C))),
              ),
            ],
          ),
          // [追加] 展開シミュ改良Step7b: 調子の1行 (v.2026.10.30+26103006)
          if (h.form != null) ...[
            const SizedBox(height: 4),
            _formRow(h.form!),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              for (int k = 0; k < labels.length; k++) ...[
                Expanded(child: _statCell(labels[k], values[k])),
                if (k < labels.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// [追加] 展開シミュ改良Step7b: 調子の1行(「調子 ▲ 好調 時計が良い・参照5走」) (v.2026.10.30+26103006)
  Widget _formRow(GameFormResult f) {
    final colors = GameSimColors.form[f.level]!;
    return Row(
      children: [
        const Text('調子',
            style: TextStyle(fontSize: 11, color: GameSimColors.subText)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
          decoration: BoxDecoration(
            color: colors.$1,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(GameFormText.chipOf(f.level),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: colors.$2)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(GameFormText.detailOf(f),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF3F4B3F))),
        ),
      ],
    );
  }

  Widget _statCell(String label, double value) {
    final rank = GameAbilityBuilder.rankOf(value);
    final colors = GameSimColors.rank[rank] ?? GameSimColors.rank['G']!;
    const small = TextStyle(fontSize: 10, color: Color(0xFF3F4B3F));
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 3, 0, 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          FittedBox(child: Text(label, style: small)),
          Text(rank,
              style: TextStyle(
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: colors.$2)),
          Text(value.round().toString(),
              style: small.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}