// lib/widgets/horse_detail/growth_curve_section.dart

// [追加] 馬体重成長曲線 Step2: 馬詳細タブ「情報・血統」の最下部に出す成長曲線。
// 見出し（1行目: デビュー体重→最新、2行目: 最高・最低・走数）、期間スイッチ（直近1年／3年／全期間）、
// グラフ（タップした点の詳細を下に表示）、凡例を並べる。データは受け取るだけで、読み込みはしない (v.2026.10.1+26100102)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/growth_curve_painter.dart';

class GrowthCurveSection extends StatefulWidget {
  final PredictionHorseDetail horse;

  /// その馬の過去走（DB の horse_performance。並び順は問わない）
  final List<HorseRaceRecord> records;

  /// 今回レースの日付（PredictionRaceData.raceDate の文字列）
  final String raceDate;

  /// 表示期間（馬を切り替えても保つため、親が持つ）
  final GrowthRange range;
  final ValueChanged<GrowthRange> onRangeChanged;

  const GrowthCurveSection({
    super.key,
    required this.horse,
    required this.records,
    required this.raceDate,
    required this.range,
    required this.onRangeChanged,
  });

  @override
  State<GrowthCurveSection> createState() => _GrowthCurveSectionState();
}

class _GrowthCurveSectionState extends State<GrowthCurveSection> {
  /// タップで選んだ点（表示中の期間の中での番号）。null なら最後の点
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant GrowthCurveSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range ||
        oldWidget.horse.horseId != widget.horse.horseId) {
      _selectedIndex = null;
    }
  }

  static String _signed(int v) {
    if (v > 0) return '+$v';
    if (v < 0) return '$v';
    return '±0';
  }

  static String _date(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}/$m/$day';
  }

  /// 見出し（生年月日は基本情報に出ているので出さない）。
  /// 1行目: デビュー体重 → 最新体重（増減）、2行目: 最高・最低・走数
  Widget _buildSummary(GrowthSummary summary) {
    final lines = <String>[];
    final debut = summary.debutWeight;
    final latest = summary.latestWeight;
    if (debut != null && latest != null) {
      final diff = summary.diffFromDebut;
      lines.add('デビュー ${debut}kg → 最新 ${latest}kg'
          '${diff == null ? '' : '（${_signed(diff)}）'}');
      lines.add('最高 ${summary.maxWeight}kg／最低 ${summary.minWeight}kg'
          '　${summary.runCount}走');
    } else {
      lines.add('${summary.runCount}走');
    }
    return Text(
      lines.join('\n'),
      style: const TextStyle(fontSize: 12, color: Colors.black87),
    );
  }

  Widget _buildRangeButtons() {
    const labels = {
      GrowthRange.oneYear: '直近1年',
      GrowthRange.threeYears: '3年',
      GrowthRange.all: '全期間',
    };
    return Row(
      children: [
        for (final range in GrowthRange.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => widget.onRangeChanged(range),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.range == range
                        ? Colors.green.shade100
                        : Colors.white,
                    border: Border.all(
                      color: widget.range == range
                          ? Colors.green.shade700
                          : Colors.grey.shade400,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    labels[range]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.range == range
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: widget.range == range
                          ? Colors.green.shade900
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChart(
      List<GrowthPoint> shown, GrowthWeightWindow window, int selected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            Size(constraints.maxWidth, GrowthCurveLayout.totalHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final layout = GrowthCurveLayout(
                size: size, points: shown, window: window);
            final index = layout.nearestIndex(details.localPosition);
            if (index != null) {
              setState(() => _selectedIndex = index);
            }
          },
          child: CustomPaint(
            size: size,
            painter: GrowthCurvePainter(
              points: shown,
              window: window,
              selectedIndex: selected,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedInfo(GrowthPoint p) {
    final weight = p.weight;
    final change = p.weightChange;
    final weightText = weight == null
        ? '馬体重 計不'
        : '馬体重 ${weight}kg${change == null ? '' : '（${_signed(change)}）'}';
    String resultText;
    if (p.isCurrent) {
      resultText = '今回の当日発表';
    } else {
      final String rankText = switch (p.finishKind) {
        GrowthFinishKind.numeric => '${p.rank}着',
        GrowthFinishKind.stopped => '中止',
        GrowthFinishKind.excluded => '除外',
        GrowthFinishKind.scratched => '取消',
        GrowthFinishKind.unknown => '--',
      };
      final popularity = p.popularity;
      final fieldSize = p.fieldSize;
      resultText = '${popularity == null ? '--' : '$popularity'}人気 → $rankText'
          '${fieldSize == null ? '' : '（$fieldSize頭）'}';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_date(p.date)}  ${p.raceName}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '$weightText　$resultText',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Widget mark, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _lineMark(Color color) {
    return Container(width: 14, height: 2, color: color);
  }

  Widget _boxMark(Color color) {
    return Container(width: 8, height: 10, color: color);
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _legendItem(_lineMark(GrowthCurvePainter.weightColor), '馬体重'),
              _legendItem(_lineMark(GrowthCurvePainter.referenceColor),
                  '${GrowthCurveBuilder.referenceWeight}kg'),
              _legendItem(_boxMark(GrowthCurvePainter.popularityColor), '人気'),
              _legendItem(
                  _boxMark(GrowthCurvePainter.betterColor), '着順（人気より上）'),
              _legendItem(
                  _boxMark(GrowthCurvePainter.worseColor), '着順（人気より下）'),
              _legendItem(_boxMark(GrowthCurvePainter.evenColor), '着順（人気どおり）'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '棒は上ほど上位（頭数で正規化）。破線は計不をはさむ区間と今回の当日体重。点をタップで詳細',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raceDate = parseRaceDateForSpeedIndex(widget.raceDate);
    final all = GrowthCurveBuilder.buildPoints(
      records: widget.records,
      raceDate: raceDate,
      currentHorseWeight: widget.horse.horseWeight,
    );
    final base =
        GrowthCurveBuilder.baseDate(raceDate: raceDate, today: DateTime.now());
    final shown = GrowthCurveBuilder.pointsInRange(all, widget.range, base);
    final window = GrowthCurveBuilder.weightWindow(shown);
    final summary = GrowthCurveBuilder.summarize(all);
    final selectedIndex = _selectedIndex;
    final selected = shown.isEmpty
        ? -1
        : (selectedIndex != null && selectedIndex < shown.length
            ? selectedIndex
            : shown.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummary(summary),
        const SizedBox(height: 6),
        _buildRangeButtons(),
        const SizedBox(height: 4),
        if (all.isEmpty)
          _message('戦績がありません')
        else if (shown.isEmpty)
          _message('この期間の出走はありません')
        else ...[
          _buildChart(shown, window, selected),
          _buildSelectedInfo(shown[selected]),
          _buildLegend(),
        ],
      ],
    );
  }
}
